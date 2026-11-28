begin;
create table if not exists agc_ctf_private.assessment_stage_map (
 mission integer not null, stage integer not null, assessment_version integer not null,
 framework text not null check(framework in ('nice','ecsf')), element_id text not null,
 facet text not null, weight integer not null check(weight between 1 and 100),
 difficulty integer not null check(difficulty between 1 and 6),
 primary key(mission,stage,assessment_version,framework,element_id,facet));
create table if not exists agc_ctf_private.assessment_stage_evidence (
 member_id uuid not null, mission integer not null, stage integer not null, assessment_version integer not null,
 framework text not null, element_id text not null, facet text not null,
 weight integer not null check(weight between 1 and 100), difficulty integer not null check(difficulty between 1 and 6),
 hint_levels integer[] not null default '{}', review_seen boolean not null default false,
 assistance text not null check(assistance in ('unknown','assisted','independent')),
 validated_at timestamptz not null default now(),
 primary key(member_id,mission,stage,assessment_version,framework,element_id,facet));
create table if not exists agc_ctf_private.assessment_review_exposure(member_id uuid not null,mission integer not null,seen_at timestamptz not null default now(),primary key(member_id,mission));
alter table agc_ctf_private.assessment_stage_map enable row level security;
alter table agc_ctf_private.assessment_stage_evidence enable row level security;
alter table agc_ctf_private.assessment_review_exposure enable row level security;
revoke all on agc_ctf_private.assessment_stage_map,agc_ctf_private.assessment_stage_evidence,agc_ctf_private.assessment_review_exposure from public,anon,authenticated;
-- Existing evidence is retained as historical, not promoted to full competency.
insert into agc_ctf_private.assessment_stage_evidence(member_id,mission,stage,assessment_version,framework,element_id,facet,weight,difficulty,assistance,validated_at)
select member_id,mission,3,assessment_version,framework,element_id,'legacy-foundation',20,1,'unknown',created_at from agc_ctf_private.competency_evidence where mission=1 and framework='nice' and element_id='K1094' on conflict do nothing;
-- No new framework mappings are activated until source identifiers are verified.
create or replace function agc_ctf_private.record_assessment_stage(p_member uuid,p_mission integer,p_stage integer,p_version integer) returns void language plpgsql set search_path='' as $$
declare hints integer[]; reviewed boolean;
begin
if p_member is distinct from auth.uid() or p_member is null then raise exception 'Unauthorized'; end if;
select coalesce(array_agg(level order by level),'{}'::integer[]) into hints from agc_ctf_private.hint_purchase where member_id=p_member and mission=p_mission and not arena;
select exists(select 1 from agc_ctf_private.assessment_review_exposure where member_id=p_member and mission=p_mission) into reviewed;
insert into agc_ctf_private.assessment_stage_evidence(member_id,mission,stage,assessment_version,framework,element_id,facet,weight,difficulty,hint_levels,review_seen,assistance)
select p_member,mission,stage,assessment_version,framework,element_id,facet,weight,difficulty,hints,reviewed,case when reviewed or cardinality(hints)>0 then 'assisted' else 'unknown' end from agc_ctf_private.assessment_stage_map where mission=p_mission and stage=p_stage and assessment_version=p_version on conflict do nothing;
end $$;
revoke all on function agc_ctf_private.record_assessment_stage(uuid,integer,integer,integer) from public,anon,authenticated;
create or replace function public.agc_ctf_competency_progress() returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid();
begin
if me is null or not exists(select 1 from auth.users u where u.id=me and not u.is_anonymous) then raise exception 'Zaloguj się'; end if;
return coalesce((select jsonb_agg(to_jsonb(t)) from (select framework,element_id as id,least(100,sum(w)) as progress,least(100,sum(i)) as independent_progress,case when sum(i)>0 then 'independent' when bool_or(assisted) then 'assisted' else 'unknown' end as assistance from (select framework,element_id,facet,max(weight) w,max(case when assistance='independent' then weight else 0 end) i,bool_or(assistance='assisted') assisted from agc_ctf_private.assessment_stage_evidence where member_id=me group by framework,element_id,facet) f group by framework,element_id) t),'[]'::jsonb);
end $$;
revoke all on function public.agc_ctf_competency_progress() from public,anon;
grant execute on function public.agc_ctf_competency_progress() to authenticated;
commit;
create table if not exists agc_ctf_private.competency_evidence(member_id uuid not null,framework text not null,element_id text not null,mission integer not null,assessment_version integer not null,assistance text not null check(assistance in ('unknown','assisted','independent')),created_at timestamptz not null default now(),primary key(member_id,framework,element_id,mission,assessment_version));
alter table agc_ctf_private.competency_evidence enable row level security;
revoke all on agc_ctf_private.competency_evidence from public,anon,authenticated;
create table if not exists agc_ctf_private.foundation_stage(member_id uuid not null,mission integer not null,stage integer not null default 0,primary key(member_id,mission));
alter table agc_ctf_private.foundation_stage enable row level security;
revoke all on agc_ctf_private.foundation_stage from public,anon,authenticated;
create or replace function public.agc_ctf_foundation(p_action text,p_answer text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); s integer; secret_value text; payload text; expected text; accepted boolean:=false;
begin
if me is null or not exists(select 1 from auth.users u where u.id=me and not u.is_anonymous) then raise exception 'Zaloguj się'; end if;
select secret into secret_value from agc_ctf_private.progress where member_id=me and mission=1;
if secret_value is null then raise exception 'Odblokuj OP001'; end if;
payload:=substr(secret_value,1,8);
insert into agc_ctf_private.foundation_stage(member_id,mission) values(me,1) on conflict do nothing;
select stage into s from agc_ctf_private.foundation_stage where member_id=me and mission=1 for update;
if p_action='answer' and s<3 then
expected:=case s when 0 then 'HEX' when 1 then payload when 2 then '8' end;
accepted:=upper(trim(p_answer))=upper(expected);
if accepted then s:=s+1;update agc_ctf_private.foundation_stage set stage=s where member_id=me and mission=1;
if s=3 then insert into agc_ctf_private.competency_evidence(member_id,framework,element_id,mission,assessment_version,assistance) values(me,'nice','K1094',1,1,'unknown') on conflict do nothing; end if;
end if;
elsif p_action not in ('state','answer') then raise exception 'Nieznana operacja'; end if;
return jsonb_build_object('stage',s,'accepted',accepted,'artifact',encode(convert_to(payload,'UTF8'),'hex'));
end $$;
revoke all on function public.agc_ctf_foundation(text,text) from public,anon;
grant execute on function public.agc_ctf_foundation(text,text) to authenticated;
create or replace function public.agc_ctf_competency_progress() returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid();
begin
if me is null or not exists(select 1 from auth.users u where u.id=me and not u.is_anonymous) then raise exception 'Zaloguj się'; end if;
return coalesce((select jsonb_agg(jsonb_build_object('framework',framework,'id',element_id,'assistance',assistance)) from (select distinct on(framework,element_id) framework,element_id,assistance from agc_ctf_private.competency_evidence where member_id=me order by framework,element_id,case assistance when 'independent' then 0 when 'assisted' then 1 else 2 end) e),'[]'::jsonb);
end $$;
revoke all on function public.agc_ctf_competency_progress() from public,anon;
grant execute on function public.agc_ctf_competency_progress() to authenticated;
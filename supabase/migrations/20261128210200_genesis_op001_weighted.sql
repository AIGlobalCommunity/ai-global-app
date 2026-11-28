begin;
insert into agc_ctf_private.assessment_stage_map values (1,2,2,'nice','K1094','legacy-foundation',20,1),(1,4,2,'ecsf','skills:Collect information while preserving its integrity','basic-hash-verification',10,1) on conflict do nothing;
alter table agc_ctf_private.foundation_stage add column if not exists version integer not null default 1;
create or replace function public.agc_ctf_foundation(p_action text,p_answer text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); s integer; payload text; expected text; accepted boolean:=false; h text;
begin
if me is null or not exists(select 1 from auth.users where id=me and not is_anonymous) then raise exception 'Zaloguj się';end if;
perform pg_advisory_xact_lock(731971);
select substr(secret,1,8) into payload from agc_ctf_private.progress where member_id=me and mission=1;
if payload is null then raise exception 'Odblokuj OP001';end if;
h:=encode(sha256(convert_to(payload,'UTF8')),'hex');
insert into agc_ctf_private.foundation_stage(member_id,mission,stage,version) values(me,1,0,2) on conflict(member_id,mission) do update set stage=0,version=2 where agc_ctf_private.foundation_stage.version<2;
select stage into s from agc_ctf_private.foundation_stage where member_id=me and mission=1 for update;
if p_action='answer' and s<5 then
expected:=case s when 0 then 'HEX' when 1 then payload when 2 then '8' when 3 then h when 4 then 'HEX|8|'||h||'|PRESERVE' end;
accepted:=upper(trim(p_answer))=upper(expected);
if accepted then s:=s+1;update agc_ctf_private.foundation_stage set stage=s where member_id=me and mission=1;perform agc_ctf_private.record_assessment_stage(me,1,s,2);end if;
elsif p_action not in ('state','answer') then raise exception 'Nieznana operacja';end if;
return jsonb_build_object('stage',s,'accepted',accepted,'artifact',encode(convert_to(payload,'UTF8'),'hex'));
end $$;
CREATE OR REPLACE FUNCTION public.agc_ctf(p_action text, p_mission integer DEFAULT 1, p_answer text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me uuid:=auth.uid(); bal bigint; rec agc_ctf_private.progress%rowtype; code text; mode int; clue text;
begin
if me is null or not exists(select 1 from auth.users where id=me and not is_anonymous) then raise exception 'Zaloguj się na stałe konto'; end if;
if p_action='status' then return jsonb_build_object('balance',public.agc_coin_balance(),'tester',agc_ctf_private.is_tester(me),'available_missions',(select count(*) from agc_ctf_private.operation_catalog where ready),'missions',coalesce((select jsonb_agg(jsonb_build_object('mission',mission,'solved',solved) order by mission) from agc_ctf_private.progress where member_id=me),'[]'::jsonb)); end if;
if p_mission is null or not exists(select 1 from agc_ctf_private.operation_catalog where mission=p_mission and ready) then raise exception 'Operacja planowana — jeszcze niedostępna'; end if;
perform pg_advisory_xact_lock(731971);
select * into rec from agc_ctf_private.progress where member_id=me and mission=p_mission;
if not found then
if p_action<>'unlock' then raise exception 'Odblokuj misję'; end if;
if not agc_ctf_private.is_tester(me) and p_mission>1 and not exists(select 1 from agc_ctf_private.progress where member_id=me and mission=p_mission-1 and solved) then raise exception 'Ukończ poprzednią misję'; end if;
select coalesce(sum(amount),0) into bal from public.agc_coin_ledger where member_id=me;
if p_mission>10 and not agc_ctf_private.is_tester(me) and bal<10 then raise exception 'Za mało GCO'; end if;
if p_mission>10 and not agc_ctf_private.is_tester(me) then insert into public.agc_coin_ledger(member_id,amount,reason,request_id) values(me,-10,'Cyber War CTF: '||p_mission,gen_random_uuid()); end if;
insert into agc_ctf_private.progress(member_id,mission,secret) values(me,p_mission,replace(gen_random_uuid()::text,'-','')) returning * into rec;
end if;
code:='GENESIS{'||substr(rec.secret,1,8+p_mission/4)||'}'; mode:=(p_mission-1)%10;
if p_action='submit' then if p_mission=1 and not rec.solved and not exists(select 1 from agc_ctf_private.foundation_stage where member_id=me and mission=1 and version=2 and stage=5) then raise exception 'Ukończ raport OP001';end if; if p_mission in (9,10,11,12) and not exists (select 1 from agc_ctf_private.lab_state where member_id=me and mission=p_mission and stage=3) then raise exception 'Ukończ etapy analizy przed zatwierdzeniem flagi'; end if;
if rec.last_attempt>now()-interval '2 seconds' then raise exception 'Odczekaj 2 sekundy'; end if;
update agc_ctf_private.progress set last_attempt=now(),solved=solved or trim(p_answer)=code where member_id=me and mission=p_mission returning * into rec;
return jsonb_build_object('solved',rec.solved);
end if;
if p_action not in ('unlock','open') then raise exception 'Nieznana operacja'; end if;
clue:=case mode when 0 then encode(convert_to(code,'UTF8'),'hex') when 1 then encode(convert_to(code,'UTF8'),'base64') when 2 then reverse(code) when 3 then encode(convert_to(reverse(code),'UTF8'),'hex') when 4 then '2026-11-27 INFO health=ok'||chr(10)||'2026-11-27 WARN incident=confirmed evidence='||code||chr(10)||'2026-11-27 INFO health=ok' when 5 then jsonb_build_object('status','quarantined','evidence',code)::text when 6 then 'src,dst,action,payload'||chr(10)||'192.0.2.1,192.0.2.20,allow,heartbeat'||chr(10)||'192.0.2.30,192.0.2.40,deny,'||code when 7 then '[public]'||chr(10)||'debug=false'||chr(10)||'[incident]'||chr(10)||'artifact='||code when 8 then '<report><status>confirmed</status><evidence>'||code||'</evidence></report>' else 'sequence=3:'||substr(code,9)||chr(10)||'sequence=1:'||substr(code,1,4)||chr(10)||'sequence=2:'||substr(code,5,4) end;
if p_mission in (9,10,11,12) then clue:='R17_SERVER_LAB'; end if; return jsonb_build_object('mission',p_mission,'mode',mode,'clue',clue,'solved',rec.solved,'balance',public.agc_coin_balance());
end $function$
;
commit;
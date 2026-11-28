-- Dynamic arena availability; new CTFs are enabled by catalogue entries, not by editing tester grants.
CREATE TABLE IF NOT EXISTS agc_ctf_private.arena_operation_catalog(
  mission integer PRIMARY KEY CHECK (mission BETWEEN 1 AND 10000),
  title text NOT NULL,
  ready boolean NOT NULL DEFAULT false
);
ALTER TABLE agc_ctf_private.arena_operation_catalog ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON agc_ctf_private.arena_operation_catalog FROM PUBLIC,anon,authenticated;
INSERT INTO agc_ctf_private.arena_operation_catalog(mission,title,ready)
SELECT i,'Arena Training '||lpad(i::text,3,'0'),true FROM generate_series(1,20) AS i
ON CONFLICT(mission) DO NOTHING;
-- agc_ctf_arena
CREATE OR REPLACE FUNCTION public.agc_ctf_arena(p_action text, p_mission integer DEFAULT 1, p_answer text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me uuid:=auth.uid(); bal bigint; rec agc_ctf_private.arena_progress%rowtype; code text; mode int; clue text;
begin
if me is null or not exists(select 1 from auth.users where id=me and not is_anonymous) then raise exception 'Zaloguj się na stałe konto'; end if;
if p_action='status' then return jsonb_build_object('balance',public.agc_coin_balance(),'tester',agc_ctf_private.is_tester(me),'available_missions',(select count(*) from agc_ctf_private.arena_operation_catalog where ready),'missions',coalesce((select jsonb_agg(jsonb_build_object('mission',mission,'solved',solved) order by mission) from agc_ctf_private.arena_progress where member_id=me),'[]'::jsonb)); end if;
if p_mission is null or not exists(select 1 from agc_ctf_private.arena_operation_catalog where mission=p_mission and ready) then raise exception 'Zadanie Arena planowane — niedostępne'; end if;
perform pg_advisory_xact_lock(731971);
select * into rec from agc_ctf_private.arena_progress where member_id=me and mission=p_mission;
if not found then
if p_action<>'unlock' then raise exception 'Odblokuj misję'; end if;
if false and not exists(select 1 from agc_ctf_private.arena_progress where member_id=me and mission=p_mission-1 and solved) then raise exception 'Ukończ poprzednią misję'; end if;
select coalesce(sum(amount),0) into bal from public.agc_coin_ledger where member_id=me;
if p_mission>10 and not agc_ctf_private.is_tester(me) and bal<10 then raise exception 'Za mało GCO'; end if;
if p_mission>10 and not agc_ctf_private.is_tester(me) then insert into public.agc_coin_ledger(member_id,amount,reason,request_id) values(me,-10,'Cyber War CTF: '||p_mission,gen_random_uuid()); end if;
insert into agc_ctf_private.arena_progress(member_id,mission,secret) values(me,p_mission,replace(gen_random_uuid()::text,'-','')) returning * into rec;
end if;
code:='GENESIS{'||substr(rec.secret,1,8+p_mission/4)||'}'; mode:=(p_mission-1)%10;
if p_action='submit' then
if rec.last_attempt>now()-interval '2 seconds' then raise exception 'Odczekaj 2 sekundy'; end if;
update agc_ctf_private.arena_progress set last_attempt=now(),solved=solved or trim(p_answer)=code where member_id=me and mission=p_mission returning * into rec;
return jsonb_build_object('solved',rec.solved);
end if;
if p_action not in ('unlock','open') then raise exception 'Nieznana operacja'; end if;
clue:=case mode when 0 then encode(convert_to(code,'UTF8'),'hex') when 1 then encode(convert_to(code,'UTF8'),'base64') when 2 then reverse(code) when 3 then encode(convert_to(reverse(code),'UTF8'),'hex') when 4 then '2026-11-27 INFO health=ok'||chr(10)||'2026-11-27 WARN incident=confirmed evidence='||code||chr(10)||'2026-11-27 INFO health=ok' when 5 then jsonb_build_object('status','quarantined','evidence',code)::text when 6 then 'src,dst,action,payload'||chr(10)||'192.0.2.1,192.0.2.20,allow,heartbeat'||chr(10)||'192.0.2.30,192.0.2.40,deny,'||code when 7 then '[public]'||chr(10)||'debug=false'||chr(10)||'[incident]'||chr(10)||'artifact='||code when 8 then '<report><status>confirmed</status><evidence>'||code||'</evidence></report>' else 'sequence=3:'||substr(code,9)||chr(10)||'sequence=1:'||substr(code,1,4)||chr(10)||'sequence=2:'||substr(code,5,4) end;
return jsonb_build_object('mission',p_mission,'mode',mode,'clue',clue,'solved',rec.solved,'balance',public.agc_coin_balance());
end $function$
;

-- agc_ctf_arena_help
CREATE OR REPLACE FUNCTION public.agc_ctf_arena_help(p_mission integer, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me uuid:=auth.uid(); r agc_ctf_private.arena_progress%rowtype; a agc_ctf_private.arena_assistance%rowtype; m int; flag text; hints text[]:=array['Użyj decode hex.','Użyj decode base64.','Użyj reverse.','Najpierw decode hex, potem reverse.','Szukaj WARN.','Szukaj pola evidence.','Szukaj deny.','Szukaj artifact.','Szukaj elementu evidence.','Ułóż sequence 1, 2, 3.'];
begin
if me is null or not exists(select 1 from auth.users where id=me and not is_anonymous) then raise exception 'Zaloguj się'; end if;
perform pg_advisory_xact_lock(731971);
if p_action='status' then return jsonb_build_object('points',coalesce((select sum(case when agc_ctf_private.is_tester(me) then 1000 else 1000-200*coalesce(h.hint::int,0)-500*coalesce(h.review::int,0) end) from agc_ctf_private.arena_progress p left join agc_ctf_private.arena_assistance h using(member_id,mission) where p.member_id=me and p.solved),0)); end if;
if not exists(select 1 from agc_ctf_private.arena_operation_catalog where mission=p_mission and ready) then raise exception 'Zadanie Arena planowane'; end if; select * into r from agc_ctf_private.arena_progress where member_id=me and mission=p_mission; if not found then raise exception 'Odblokuj zadanie'; end if;
insert into agc_ctf_private.arena_assistance(member_id,mission) values(me,p_mission) on conflict do nothing;
select * into a from agc_ctf_private.arena_assistance where member_id=me and mission=p_mission;
m:=(p_mission-1)%10+1; flag:='GENESIS{'||substr(r.secret,1,8+p_mission/4)||'}';
if p_action='hint' then if not r.solved and not agc_ctf_private.is_tester(me) then update agc_ctf_private.arena_assistance set hint=true where member_id=me and mission=p_mission; end if; return jsonb_build_object('text',hints[m]); end if;
if p_action='review' then
if not r.solved and not a.review and not agc_ctf_private.is_tester(me) then
if public.agc_coin_balance()<500 then raise exception 'Za mało GCO'; end if;
insert into public.agc_coin_ledger(member_id,amount,reason,request_id) values(me,-500,'CTF omówienie: '||p_mission,gen_random_uuid());
update agc_ctf_private.arena_assistance set review=true where member_id=me and mission=p_mission;
end if;
return jsonb_build_object('text','1. scan; 2. connect soc; 3. cat /logs/audit.log; 4. połącz się z hostem wskazanym w logu i odczytaj plik w /evidence; 5. '||hints[m]||' 6. Prześlij flagę: '||flag);
end if; raise exception 'Nieznana operacja'; end $function$
;

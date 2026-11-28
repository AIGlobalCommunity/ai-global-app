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
if not r.solved and not exists(select 1 from auth.users u where u.id=me and lower(u.email)='mpiw123@gmail.com') then raise exception 'Omówienie dostępne po zaliczeniu flagi'; end if;
return jsonb_build_object('text','1. scan; 2. connect soc; 3. cat /logs/audit.log; 4. połącz się z hostem wskazanym w logu i odczytaj plik w /evidence; 5. '||hints[m]||' 6. Prześlij flagę: '||flag);
end if; raise exception 'Nieznana operacja'; end $function$
;
CREATE OR REPLACE FUNCTION public.agc_ctf_help(p_mission integer, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me uuid:=auth.uid(); r agc_ctf_private.progress%rowtype; a agc_ctf_private.assistance%rowtype; m int; flag text; hints text[]:=array['Użyj decode hex.','Użyj decode base64.','Użyj reverse.','Najpierw decode hex, potem reverse.','Szukaj WARN.','Szukaj pola evidence.','Szukaj deny.','Szukaj artifact.','Szukaj elementu evidence.','Ułóż sequence 1, 2, 3.'];
begin
if me is null or not exists(select 1 from auth.users where id=me and not is_anonymous) then raise exception 'Zaloguj się'; end if;
perform pg_advisory_xact_lock(731971);
if p_action='status' then return jsonb_build_object('points',coalesce((select sum(case when agc_ctf_private.is_tester(me) then 1000 else 1000-200*coalesce(h.hint::int,0)-500*coalesce(h.review::int,0) end) from agc_ctf_private.progress p left join agc_ctf_private.assistance h using(member_id,mission) where p.member_id=me and p.solved),0)); end if;
if not exists(select 1 from agc_ctf_private.operation_catalog where mission=p_mission and ready) then raise exception 'Operacja planowana'; end if; select * into r from agc_ctf_private.progress where member_id=me and mission=p_mission; if not found then raise exception 'Odblokuj zadanie'; end if;
insert into agc_ctf_private.assistance(member_id,mission) values(me,p_mission) on conflict do nothing;
select * into a from agc_ctf_private.assistance where member_id=me and mission=p_mission;
m:=(p_mission-1)%10+1; flag:='GENESIS{'||substr(r.secret,1,8+p_mission/4)||'}';
if p_action='hint' then if not r.solved and not agc_ctf_private.is_tester(me) then update agc_ctf_private.assistance set hint=true where member_id=me and mission=p_mission; end if; return jsonb_build_object('text',hints[m]); end if;
if p_action='review' then
if not r.solved and not exists(select 1 from auth.users u where u.id=me and lower(u.email)='mpiw123@gmail.com') then raise exception 'Omówienie dostępne po zaliczeniu flagi'; end if;
return jsonb_build_object('text','1. scan; 2. connect soc; 3. cat /logs/audit.log; 4. połącz się z hostem wskazanym w logu i odczytaj plik w /evidence; 5. '||hints[m]||' 6. Prześlij flagę: '||flag);
end if; raise exception 'Nieznana operacja'; end $function$

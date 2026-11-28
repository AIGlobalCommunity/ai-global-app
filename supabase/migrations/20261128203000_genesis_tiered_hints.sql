create table if not exists agc_ctf_private.hint_purchase(member_id uuid not null, arena boolean not null, mission integer not null, level integer not null check(level between 1 and 4), primary key(member_id,arena,mission,level)); alter table agc_ctf_private.hint_purchase enable row level security; revoke all on agc_ctf_private.hint_purchase from public,anon,authenticated;
CREATE OR REPLACE FUNCTION public.agc_ctf_help(p_mission integer, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me uuid:=auth.uid(); r agc_ctf_private.progress%rowtype; a agc_ctf_private.assistance%rowtype; m int; flag text; lvl int; cost int; bal bigint; bought boolean; texts text[][]:=array[['Zbadaj ślady transmisji.','Sprawdź gateway, SOC i archive.','Rozpoznaj kodowanie bajtów.','cat /evidence/payload.hex; decode hex <dane>'],['Zbadaj transmisje.','Sprawdź gateway, SOC i vault.','Rozpoznaj kodowanie tekstowe.','ls /signals; decodefile base64 <ścieżka>'],['Ustal kolejność fragmentów.','Sprawdź SOC i workstation.','Połącz fragmenty i odwróć tekst.','cat /evidence/order.csv; joinfiles <ścieżki>; reverse <tekst>'],['Ustal format fragmentów.','Sprawdź SOC i archive.','Połącz, dekoduj HEX i odwróć.','joinfiles <ścieżki>; decode hex <tekst>; reverse <tekst>'],['Skoreluj incydent.','Sprawdź log gateway i SOC.','Powiąż identyfikatory REQ.','cat /logs/incident.log; cat /evidence/correlation.csv'],['Zweryfikuj dowody.','Sprawdź SOC i vault.','Porównaj SHA-256 z manifestem.','cat /evidence/manifest.csv; sha256sum <ścieżka>'],['Zbadaj nietypowy ruch.','Sprawdź gateway i SOC.','Skoreluj przepływy i pakiety.','cat /captures/packets.csv; cat /evidence/flow-index.csv'],['Porównaj konfigurację z polityką.','Sprawdź SOC i gateway.','Wykryj odstępstwa i odtwórz zmiany.','cat /policy/baseline.csv; cat /etc/ssh/sshd_config'],['Skoreluj dokumenty.','Sprawdź archive i manifest SOC.','Porównaj integralność, ticket i czas.','ls /documents; metadata ID; sha256sum ID; timeline'],['Sprawdź integralność bloków.','Sprawdź vault i manifest.','Odrzuć błędne sumy, uporządkuj offsety.','ls /blocks; sha256sum ID; reconstruct ID,ID,...'],['Skoreluj anomalie logowania.','Sprawdź dokumenty IAM w archive.','Powiąż MFA, urządzenie i zmianę roli.','ls; cat ID; timeline; raport DECYZJA|KONTO|DOWODY|TYPY'],['Zbadaj zachowanie artefaktów.','Sprawdź raporty w archive.','Porównaj IOC, procesy i zachowanie.','ls; cat ID; strings ID; hexdump ID']]; hints text[]:=array['Użyj decode hex.','Użyj decode base64.','Użyj reverse.','Najpierw decode hex, potem reverse.','Szukaj WARN.','Szukaj pola evidence.','Szukaj deny.','Szukaj artifact.','Szukaj elementu evidence.','Ułóż sequence 1, 2, 3.'];
begin
if me is null or not exists(select 1 from auth.users where id=me and not is_anonymous) then raise exception 'Zaloguj się'; end if;
perform pg_advisory_xact_lock(731971);
if p_action='status' then return jsonb_build_object('points',coalesce((select sum(case when agc_ctf_private.is_tester(me) then 1000 else 1000-200*coalesce(h.hint::int,0)-500*coalesce(h.review::int,0) end) from agc_ctf_private.progress p left join agc_ctf_private.assistance h using(member_id,mission) where p.member_id=me and p.solved),0)); end if;
if not exists(select 1 from agc_ctf_private.operation_catalog where mission=p_mission and ready) then raise exception 'Operacja planowana'; end if; select * into r from agc_ctf_private.progress where member_id=me and mission=p_mission; if not found then raise exception 'Odblokuj zadanie'; end if;
insert into agc_ctf_private.assistance(member_id,mission) values(me,p_mission) on conflict do nothing;
select * into a from agc_ctf_private.assistance where member_id=me and mission=p_mission;
m:=(p_mission-1)%10+1; flag:='GENESIS{'||substr(r.secret,1,8+p_mission/4)||'}';
if p_action='hint_status' then return jsonb_build_object('levels',coalesce((select jsonb_agg(level order by level) from agc_ctf_private.hint_purchase where member_id=me and arena=false and mission=p_mission),'[]'::jsonb)); end if;
if p_action='hint' or p_action ~ '^hint[1-4]
if p_action='review' then
if not r.solved and not exists(select 1 from auth.users u where u.id=me and lower(u.email)='mpiw123@gmail.com') then raise exception 'Omówienie dostępne po zaliczeniu flagi'; end if;
return jsonb_build_object('text','1. scan; 2. connect soc; 3. cat /logs/audit.log; 4. połącz się z hostem wskazanym w logu i odczytaj plik w /evidence; 5. '||hints[m]||' 6. Prześlij flagę: '||flag);
end if; raise exception 'Nieznana operacja'; end $function$
 then
lvl:=case when p_action='hint' then 1 else right(p_action,1)::int end;
cost:=(array[1,2,3,5])[lvl];
select exists(select 1 from agc_ctf_private.hint_purchase where member_id=me and arena=false and mission=p_mission and level=lvl) into bought;
if not bought then
if not agc_ctf_private.is_tester(me) and not r.solved then
if lvl>1 and not exists(select 1 from agc_ctf_private.hint_purchase where member_id=me and arena=false and mission=p_mission and level=lvl-1) then raise exception 'Najpierw odblokuj poprzedni poziom'; end if;
select coalesce(sum(amount),0) into bal from public.agc_coin_ledger where member_id=me;
if bal<cost then raise exception 'Za mało GCO'; end if;
insert into public.agc_coin_ledger(member_id,amount,reason,request_id) values(me,-cost,'Cyber War hint campaign '||p_mission||'/'||lvl,gen_random_uuid());
end if;
insert into agc_ctf_private.hint_purchase values(me,false,p_mission,lvl);
end if;
return jsonb_build_object('text',texts[p_mission][lvl],'level',lvl,'balance',public.agc_coin_balance());
end if;
if p_action='review' then
if not r.solved and not exists(select 1 from auth.users u where u.id=me and lower(u.email)='mpiw123@gmail.com') then raise exception 'Omówienie dostępne po zaliczeniu flagi'; end if;
return jsonb_build_object('text','1. scan; 2. connect soc; 3. cat /logs/audit.log; 4. połącz się z hostem wskazanym w logu i odczytaj plik w /evidence; 5. '||hints[m]||' 6. Prześlij flagę: '||flag);
end if; raise exception 'Nieznana operacja'; end $function$
;
CREATE OR REPLACE FUNCTION public.agc_ctf_arena_help(p_mission integer, p_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me uuid:=auth.uid(); r agc_ctf_private.arena_progress%rowtype; a agc_ctf_private.arena_assistance%rowtype; m int; flag text; lvl int; cost int; bal bigint; bought boolean; texts text[][]:=array[['Zbadaj dostępne ślady.','Sprawdź log SOC i host wskazany w logu.','Rozpoznaj format danych i kolejność.','scan; connect soc; cat /logs/audit.log; decode hex'],['Zbadaj dostępne ślady.','Sprawdź log SOC i host wskazany w logu.','Rozpoznaj format danych i kolejność.','scan; connect soc; cat /logs/audit.log; decode base64'],['Zbadaj dostępne ślady.','Sprawdź log SOC i host wskazany w logu.','Rozpoznaj format danych i kolejność.','scan; connect soc; cat /logs/audit.log; reverse'],['Zbadaj dostępne ślady.','Sprawdź log SOC i host wskazany w logu.','Rozpoznaj format danych i kolejność.','scan; connect soc; cat /logs/audit.log; decode hex; reverse'],['Zbadaj dostępne ślady.','Sprawdź log SOC i host wskazany w logu.','Rozpoznaj format danych i kolejność.','scan; connect soc; cat /logs/audit.log; grep WARN'],['Zbadaj dostępne ślady.','Sprawdź log SOC i host wskazany w logu.','Rozpoznaj format danych i kolejność.','scan; connect soc; cat /logs/audit.log; grep evidence'],['Zbadaj dostępne ślady.','Sprawdź log SOC i host wskazany w logu.','Rozpoznaj format danych i kolejność.','scan; connect soc; cat /logs/audit.log; grep deny'],['Zbadaj dostępne ślady.','Sprawdź log SOC i host wskazany w logu.','Rozpoznaj format danych i kolejność.','scan; connect soc; cat /logs/audit.log; grep artifact'],['Zbadaj dostępne ślady.','Sprawdź log SOC i host wskazany w logu.','Rozpoznaj format danych i kolejność.','scan; connect soc; cat /logs/audit.log; grep evidence'],['Zbadaj dostępne ślady.','Sprawdź log SOC i host wskazany w logu.','Rozpoznaj format danych i kolejność.','scan; connect soc; cat /logs/audit.log; sort']]; hints text[]:=array['Użyj decode hex.','Użyj decode base64.','Użyj reverse.','Najpierw decode hex, potem reverse.','Szukaj WARN.','Szukaj pola evidence.','Szukaj deny.','Szukaj artifact.','Szukaj elementu evidence.','Ułóż sequence 1, 2, 3.'];
begin
if me is null or not exists(select 1 from auth.users where id=me and not is_anonymous) then raise exception 'Zaloguj się'; end if;
perform pg_advisory_xact_lock(731971);
if p_action='status' then return jsonb_build_object('points',coalesce((select sum(case when agc_ctf_private.is_tester(me) then 1000 else 1000-200*coalesce(h.hint::int,0)-500*coalesce(h.review::int,0) end) from agc_ctf_private.arena_progress p left join agc_ctf_private.arena_assistance h using(member_id,mission) where p.member_id=me and p.solved),0)); end if;
if not exists(select 1 from agc_ctf_private.arena_operation_catalog where mission=p_mission and ready) then raise exception 'Zadanie Arena planowane'; end if; select * into r from agc_ctf_private.arena_progress where member_id=me and mission=p_mission; if not found then raise exception 'Odblokuj zadanie'; end if;
insert into agc_ctf_private.arena_assistance(member_id,mission) values(me,p_mission) on conflict do nothing;
select * into a from agc_ctf_private.arena_assistance where member_id=me and mission=p_mission;
m:=(p_mission-1)%10+1; flag:='GENESIS{'||substr(r.secret,1,8+p_mission/4)||'}';
if p_action='hint_status' then return jsonb_build_object('levels',coalesce((select jsonb_agg(level order by level) from agc_ctf_private.hint_purchase where member_id=me and arena=true and mission=p_mission),'[]'::jsonb)); end if;
if p_action='hint' or p_action ~ '^hint[1-4]
if p_action='review' then
if not r.solved and not exists(select 1 from auth.users u where u.id=me and lower(u.email)='mpiw123@gmail.com') then raise exception 'Omówienie dostępne po zaliczeniu flagi'; end if;
return jsonb_build_object('text','1. scan; 2. connect soc; 3. cat /logs/audit.log; 4. połącz się z hostem wskazanym w logu i odczytaj plik w /evidence; 5. '||hints[m]||' 6. Prześlij flagę: '||flag);
end if; raise exception 'Nieznana operacja'; end $function$
 then
lvl:=case when p_action='hint' then 1 else right(p_action,1)::int end;
cost:=(array[1,2,3,5])[lvl];
select exists(select 1 from agc_ctf_private.hint_purchase where member_id=me and arena=true and mission=p_mission and level=lvl) into bought;
if not bought then
if not agc_ctf_private.is_tester(me) and not r.solved then
if lvl>1 and not exists(select 1 from agc_ctf_private.hint_purchase where member_id=me and arena=true and mission=p_mission and level=lvl-1) then raise exception 'Najpierw odblokuj poprzedni poziom'; end if;
select coalesce(sum(amount),0) into bal from public.agc_coin_ledger where member_id=me;
if bal<cost then raise exception 'Za mało GCO'; end if;
insert into public.agc_coin_ledger(member_id,amount,reason,request_id) values(me,-cost,'Cyber War hint arena '||p_mission||'/'||lvl,gen_random_uuid());
end if;
insert into agc_ctf_private.hint_purchase values(me,true,p_mission,lvl);
end if;
return jsonb_build_object('text',texts[m][lvl],'level',lvl,'balance',public.agc_coin_balance());
end if;
if p_action='review' then
if not r.solved and not exists(select 1 from auth.users u where u.id=me and lower(u.email)='mpiw123@gmail.com') then raise exception 'Omówienie dostępne po zaliczeniu flagi'; end if;
return jsonb_build_object('text','1. scan; 2. connect soc; 3. cat /logs/audit.log; 4. połącz się z hostem wskazanym w logu i odczytaj plik w /evidence; 5. '||hints[m]||' 6. Prześlij flagę: '||flag);
end if; raise exception 'Nieznana operacja'; end $function$
;

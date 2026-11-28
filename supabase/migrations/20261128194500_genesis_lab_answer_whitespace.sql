CREATE OR REPLACE FUNCTION public.agc_ctf_lab(p_action text, p_mission integer, p_answer text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 me uuid:=auth.uid(); s agc_ctf_private.lab_state%rowtype;
 r agc_ctf_private.progress%rowtype; v jsonb; items jsonb:='[]'::jsonb;
 case_id text; id text; body text; source text; category text; tm text;
 checksum text; ticket text; plain text; sha text;
 rejects text:=''; ordered text:=''; sources text; timeline text;
 i int; seq int; target text; next_stage int; ok boolean; flag text;
begin
 if me is null or not exists(select 1 from auth.users u where u.id=me and not u.is_anonymous)
 then raise exception 'Zaloguj się na stałe konto'; end if;
 if p_mission not in (9,10) then raise exception 'Nieobsługiwana operacja'; end if;
 if not exists(select 1 from agc_ctf_private.operation_catalog where mission=p_mission and ready)
 then raise exception 'Operacja nie jest jeszcze dostępna'; end if;
 select * into r from agc_ctf_private.progress where member_id=me and mission=p_mission;
 if not found then raise exception 'Najpierw odblokuj operację'; end if;
 perform pg_advisory_xact_lock(hashtext(me::text||':'||p_mission::text));
 select * into s from agc_ctf_private.lab_state where member_id=me and mission=p_mission for update;
 if not found then
  if p_action <> 'state' then raise exception 'Otwórz laboratorium'; end if;
  case_id:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
  if p_mission=9 then
   ticket:='BLACK-ORBIT-'||case_id;
   for i in 1..24 loop
    id:='DOC-'||lpad(i::text,2,'0')||'-'||case_id;
    source:=(array['HELIX ARCHIVE','NOVA SIGNALS','VANTA CONTROL','ATLAS SOC','ORBIT RECORDS','MIRROR DISPATCH'])[1+(i-1)%6];
    category:=(array['TXT','JSON','HTML','MAIL'])[1+(i-1)%4];
    tm:='2035-04-21T08:'||lpad(((i*3+7)%55)::text,2,'0')||':00Z';
    body:='BLACK ORBIT / '||source||' / '||i::text;
    if i=16 then
     tm:='2035-04-21T08:05:00Z';
     body:='BLACK ORBIT verified incident / initial anomaly at 08:05Z. Correlation '||ticket||'.';
    elsif i=4 then
     tm:='2035-04-21T08:13:00Z';
     body:='BLACK ORBIT verified identity breach at 08:13Z. Correlation '||ticket||'.';
    elsif i=9 then
     tm:='2035-04-21T08:27:00Z';
     body:='BLACK ORBIT verified endpoint impact at 08:27Z. Decision: CONTAIN. Correlation '||ticket||'.';
    else
     body:='Unconfirmed synthetic dispatch from '||source||'. Reported event '||i||'. Ref '||id;
    end if;
    checksum:=encode(extensions.digest(convert_to(body,'UTF8'),'sha256'),'hex');
    if i%5=0 and i not in (4,9,16) then
     checksum:=encode(extensions.digest(convert_to(body||'altered','UTF8'),'sha256'),'hex');
    end if;
    items:=items||jsonb_build_array(jsonb_build_object(
     'id',id,'source',source,'format',category,'author','operator-'||((i%9)+1),
     'revision',1+i%4,'modified_at',tm,'ticket',case when i in (4,9,16) then ticket else 'UNVERIFIED-'||i end,
     'content',body,'sha256',checksum,'access','CASE-'||case_id,'filename','/documents/'||id||'.txt'));
   end loop;
   sources:='DOC-04-'||case_id||',DOC-09-'||case_id||',DOC-16-'||case_id;
   timeline:='DOC-16-'||case_id||',DOC-04-'||case_id||',DOC-09-'||case_id;
   v:=jsonb_build_object('case',case_id,'documents',items,'sources',sources,'timeline',timeline);
  else
   plain:=rpad('BLACK-ORBIT|CASE='||case_id||'|2035-04-21|SOURCE=HELIX|INCIDENT=CONFIRMED|ACTION=CONTAIN|RECONSTRUCTION=AUTHORIZED|',192,'|SYNTHETIC-FORENSIC-TRACE|');
   sha:=encode(extensions.digest(convert_to(plain,'UTF8'),'sha256'),'hex');
   for i in 1..32 loop
    id:='BLK-'||lpad(i::text,2,'0')||'-'||case_id;
    seq:=case when i<=24 then i else i-24 end;
    body:=case when i<=24 then substr(plain,(i-1)*8+1,8) else substr('DECOY'||lpad(i::text,3,'0'),1,8) end;
    checksum:=encode(extensions.digest(convert_to(body,'UTF8'),'sha256'),'hex');
    if i>24 then checksum:=encode(extensions.digest(convert_to(body||':corrupt','UTF8'),'sha256'),'hex'); end if;
    items:=items||jsonb_build_array(jsonb_build_object(
     'id',id,'sequence',seq,'offset',(seq-1)*8,'bytes',8,'format','HEX',
     'data',encode(convert_to(body,'UTF8'),'hex'),'sha256',checksum,
     'captured_at','2035-04-21T08:'||lpad(((i*13+17)%60)::text,2,'0')||':00Z',
     'sort',md5(case_id||':'||i::text),'filename','/blocks/'||id||'.hex'));
    if i<=24 then ordered:=ordered||case when i>1 then ',' else '' end||id;
    else rejects:=rejects||case when i>25 then ',' else '' end||id; end if;
   end loop;
   select jsonb_agg(x order by x->>'sort') into items from jsonb_array_elements(items) x;
   v:=jsonb_build_object('case',case_id,'blocks',items,'reject',rejects,'order',ordered,
     'stream_sha256',sha,'stream_bytes',192);
  end if;
  insert into agc_ctf_private.lab_state(member_id,mission,variant) values(me,p_mission,v) on conflict do nothing;
  select * into s from agc_ctf_private.lab_state where member_id=me and mission=p_mission for update;
 end if;
 flag:='GENESIS{'||substr(r.secret,1,8+p_mission/4)||'}';
 if p_action='state' then return jsonb_build_object(
  'stage',s.stage,'case',s.variant->>'case',
  'documents',case when p_mission=9 then s.variant->'documents' else null end,
  'blocks',case when p_mission=10 then s.variant->'blocks' else null end,
  'stream_bytes',case when p_mission=10 then s.variant->'stream_bytes' else null end,
  'stream_sha256',case when p_mission=10 then s.variant->'stream_sha256' else null end,
  'flag',case when s.stage=3 then flag else null end);
 end if;
 if p_action not in ('sources','timeline','report','integrity','reconstruct','verify')
 then raise exception 'Nieznana akcja laboratorium'; end if;
 if s.last_attempt>now()-interval '1 second' then raise exception 'Zaczekaj przed następną próbą'; end if;
 if length(p_answer)>1600 then raise exception 'Odpowiedź jest zbyt długa'; end if;
 if p_mission=9 then
  if p_action='sources' and s.stage=0 then target:=s.variant->>'sources';next_stage:=1;
  elsif p_action='timeline' and s.stage=1 then target:=s.variant->>'timeline';next_stage:=2;
  elsif p_action='report' and s.stage=2 then target:='CONTAIN';next_stage:=3;
  else raise exception 'Nieprawidłowy etap %',s.stage; end if;
 else
  if p_action='integrity' and s.stage=0 then target:=s.variant->>'reject';next_stage:=1;
  elsif p_action='reconstruct' and s.stage=1 then target:=s.variant->>'order';next_stage:=2;
  elsif p_action='verify' and s.stage=2 then target:=s.variant->>'stream_sha256';next_stage:=3;
  else raise exception 'Nieprawidłowy etap %',s.stage; end if;
 end if;
 ok:=upper(regexp_replace(trim(p_answer),'[[:space:]]+','','g'))=upper(target);
 update agc_ctf_private.lab_state set stage=case when ok then next_stage else s.stage end,
 last_attempt=now() where member_id=me and mission=p_mission;
 return jsonb_build_object('accepted',ok,'stage',case when ok then next_stage else s.stage end,
 'flag',case when ok and next_stage=3 then flag else null end);
end $function$

begin;
update agc_ctf_private.operation_catalog set ready=true where mission in (11,12);
select set_config('request.jwt.claim.sub',(select id::text from auth.users where email='mpiw123@gmail.com'),true);
do $test$ declare m int; v jsonb; s jsonb; ans text; z jsonb; bal bigint; begin
bal:=public.agc_coin_balance();
for m in 11..12 loop
v:=public.agc_ctf('unlock',m,''); v:=public.agc_ctf_lab('state',m,'');
if jsonb_array_length(v->'documents')<>(case when m=11 then 60 else 20 end) then raise exception 'wrong count %',m; end if;
select variant into s from agc_ctf_private.lab_state where member_id=auth.uid() and mission=m;
update agc_ctf_private.lab_state set stage=0,last_attempt=null where member_id=auth.uid() and mission=m;
z:=public.agc_ctf_lab('sources',m,'WRONG'); if (z->>'accepted')::boolean then raise exception 'wrong accepted'; end if;
update agc_ctf_private.lab_state set last_attempt=null where member_id=auth.uid() and mission=m;
z:=public.agc_ctf_lab('sources',m,s->>'sources'); if (z->>'stage')::int<>1 then raise exception 'stage 1 failed'; end if;
update agc_ctf_private.lab_state set last_attempt=null where member_id=auth.uid() and mission=m;
z:=public.agc_ctf_lab('timeline',m,s->>'timeline'); if (z->>'stage')::int<>2 then raise exception 'stage 2 failed'; end if;
update agc_ctf_private.lab_state set last_attempt=null where member_id=auth.uid() and mission=m;
ans:=(case when m=11 then 'REVOKE' else 'ISOLATE' end)||'|'||(s->>'sources')||'|'||(s->>'timeline')||'|'||(case when m=11 then 'MFA_DENIED,LOGIN_NEW_DEVICE,ROLE_CHANGED' else 'UNEXPECTED_OUTBOUND_EVENT' end);
z:=public.agc_ctf_lab('report',m,ans); if (z->>'stage')::int<>3 then raise exception 'stage 3 failed'; end if;
v:=public.agc_ctf('submit',m,z->>'flag'); if not (v->>'solved')::boolean then raise exception 'flag failed'; end if;
end loop;
if public.agc_coin_balance()<>bal then raise exception 'tester charged'; end if;
end $test$;
select 'PASS' as result; rollback;
begin;
select set_config('request.jwt.claim.sub',(select id::text from auth.users where email='mpiw123@gmail.com'),true);
do $t$ declare u uuid:=auth.uid(); ar boolean; m int; l int; b bigint; cost int; h jsonb; rejected boolean; begin
delete from agc_ctf_private.testers where member_id=u;
if agc_ctf_private.is_tester(u) then raise exception 'tester still active'; end if;
foreach ar in array array[false,true] loop
foreach m in array array[11,12] loop
if ar then insert into agc_ctf_private.arena_progress(member_id,mission,secret,solved) values(u,m,'payment-test',false) on conflict(member_id,mission) do update set solved=false;
else insert into agc_ctf_private.progress(member_id,mission,secret,solved) values(u,m,'payment-test',false) on conflict(member_id,mission) do update set solved=false; end if;
delete from agc_ctf_private.hint_purchase where member_id=u and arena=ar and mission=m;
b:=public.agc_coin_balance(); if b<11 then insert into public.agc_coin_ledger(member_id,amount,reason,request_id) values(u,11-b,'rollback payment test',gen_random_uuid()); end if;
b:=public.agc_coin_balance(); rejected:=false;
begin if ar then perform public.agc_ctf_arena_help(m,'hint2'); else perform public.agc_ctf_help(m,'hint2'); end if; exception when others then if sqlerrm like '%poprzedni poziom%' then rejected:=true; else raise; end if; end;
if not rejected or public.agc_coin_balance()<>b then raise exception 'skip failed'; end if;
for l in 1..4 loop
cost:=(array[1,2,3,5])[l]; b:=public.agc_coin_balance();
if ar then h:=public.agc_ctf_arena_help(m,'hint'||l); else h:=public.agc_ctf_help(m,'hint'||l); end if;
if public.agc_coin_balance()<>b-cost or coalesce(h->>'text','')='' then raise exception 'charge failed % % %',ar,m,l; end if;
if ar then perform public.agc_ctf_arena_help(m,'hint'||l); else perform public.agc_ctf_help(m,'hint'||l); end if;
if public.agc_coin_balance()<>b-cost then raise exception 'double charge'; end if;
end loop;
delete from agc_ctf_private.hint_purchase where member_id=u and arena=ar and mission=m;
b:=public.agc_coin_balance(); if b>0 then insert into public.agc_coin_ledger(member_id,amount,reason,request_id) values(u,-b,'rollback zero balance test',gen_random_uuid()); end if;
rejected:=false; begin if ar then perform public.agc_ctf_arena_help(m,'hint1'); else perform public.agc_ctf_help(m,'hint1'); end if; exception when others then if sqlerrm like '%Za mało GCO%' then rejected:=true; else raise; end if; end;
if not rejected or public.agc_coin_balance()<>0 or exists(select 1 from agc_ctf_private.hint_purchase where member_id=u and arena=ar and mission=m) then raise exception 'insufficient balance failed'; end if;
end loop; end loop; end $t$;
select 'PASS: campaign and arena 11/12, all prices, repeat, skip, insufficient funds' as result; rollback;
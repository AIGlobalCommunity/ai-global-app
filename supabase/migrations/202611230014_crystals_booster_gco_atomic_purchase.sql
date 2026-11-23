-- Purchases are debited atomically from the existing GCO ledger.
-- A unique request UUID prevents duplicate charges on network retries.
create or replace function public.agc_crystals_booster_buy(p_booster text,p_request uuid)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare me uuid:=auth.uid(); price bigint; balance bigint; prior bigint;
begin
 if me is null or not exists(select 1 from auth.users where id=me and not is_anonymous) then
  raise exception 'Zaloguj się na konto The Genesis Era';
 end if;
 if p_request is null then raise exception 'Brak identyfikatora zakupu'; end if;
 price:=case p_booster when 'hammer' then 10 when 'bomb' then 25 when 'shuffle' then 15 else null end;
 if price is null then raise exception 'Nieznane ulepszenie'; end if;
 perform pg_advisory_xact_lock(731971);
 select amount into prior from public.agc_coin_ledger where member_id=me and request_id=p_request limit 1;
 if prior is not null then
  if prior<>-price or not exists(select 1 from public.agc_coin_ledger where member_id=me and request_id=p_request and reason='Crystals booster: '||p_booster) then
   raise exception 'Identyfikator zakupu już wykorzystany';
  end if;
  select coalesce(sum(amount),0) into balance from public.agc_coin_ledger where member_id=me;
  return jsonb_build_object('ok',true,'booster',p_booster,'balance',balance,'duplicate',true);
 end if;
 select coalesce(sum(amount),0) into balance from public.agc_coin_ledger where member_id=me;
 if balance<price then raise exception 'Za mało GCO. Dostępne: %, wymagane: %',balance,price; end if;
 insert into public.agc_coin_ledger(member_id,amount,reason,request_id)
 values(me,-price,'Crystals booster: '||p_booster,p_request);
 return jsonb_build_object('ok',true,'booster',p_booster,'balance',balance-price,'duplicate',false);
end;
$$;
revoke all on function public.agc_crystals_booster_buy(text,uuid) from public,anon;
grant execute on function public.agc_crystals_booster_buy(text,uuid) to authenticated;

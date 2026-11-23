create or replace function public.agc_crystals_booster_buy(p_booster text,p_request uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare me uuid:=auth.uid(); price bigint; balance bigint; prior bigint; prior_booster text; bought bigint;
begin
 if me is null or not exists(select 1 from auth.users where id=me and not is_anonymous) then
  raise exception 'Zaloguj się na konto The Genesis Era';
 end if;
 if p_request is null then raise exception 'Brak identyfikatora zakupu'; end if;
 if p_booster not in ('hammer','bomb','shuffle') or p_booster is null then raise exception 'Nieznane ulepszenie'; end if;
 perform pg_advisory_xact_lock(731971);
 select amount,reason into prior,prior_booster from public.agc_coin_ledger where member_id=me and request_id=p_request limit 1;
 if prior is not null then
  if prior_booster <> 'Crystals booster: '||p_booster then raise exception 'Identyfikator zakupu już wykorzystany'; end if;
  select coalesce(sum(amount),0) into balance from public.agc_coin_ledger where member_id=me;
  select count(*) into bought from public.agc_coin_ledger where member_id=me and reason like 'Crystals booster: %';
  return jsonb_build_object('ok',true,'booster',p_booster,'balance',balance,'price',-prior,'next_price',least(5,bought+1),'purchase_count',bought,'duplicate',true);
 end if;
 select count(*) into bought from public.agc_coin_ledger where member_id=me and reason like 'Crystals booster: %';
 price:=least(5,bought+1);
 select coalesce(sum(amount),0) into balance from public.agc_coin_ledger where member_id=me;
 if balance<price then raise exception 'Za mało GCO. Dostępne: %, wymagane: %',balance,price; end if;
 insert into public.agc_coin_ledger(member_id,amount,reason,request_id)
 values(me,-price,'Crystals booster: '||p_booster,p_request);
 return jsonb_build_object('ok',true,'booster',p_booster,'balance',balance-price,'price',price,'next_price',least(5,bought+2),'purchase_count',bought+1,'duplicate',false);
end;
$$;
revoke all on function public.agc_crystals_booster_buy(text,uuid) from public,anon;
grant execute on function public.agc_crystals_booster_buy(text,uuid) to authenticated;

create or replace function public.agc_crystals_shop_status()
returns jsonb language sql stable security definer set search_path=''
as $$
 select jsonb_build_object('balance',(select coalesce(sum(amount),0) from public.agc_coin_ledger where member_id=(select auth.uid())),
 'next_price',least(5,1+(select count(*) from public.agc_coin_ledger where member_id=(select auth.uid()) and reason like 'Crystals booster: %')),
 'purchase_count',(select count(*) from public.agc_coin_ledger where member_id=(select auth.uid()) and reason like 'Crystals booster: %'))
 where (select auth.uid()) is not null
$$;
revoke all on function public.agc_crystals_shop_status() from public,anon;
grant execute on function public.agc_crystals_shop_status() to authenticated;

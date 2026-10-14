-- Real referrals: award 100 GP only when the invited account verifies its email.
-- The referral code is stored in auth.users.raw_user_meta_data at signup.
-- Existing unique agc_referrals.invited_id and agc_points.source_key prevent duplicates.
create or replace function public.agc_reward_invite_on_confirmation()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  inviter uuid;
  referral text;
begin
  if new.email_confirmed_at is null then return new; end if;
  if tg_op = 'UPDATE' and old.email_confirmed_at is not null then return new; end if;
  referral := upper(trim(coalesce(new.raw_user_meta_data ->> 'referral_code', '')));
  if referral !~ '^[A-Z0-9_-]{4,64}$' then return new; end if;
  select id into inviter from public.agc_profiles where referral_code = referral;
  if inviter is null or inviter = new.id then return new; end if;
  if not exists (select 1 from public.agc_profiles where id = new.id) then return new; end if;
  insert into public.agc_referrals(invited_id, inviter_id, rewarded_at)
    values (new.id, inviter, now()) on conflict (invited_id) do nothing;
  if found then
    insert into public.agc_points(member_id, points, reason, source_key)
    values (inviter, 100, 'verified_referral', 'referral:' || new.id::text)
    on conflict (source_key) do nothing;
  end if;
  return new;
end;
$$;
drop trigger if exists zz_agc_invite_confirmed on auth.users;
create trigger zz_agc_invite_confirmed
after insert or update of email_confirmed_at on auth.users
for each row execute function public.agc_reward_invite_on_confirmation();

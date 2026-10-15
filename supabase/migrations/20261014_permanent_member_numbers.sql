-- Permanent public member numbers, assigned in registration order.
CREATE SEQUENCE IF NOT EXISTS public.agc_member_number_seq AS bigint START WITH 1;
ALTER TABLE public.agc_profiles ADD COLUMN IF NOT EXISTS member_number bigint;
WITH numbered AS (
  SELECT id, row_number() OVER (ORDER BY created_at, id) AS n
  FROM public.agc_profiles WHERE member_number IS NULL
)
UPDATE public.agc_profiles p SET member_number = numbered.n +
  COALESCE((SELECT max(member_number) FROM public.agc_profiles), 0)
FROM numbered WHERE p.id = numbered.id;
SELECT setval('public.agc_member_number_seq',
  GREATEST(COALESCE((SELECT max(member_number) FROM public.agc_profiles), 0), 1),
  COALESCE((SELECT max(member_number) FROM public.agc_profiles), 0) > 0);
ALTER TABLE public.agc_profiles
  ALTER COLUMN member_number SET DEFAULT nextval('public.agc_member_number_seq'),
  ALTER COLUMN member_number SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS agc_profiles_member_number_unique
  ON public.agc_profiles (member_number);
CREATE OR REPLACE VIEW public.agc_leaderboard AS
SELECT s.id, s.handle, s.country_code, s.created_at, s.genesis_points,
  row_number() OVER (ORDER BY s.genesis_points DESC, s.created_at, s.id) AS place,
  p.member_number
FROM public.agc_public_scores s
JOIN public.agc_profiles p ON p.id = s.id
WHERE p.is_demo = false;

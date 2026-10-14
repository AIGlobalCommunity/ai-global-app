-- Disable future event and consultation GP awards.
-- No event/consultation awards existed at the time of this migration.
ALTER TABLE public.agc_points DROP CONSTRAINT IF EXISTS agc_points_reason_check;
ALTER TABLE public.agc_points ADD CONSTRAINT agc_points_reason_check
  CHECK (reason IN ('signup', 'verified_referral', 'contribution'));

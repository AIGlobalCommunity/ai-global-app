-- Enable the third arcade game in the existing best-score table.
-- This migration must be applied to the THE GENESIS ERA Supabase project.
DO $$
DECLARE c record;
BEGIN
  IF to_regclass('public.agc_game_scores') IS NULL THEN
    RAISE EXCEPTION 'agc_game_scores table is missing';
  END IF;
  FOR c IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.agc_game_scores'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%game_key%'
  LOOP
    EXECUTE format('ALTER TABLE public.agc_game_scores DROP CONSTRAINT %I', c.conname);
  END LOOP;
  ALTER TABLE public.agc_game_scores
    ADD CONSTRAINT agc_game_scores_supported_games
    CHECK (game_key IN ('signal', 'defender', 'wolf'));
END $$;

-- Note: if agc_submit_game_score itself restricts allowed keys,
-- its implementation must also be updated in the live database.

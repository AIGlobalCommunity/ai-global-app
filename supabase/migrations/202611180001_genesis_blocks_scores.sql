-- Enable Genesis Blocks in the existing arcade score table.
-- Apply to the production THE GENESIS ERA Supabase project.
DO $$
DECLARE c record;
BEGIN
  IF to_regclass('public.agc_game_scores') IS NULL THEN
    RAISE EXCEPTION 'agc_game_scores table is missing';
  END IF;
  FOR c IN
    SELECT conname FROM pg_constraint
    WHERE conrelid='public.agc_game_scores'::regclass AND contype='c'
      AND pg_get_constraintdef(oid) ILIKE '%game_key%'
  LOOP
    EXECUTE format('ALTER TABLE public.agc_game_scores DROP CONSTRAINT %I',c.conname);
  END LOOP;
  ALTER TABLE public.agc_game_scores
    ADD CONSTRAINT agc_game_scores_supported_games
    CHECK (game_key IN ('signal','defender','wolf','blocks'));
END $$;
-- Check the deployed agc_submit_game_score RPC for an additional allowlist.

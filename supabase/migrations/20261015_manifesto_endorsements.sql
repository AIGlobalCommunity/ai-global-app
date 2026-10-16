-- Voluntary, reversible endorsement of the open letter; no GP rewards.
CREATE TABLE IF NOT EXISTS public.agc_manifesto_signatures (
  member_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  signed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.agc_manifesto_signatures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Members can read own endorsement" ON public.agc_manifesto_signatures;
CREATE POLICY "Members can read own endorsement" ON public.agc_manifesto_signatures
  FOR SELECT TO authenticated USING (member_id = auth.uid());
DROP POLICY IF EXISTS "Members can endorse personally" ON public.agc_manifesto_signatures;
CREATE POLICY "Members can endorse personally" ON public.agc_manifesto_signatures
  FOR INSERT TO authenticated WITH CHECK (member_id = auth.uid());
DROP POLICY IF EXISTS "Members can withdraw own endorsement" ON public.agc_manifesto_signatures;
CREATE POLICY "Members can withdraw own endorsement" ON public.agc_manifesto_signatures
  FOR DELETE TO authenticated USING (member_id = auth.uid());
GRANT SELECT, INSERT, DELETE ON public.agc_manifesto_signatures TO authenticated;
CREATE OR REPLACE FUNCTION public.agc_manifesto_supporter_count()
RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = '' AS $$
  SELECT count(*) FROM public.agc_manifesto_signatures;
$$;
REVOKE ALL ON FUNCTION public.agc_manifesto_supporter_count() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.agc_manifesto_supporter_count() TO authenticated;

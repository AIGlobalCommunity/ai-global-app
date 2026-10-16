-- One non-financial preference per member. This is not a donation or pledge.
CREATE TABLE IF NOT EXISTS public.agc_support_preferences (
 member_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 priority text NOT NULL CHECK (priority IN ('platform','safety','research')),
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.agc_support_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY agc_support_preference_own_read ON public.agc_support_preferences
 FOR SELECT TO authenticated USING (member_id = (SELECT auth.uid()));
CREATE POLICY agc_support_preference_own_insert ON public.agc_support_preferences
 FOR INSERT TO authenticated WITH CHECK (member_id = (SELECT auth.uid()));
CREATE POLICY agc_support_preference_own_update ON public.agc_support_preferences
 FOR UPDATE TO authenticated USING (member_id = (SELECT auth.uid()))
 WITH CHECK (member_id = (SELECT auth.uid()));
GRANT SELECT,INSERT,UPDATE ON public.agc_support_preferences TO authenticated;

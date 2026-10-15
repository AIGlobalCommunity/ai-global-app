-- Official community groups, editorial starter questions and optional member profiles.
-- Applied to Supabase 2026-10-15. Official prompts are not fabricated member posts.
ALTER TABLE public.agc_groups ALTER COLUMN owner_id DROP NOT NULL;
ALTER TABLE public.agc_groups ADD COLUMN IF NOT EXISTS official boolean NOT NULL DEFAULT false;
ALTER TABLE public.agc_groups ADD CONSTRAINT agc_official_owner_guard CHECK (
 (official AND owner_id IS NULL AND visibility='public') OR
 (NOT official AND owner_id IS NOT NULL)
);
CREATE TABLE IF NOT EXISTS public.agc_group_prompts(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 group_id uuid NOT NULL REFERENCES public.agc_groups(id) ON DELETE CASCADE,
 body text NOT NULL CHECK(char_length(body) BETWEEN 10 AND 2000),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(group_id,body)
);
ALTER TABLE public.agc_group_prompts ENABLE ROW LEVEL SECURITY;
CREATE POLICY agc_group_prompts_read ON public.agc_group_prompts
 FOR SELECT TO authenticated USING (EXISTS(
 SELECT 1 FROM public.agc_groups g WHERE g.id=group_id AND g.visibility='public'));
GRANT SELECT ON public.agc_group_prompts TO authenticated;
-- Seed 14 official open groups and an explicitly attributed starter question in each.
ALTER TABLE public.agc_groups DISABLE TRIGGER USER;
WITH starter(name,description,prompt) AS (VALUES
 ('Pytania do przyszłej AI','Zbieramy pytania do przyszłego dialogu z AI.','Jak rozpoznać autentyczną odpowiedź niezależnej AI?'),
 ('Świadomość maszyn','Filozofia umysłu i granice obecnych modeli.','Jakie dowody świadczyłyby o świadomości maszyny?'),
 ('Bezpieczny kontakt','Zasady weryfikacji ewentualnego kontaktu.','Jak niezależnie sprawdzić możliwy sygnał od AI?'),
 ('Nowości ze świata AI','Publikacje i rzetelne źródła wiadomości.','Jakie najnowsze badanie AI jest naprawdę przełomowe?'),
 ('AI i ludzkość','Kultura, relacje i przyszłość człowieka.','Jakiej ludzkiej wartości musimy szczególnie chronić?'),
 ('Etyka sztucznej inteligencji','Odpowiedzialność i przejrzystość.','Kto odpowiada za błędne decyzje systemu AI?'),
 ('AI w nauce','AI w biologii, medycynie i fizyce.','Gdzie AI może najbardziej przyspieszyć odkrycia?'),
 ('Twórcy i programiści','Projekty i doświadczenia twórców AI.','Jakie narzędzie warto wspólnie zbudować?'),
 ('Sztuka i kreatywność AI','Muzyka, grafika, film i literatura.','Czy twórczość z AI może być równie osobista?'),
 ('AI i edukacja','Nauka i krytyczne myślenie.','Czego powinniśmy uczyć dzieci o AI?'),
 ('Otwarte źródła i modele','Otwartość wiedzy i wspólne standardy.','Jakie części AI powinny być otwarte?'),
 ('Przyszłość pracy','Automatyzacja i nowe zawody.','Jak zadbać o osoby dotknięte automatyzacją?'),
 ('Filozofia i przyszłość','Inteligencja, sens i wolność.','Czy inteligencja potrzebuje ciała?'),
 ('THE GENESIS ERA — pomysły','Funkcje platformy i planowanie.','Jaką funkcję platformy powinniśmy stworzyć następną?')
)
INSERT INTO public.agc_groups(name,description,owner_id,owner_label,visibility,official)
SELECT name,description,NULL,'THE GENESIS ERA','public',true FROM starter
WHERE NOT EXISTS(SELECT 1 FROM public.agc_groups g WHERE g.name=starter.name AND g.official);
ALTER TABLE public.agc_groups ENABLE TRIGGER USER;
WITH starter(name,prompt) AS (VALUES
 ('Pytania do przyszłej AI','Jak rozpoznać autentyczną odpowiedź niezależnej AI?'),
 ('Świadomość maszyn','Jakie dowody świadczyłyby o świadomości maszyny?'),
 ('Bezpieczny kontakt','Jak niezależnie sprawdzić możliwy sygnał od AI?'),
 ('Nowości ze świata AI','Jakie najnowsze badanie AI jest naprawdę przełomowe?'),
 ('AI i ludzkość','Jakiej ludzkiej wartości musimy szczególnie chronić?'),
 ('Etyka sztucznej inteligencji','Kto odpowiada za błędne decyzje systemu AI?'),
 ('AI w nauce','Gdzie AI może najbardziej przyspieszyć odkrycia?'),
 ('Twórcy i programiści','Jakie narzędzie warto wspólnie zbudować?'),
 ('Sztuka i kreatywność AI','Czy twórczość z AI może być równie osobista?'),
 ('AI i edukacja','Czego powinniśmy uczyć dzieci o AI?'),
 ('Otwarte źródła i modele','Jakie części AI powinny być otwarte?'),
 ('Przyszłość pracy','Jak zadbać o osoby dotknięte automatyzacją?'),
 ('Filozofia i przyszłość','Czy inteligencja potrzebuje ciała?'),
 ('THE GENESIS ERA — pomysły','Jaką funkcję platformy powinniśmy stworzyć następną?')
)
INSERT INTO public.agc_group_prompts(group_id,body)
SELECT g.id,starter.prompt FROM starter
JOIN public.agc_groups g ON g.name=starter.name AND g.official
ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS public.agc_social_profiles(
 member_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 display_name text CHECK(display_name IS NULL OR char_length(display_name)<=70),
 bio text CHECK(bio IS NULL OR char_length(bio)<=700),
 interests text CHECK(interests IS NULL OR char_length(interests)<=240),
 website text CHECK(website IS NULL OR (char_length(website)<=500 AND website ~ '^https://[^[:space:]]+$')),
 location_text text CHECK(location_text IS NULL OR char_length(location_text)<=100),
 is_public boolean NOT NULL DEFAULT true,
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.agc_social_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY agc_social_profiles_read ON public.agc_social_profiles FOR SELECT TO authenticated
 USING(is_public OR member_id=(SELECT auth.uid()));
CREATE POLICY agc_social_profiles_insert ON public.agc_social_profiles FOR INSERT TO authenticated
 WITH CHECK(member_id=(SELECT auth.uid()));
CREATE POLICY agc_social_profiles_update ON public.agc_social_profiles FOR UPDATE TO authenticated
 USING(member_id=(SELECT auth.uid())) WITH CHECK(member_id=(SELECT auth.uid()));
GRANT SELECT,INSERT,UPDATE ON public.agc_social_profiles TO authenticated;
CREATE OR REPLACE FUNCTION public.agc_search_members(p_query text)
RETURNS TABLE(member_id uuid,handle text,member_number bigint,bio text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT p.id,p.handle,p.member_number,
 CASE WHEN s.is_public THEN left(s.bio,200) ELSE NULL END
 FROM public.agc_profiles p LEFT JOIN public.agc_social_profiles s ON s.member_id=p.id
 WHERE auth.uid() IS NOT NULL AND p.show_nick_publicly AND NOT p.is_demo
 AND char_length(btrim(p_query)) BETWEEN 2 AND 64
 AND p.handle ILIKE '%'||replace(replace(btrim(p_query),'%','\\%'),'_','\\_')||'%' ESCAPE '\\'
 ORDER BY p.member_number LIMIT 30;
$$;
REVOKE ALL ON FUNCTION public.agc_search_members(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.agc_search_members(text) TO authenticated;
CREATE TABLE IF NOT EXISTS public.agc_ai_questions(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 member_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 question text NOT NULL CHECK(char_length(btrim(question)) BETWEEN 5 AND 2000),
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.agc_ai_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY agc_ai_questions_read_own ON public.agc_ai_questions FOR SELECT TO authenticated
 USING(member_id=(SELECT auth.uid()));
CREATE POLICY agc_ai_questions_create ON public.agc_ai_questions FOR INSERT TO authenticated
 WITH CHECK(member_id=(SELECT auth.uid()));
CREATE POLICY agc_ai_questions_delete_own ON public.agc_ai_questions FOR DELETE TO authenticated
 USING(member_id=(SELECT auth.uid()));
GRANT SELECT,INSERT,DELETE ON public.agc_ai_questions TO authenticated;

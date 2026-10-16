-- Community discussions: groups, posts, comments, likes and private reports.
-- Deployed to Supabase on 2026-10-15; this file documents the migration.
CREATE TABLE IF NOT EXISTS public.agc_groups (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 owner_label text NOT NULL DEFAULT '',
 name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 4 AND 64),
 description text NOT NULL CHECK (char_length(btrim(description)) BETWEEN 10 AND 500),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.agc_group_posts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 group_id uuid NOT NULL REFERENCES public.agc_groups(id) ON DELETE CASCADE,
 author_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 author_label text NOT NULL DEFAULT '',
 body text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 3 AND 3000),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.agc_post_comments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 post_id uuid NOT NULL REFERENCES public.agc_group_posts(id) ON DELETE CASCADE,
 author_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 author_label text NOT NULL DEFAULT '',
 body text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 2 AND 1000),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.agc_post_likes (
 post_id uuid NOT NULL REFERENCES public.agc_group_posts(id) ON DELETE CASCADE,
 member_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (post_id,member_id)
);
CREATE TABLE IF NOT EXISTS public.agc_post_reports (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 post_id uuid NOT NULL REFERENCES public.agc_group_posts(id) ON DELETE CASCADE,
 reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 5 AND 500),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (post_id,reporter_id)
);
CREATE INDEX IF NOT EXISTS agc_posts_group_newest ON public.agc_group_posts(group_id,created_at DESC);
CREATE INDEX IF NOT EXISTS agc_comments_post_newest ON public.agc_post_comments(post_id,created_at DESC);
CREATE INDEX IF NOT EXISTS agc_groups_newest ON public.agc_groups(created_at DESC);
CREATE OR REPLACE FUNCTION public.agc_discussion_author_label()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE profile record;
BEGIN
 SELECT p.handle,p.member_number,p.show_nick_publicly INTO profile
 FROM public.agc_profiles p WHERE p.id = (SELECT auth.uid());
 IF NOT FOUND THEN RAISE EXCEPTION 'Member profile required'; END IF;
 IF TG_TABLE_NAME = 'agc_groups' THEN
   NEW.owner_label := CASE WHEN profile.show_nick_publicly
     THEN profile.handle ELSE 'Genesis #' || profile.member_number::text END;
 ELSE
   NEW.author_label := CASE WHEN profile.show_nick_publicly
     THEN profile.handle ELSE 'Genesis #' || profile.member_number::text END;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.agc_discussion_author_label() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS agc_groups_author_label ON public.agc_groups;
CREATE TRIGGER agc_groups_author_label BEFORE INSERT ON public.agc_groups
 FOR EACH ROW EXECUTE FUNCTION public.agc_discussion_author_label();
DROP TRIGGER IF EXISTS agc_posts_author_label ON public.agc_group_posts;
CREATE TRIGGER agc_posts_author_label BEFORE INSERT ON public.agc_group_posts
 FOR EACH ROW EXECUTE FUNCTION public.agc_discussion_author_label();
DROP TRIGGER IF EXISTS agc_comments_author_label ON public.agc_post_comments;
CREATE TRIGGER agc_comments_author_label BEFORE INSERT ON public.agc_post_comments
 FOR EACH ROW EXECUTE FUNCTION public.agc_discussion_author_label();
CREATE OR REPLACE FUNCTION public.agc_discussion_rate_limit()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE recent_count int;
BEGIN
 IF TG_TABLE_NAME = 'agc_groups' THEN
   SELECT count(*) INTO recent_count FROM public.agc_groups
    WHERE owner_id = NEW.owner_id AND created_at > now() - interval '24 hours';
   IF recent_count >= 3 THEN RAISE EXCEPTION 'Maximum 3 groups per day'; END IF;
 ELSIF TG_TABLE_NAME = 'agc_group_posts' THEN
   SELECT count(*) INTO recent_count FROM public.agc_group_posts
    WHERE author_id = NEW.author_id AND created_at > now() - interval '1 minute';
   IF recent_count >= 3 THEN RAISE EXCEPTION 'Please wait before posting again'; END IF;
 ELSIF TG_TABLE_NAME = 'agc_post_comments' THEN
   SELECT count(*) INTO recent_count FROM public.agc_post_comments
    WHERE author_id = NEW.author_id AND created_at > now() - interval '1 minute';
   IF recent_count >= 8 THEN RAISE EXCEPTION 'Please wait before commenting again'; END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.agc_discussion_rate_limit() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS agc_groups_rate_limit ON public.agc_groups;
CREATE TRIGGER agc_groups_rate_limit BEFORE INSERT ON public.agc_groups
 FOR EACH ROW EXECUTE FUNCTION public.agc_discussion_rate_limit();
DROP TRIGGER IF EXISTS agc_posts_rate_limit ON public.agc_group_posts;
CREATE TRIGGER agc_posts_rate_limit BEFORE INSERT ON public.agc_group_posts
 FOR EACH ROW EXECUTE FUNCTION public.agc_discussion_rate_limit();
DROP TRIGGER IF EXISTS agc_comments_rate_limit ON public.agc_post_comments;
CREATE TRIGGER agc_comments_rate_limit BEFORE INSERT ON public.agc_post_comments
 FOR EACH ROW EXECUTE FUNCTION public.agc_discussion_rate_limit();
ALTER TABLE public.agc_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agc_group_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agc_post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agc_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agc_post_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY agc_groups_read ON public.agc_groups FOR SELECT TO authenticated USING (true);
CREATE POLICY agc_groups_create ON public.agc_groups FOR INSERT TO authenticated WITH CHECK (owner_id = (SELECT auth.uid()));
CREATE POLICY agc_posts_read ON public.agc_group_posts FOR SELECT TO authenticated USING (true);
CREATE POLICY agc_posts_create ON public.agc_group_posts FOR INSERT TO authenticated WITH CHECK (author_id = (SELECT auth.uid()));
CREATE POLICY agc_posts_delete ON public.agc_group_posts FOR DELETE TO authenticated USING (author_id = (SELECT auth.uid()));
CREATE POLICY agc_comments_read ON public.agc_post_comments FOR SELECT TO authenticated USING (true);
CREATE POLICY agc_comments_create ON public.agc_post_comments FOR INSERT TO authenticated WITH CHECK (author_id = (SELECT auth.uid()));
CREATE POLICY agc_comments_delete ON public.agc_post_comments FOR DELETE TO authenticated USING (author_id = (SELECT auth.uid()));
CREATE POLICY agc_likes_read ON public.agc_post_likes FOR SELECT TO authenticated USING (true);
CREATE POLICY agc_likes_create ON public.agc_post_likes FOR INSERT TO authenticated WITH CHECK (member_id = (SELECT auth.uid()));
CREATE POLICY agc_likes_delete ON public.agc_post_likes FOR DELETE TO authenticated USING (member_id = (SELECT auth.uid()));
CREATE POLICY agc_reports_create ON public.agc_post_reports FOR INSERT TO authenticated WITH CHECK (reporter_id = (SELECT auth.uid()));
GRANT SELECT,INSERT ON public.agc_groups TO authenticated;
GRANT SELECT,INSERT,DELETE ON public.agc_group_posts,public.agc_post_comments,public.agc_post_likes TO authenticated;
GRANT INSERT ON public.agc_post_reports TO authenticated;

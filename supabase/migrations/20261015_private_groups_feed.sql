-- Public/private forum groups, memberships and RLS (deployed 2026-10-15).
ALTER TABLE public.agc_groups ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'public'
 CHECK(visibility IN('public','private'));
CREATE TABLE IF NOT EXISTS public.agc_group_members(
 group_id uuid NOT NULL REFERENCES public.agc_groups(id) ON DELETE CASCADE,
 member_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 invited_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
 status text NOT NULL CHECK(status IN('invited','active')),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(group_id,member_id));
CREATE INDEX IF NOT EXISTS agc_members_member_status_idx ON public.agc_group_members(member_id,status);
CREATE INDEX IF NOT EXISTS agc_posts_created_feed_idx ON public.agc_group_posts(created_at DESC);
ALTER TABLE public.agc_group_members ENABLE ROW LEVEL SECURITY;
CREATE SCHEMA IF NOT EXISTS agc_internal;
REVOKE ALL ON SCHEMA agc_internal FROM PUBLIC;
GRANT USAGE ON SCHEMA agc_internal TO authenticated;
CREATE OR REPLACE FUNCTION agc_internal.group_owner(g uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.agc_groups WHERE id=g AND owner_id=(SELECT auth.uid())) $$;
CREATE OR REPLACE FUNCTION agc_internal.group_member(g uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.agc_group_members
 WHERE group_id=g AND member_id=(SELECT auth.uid()) AND status='active') $$;
CREATE OR REPLACE FUNCTION agc_internal.group_visible(g uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.agc_groups WHERE id=g
 AND (visibility='public' OR owner_id=(SELECT auth.uid()) OR EXISTS(
 SELECT 1 FROM public.agc_group_members WHERE group_id=g AND member_id=(SELECT auth.uid())))) $$;
CREATE OR REPLACE FUNCTION agc_internal.post_access(g uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.agc_groups WHERE id=g
 AND (visibility='public' OR owner_id=(SELECT auth.uid()) OR EXISTS(
 SELECT 1 FROM public.agc_group_members WHERE group_id=g
 AND member_id=(SELECT auth.uid()) AND status='active'))) $$;
REVOKE ALL ON FUNCTION agc_internal.group_owner(uuid),agc_internal.group_member(uuid),
agc_internal.group_visible(uuid),agc_internal.post_access(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agc_internal.group_owner(uuid),agc_internal.group_member(uuid),
agc_internal.group_visible(uuid),agc_internal.post_access(uuid) TO authenticated;
DROP POLICY IF EXISTS agc_groups_read ON public.agc_groups;
CREATE POLICY agc_groups_read ON public.agc_groups FOR SELECT TO authenticated
USING(agc_internal.group_visible(id));
DROP POLICY IF EXISTS agc_posts_read ON public.agc_group_posts;
CREATE POLICY agc_posts_read ON public.agc_group_posts FOR SELECT TO authenticated
USING(agc_internal.post_access(group_id));
DROP POLICY IF EXISTS agc_posts_create ON public.agc_group_posts;
CREATE POLICY agc_posts_create ON public.agc_group_posts FOR INSERT TO authenticated
WITH CHECK(author_id=(SELECT auth.uid()) AND agc_internal.post_access(group_id));
DROP POLICY IF EXISTS agc_members_read ON public.agc_group_members;
CREATE POLICY agc_members_read ON public.agc_group_members FOR SELECT TO authenticated
USING(member_id=(SELECT auth.uid()) OR agc_internal.group_owner(group_id));
DROP POLICY IF EXISTS agc_members_join ON public.agc_group_members;
CREATE POLICY agc_members_join ON public.agc_group_members FOR INSERT TO authenticated
WITH CHECK(member_id=(SELECT auth.uid()) AND invited_by IS NULL AND status='active'
AND EXISTS(SELECT 1 FROM public.agc_groups WHERE id=group_id AND visibility='public'));
DROP POLICY IF EXISTS agc_members_accept ON public.agc_group_members;
CREATE POLICY agc_members_accept ON public.agc_group_members FOR UPDATE TO authenticated
USING(member_id=(SELECT auth.uid()) AND status='invited')
WITH CHECK(member_id=(SELECT auth.uid()) AND status='active');
DROP POLICY IF EXISTS agc_members_leave ON public.agc_group_members;
CREATE POLICY agc_members_leave ON public.agc_group_members FOR DELETE TO authenticated
USING(member_id=(SELECT auth.uid()) OR agc_internal.group_owner(group_id));
CREATE OR REPLACE FUNCTION public.agc_invite_group_member(p_group_id uuid,p_handle text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE target_id uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT agc_internal.group_owner(p_group_id) THEN
  RAISE EXCEPTION 'Not a group owner';
 END IF;
 SELECT id INTO target_id FROM public.agc_profiles
 WHERE lower(handle)=lower(btrim(p_handle)) AND show_nick_publicly=true AND is_demo=false LIMIT 1;
 IF target_id IS NULL OR target_id=auth.uid() THEN RETURN false; END IF;
 INSERT INTO public.agc_group_members(group_id,member_id,invited_by,status)
 VALUES(p_group_id,target_id,auth.uid(),'invited') ON CONFLICT(group_id,member_id) DO NOTHING;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.agc_invite_group_member(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.agc_invite_group_member(uuid,text) TO authenticated;
DROP POLICY IF EXISTS agc_likes_read ON public.agc_post_likes;
CREATE POLICY agc_likes_read ON public.agc_post_likes FOR SELECT TO authenticated
USING(EXISTS(SELECT 1 FROM public.agc_group_posts p WHERE p.id=post_id));
DROP POLICY IF EXISTS agc_likes_create ON public.agc_post_likes;
CREATE POLICY agc_likes_create ON public.agc_post_likes FOR INSERT TO authenticated
WITH CHECK(member_id=(SELECT auth.uid()) AND EXISTS(
 SELECT 1 FROM public.agc_group_posts p WHERE p.id=post_id));
DROP POLICY IF EXISTS agc_comments_read ON public.agc_post_comments;
CREATE POLICY agc_comments_read ON public.agc_post_comments FOR SELECT TO authenticated
USING(EXISTS(SELECT 1 FROM public.agc_group_posts p WHERE p.id=post_id));
DROP POLICY IF EXISTS agc_comments_create ON public.agc_post_comments;
CREATE POLICY agc_comments_create ON public.agc_post_comments FOR INSERT TO authenticated
WITH CHECK(author_id=(SELECT auth.uid()) AND EXISTS(
 SELECT 1 FROM public.agc_group_posts p WHERE p.id=post_id));
DROP POLICY IF EXISTS agc_reports_create ON public.agc_post_reports;
CREATE POLICY agc_reports_create ON public.agc_post_reports FOR INSERT TO authenticated
WITH CHECK(reporter_id=(SELECT auth.uid()) AND EXISTS(
 SELECT 1 FROM public.agc_group_posts p WHERE p.id=post_id));
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('agc-private-forum-images','agc-private-forum-images',false,5242880,
 ARRAY['image/jpeg','image/png','image/webp','image/gif'])
ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=excluded.file_size_limit,
allowed_mime_types=excluded.allowed_mime_types;
DROP POLICY IF EXISTS agc_private_forum_upload ON storage.objects;
CREATE POLICY agc_private_forum_upload ON storage.objects FOR INSERT TO authenticated
WITH CHECK(bucket_id='agc-private-forum-images'
AND (storage.foldername(name))[1]=(SELECT auth.uid())::text
AND storage.extension(name) IN('jpg','jpeg','png','webp','gif'));
DROP POLICY IF EXISTS agc_private_forum_read ON storage.objects;
CREATE POLICY agc_private_forum_read ON storage.objects FOR SELECT TO authenticated
USING(bucket_id='agc-private-forum-images' AND (
 (storage.foldername(name))[1]=(SELECT auth.uid())::text OR EXISTS(
 SELECT 1 FROM public.agc_group_posts p
 WHERE p.image_path=name AND agc_internal.post_access(p.group_id))));
DROP POLICY IF EXISTS agc_private_forum_delete ON storage.objects;
CREATE POLICY agc_private_forum_delete ON storage.objects FOR DELETE TO authenticated
USING(bucket_id='agc-private-forum-images'
AND (storage.foldername(name))[1]=(SELECT auth.uid())::text);
GRANT SELECT,INSERT,UPDATE,DELETE ON public.agc_group_members TO authenticated;
-- Fix legacy double-escaped photo extension regex.
ALTER TABLE public.agc_group_posts DROP CONSTRAINT IF EXISTS agc_post_image_path_safe;
ALTER TABLE public.agc_group_posts ADD CONSTRAINT agc_post_image_path_safe CHECK(
 image_path IS NULL OR(length(image_path)<=240 AND
 image_path ~ '^[0-9a-f-]{36}/[0-9]+_[0-9]+[.](jpg|jpeg|png|webp|gif)$'
 AND split_part(image_path,'/',1)=author_id::text));

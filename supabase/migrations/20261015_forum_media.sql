-- Forum photo uploads, links and video references (deployed 2026-10-15).
ALTER TABLE public.agc_group_posts
 ADD COLUMN IF NOT EXISTS image_path text,
 ADD COLUMN IF NOT EXISTS link_url text,
 ADD COLUMN IF NOT EXISTS video_url text;
ALTER TABLE public.agc_group_posts
 ADD CONSTRAINT agc_post_image_path_safe CHECK (
   image_path IS NULL OR
   (length(image_path) <= 240 AND image_path ~ '^[0-9a-f-]{36}/[0-9]+_[0-9]+\.(jpg|jpeg|png|webp|gif)$'
    AND split_part(image_path,'/',1) = author_id::text)
 );
ALTER TABLE public.agc_group_posts
 ADD CONSTRAINT agc_post_link_https CHECK (
   link_url IS NULL OR (length(link_url) <= 1500 AND link_url ~ '^https://[^[:space:]]+$')
 );
ALTER TABLE public.agc_group_posts
 ADD CONSTRAINT agc_post_video_https CHECK (
   video_url IS NULL OR (length(video_url) <= 1500 AND video_url ~ '^https://[^[:space:]]+$')
 );
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES ('agc-forum-images','agc-forum-images',true,5242880,
 ARRAY['image/jpeg','image/png','image/webp','image/gif'])
 ON CONFLICT (id) DO UPDATE SET
 public=excluded.public,file_size_limit=excluded.file_size_limit,
 allowed_mime_types=excluded.allowed_mime_types;
CREATE POLICY agc_forum_images_upload ON storage.objects
 FOR INSERT TO authenticated WITH CHECK (
   bucket_id = 'agc-forum-images'
   AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
   AND (storage.extension(name)) IN ('jpg','jpeg','png','webp','gif')
 );
CREATE POLICY agc_forum_images_delete_own ON storage.objects
 FOR DELETE TO authenticated USING (
   bucket_id = 'agc-forum-images'
   AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
 );
GRANT UPDATE (image_path,link_url,video_url) ON public.agc_group_posts TO authenticated;

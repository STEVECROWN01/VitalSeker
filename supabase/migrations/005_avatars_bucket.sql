-- ============================================================================
-- Migration 005: Avatars storage bucket
-- ============================================================================
-- Creates a public-readable Storage bucket for user avatars. Files are
-- uploaded by the user themselves; RLS on storage.objects ensures each user
-- can only write to a path prefixed with their own user id.
--
-- The Flutter client uploads to: avatars/{user_id}/avatar.jpg
-- The public URL is then stored on users.avatar_url for fast lookup.
-- ============================================================================

BEGIN;

-- 1. Create the bucket (public-read so avatars can be rendered in the UI
--    without signed URLs; size limit 2MB; jpg/png/webp only).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  2097152,  -- 2 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Storage RLS policies.
--    Each user can INSERT / UPDATE / DELETE only files under their own prefix.
--    Public SELECT (avatars must render for any viewer, including the
--    emergency contact who scans the QR).

-- Public read for avatars (so QR-code viewers can render the avatar).
DROP POLICY IF EXISTS "Public can read avatars" ON storage.objects;
CREATE POLICY "Public can read avatars"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- Owner can manage their own avatar files (path must start with their user id).
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

COMMIT;

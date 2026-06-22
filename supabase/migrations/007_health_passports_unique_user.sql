-- ============================================================================
-- Migration 007: UNIQUE constraint on health_passports.user_id
-- ============================================================================
-- Bug 2 (QR generation failure) root cause:
--   The `generate-qr` edge function does an upsert keyed on `user_id` so a
--   user only ever has one active passport row. Upserts require a UNIQUE
--   constraint (or UNIQUE index) on the conflict target column — without
--   one, Postgres raises:
--     "There is no unique or exclusion constraint matching the ON CONFLICT
--      specification"
--   and the edge function returns 500, which the client surfaced as the
--   generic "Failed to generate QR code" message.
--
-- The original schema (migration 001) declared `user_id` as NOT NULL but
-- did NOT add a UNIQUE constraint, so the upsert has been broken since day
-- one. This migration adds the constraint (idempotently) so the edge
-- function's `ON CONFLICT (user_id) DO UPDATE` works as intended.
--
-- Safe to re-run: each statement uses IF NOT EXISTS / guards via DROP first.
-- ============================================================================

BEGIN;

-- Deduplicate any pre-existing duplicate rows before adding the constraint,
-- otherwise ALTER TABLE … ADD CONSTRAINT will fail. We keep the most
-- recently updated row per user and delete the older duplicates.
DELETE FROM public.health_passports hp
WHERE EXISTS (
  SELECT 1
  FROM public.health_passports hp2
  WHERE hp2.user_id = hp.user_id
    AND (
      hp2.updated_at > hp.updated_at
      OR (hp2.updated_at = hp.updated_at AND hp2.id > hp.id)
    )
);

-- Add the UNIQUE constraint. Using a constraint (rather than just a unique
-- index) so it shows up in information_schema and is easier to reason about
-- for the edge function's ON CONFLICT clause.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'health_passports_user_id_key'
      AND conrelid = 'public.health_passports'::regclass
  ) THEN
    ALTER TABLE public.health_passports
      ADD CONSTRAINT health_passports_user_id_key UNIQUE (user_id);
  END IF;
END$$;

COMMIT;

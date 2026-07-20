-- ============================================================================
-- Migration 012: Server-side hardening bundle
-- ============================================================================
-- Addresses the following audit findings:
--
--   1. CRITICAL: storage.objects had a public-read policy on the avatars
--      bucket (from migration 005) that was never dropped when migration 010
--      marked the bucket private. The combination left avatars accessible
--      to anonymous users — anyone could enumerate and download every
--      user's profile picture via the Storage API.
--
--   2. HIGH: medical_records had no `updated_at` column. The client
--      DatabaseService.updateMedicalRecord sets `updated_at` in the payload,
--      causing every update to throw PostgrestException PGRST204
--      ("column does not exist").
--
--   3. HIGH: symptom_logs had no `updated_at` column. Same issue as #2 —
--      DatabaseService.updateSymptomLog sets `updated_at` and the call
--      fails.
--
--   4. HIGH: the `vitals_spo2_range` CHECK constraint used the mixed-case
--      string 'spO2' while the type enum stores lowercase 'spo2'. The
--      constraint was a no-op — `type != 'spO2'` was always TRUE for every
--      row, so out-of-range SpO2 values (e.g. 9999) were silently accepted.
--
--   5. MEDIUM: family_profiles had an `updated_at` column but no trigger
--      to auto-touch it. The client was setting it manually, which is
--      fragile — concurrent writes could overwrite each other's timestamp.
--
--   6. INFO: add a `resolved_at` column to sos_events if missing (used by
--      the new resolveSos flow in the client).
--
-- All changes are idempotent (IF NOT EXISTS / DROP IF EXISTS).
-- ============================================================================

BEGIN;

-- ── 1. Drop the avatars public-read policy ─────────────────────────────────
-- Migration 010 already added a proper auth-scoped SELECT policy
-- ("Users can read own avatar"). The public-read policy from migration 005
-- is dead weight AND a security hole — drop it.
DROP POLICY IF EXISTS "Public can read avatars" ON storage.objects;

-- ── 2. Add medical_records.updated_at column + trigger ────────────────────
ALTER TABLE public.medical_records
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

ALTER TABLE public.medical_records
  ALTER COLUMN updated_at SET DEFAULT now();

DROP TRIGGER IF EXISTS trg_medical_records_updated_at ON public.medical_records;
CREATE TRIGGER trg_medical_records_updated_at
  BEFORE UPDATE ON public.medical_records
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 3. Add symptom_logs.updated_at column + trigger ───────────────────────
ALTER TABLE public.symptom_logs
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

ALTER TABLE public.symptom_logs
  ALTER COLUMN updated_at SET DEFAULT now();

DROP TRIGGER IF EXISTS trg_symptom_logs_updated_at ON public.symptom_logs;
CREATE TRIGGER trg_symptom_logs_updated_at
  BEFORE UPDATE ON public.symptom_logs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 4. Fix the spO2 CHECK constraint (case mismatch) ──────────────────────
-- The constraint's `type != 'spO2'` was always TRUE for every row because
-- the type enum stores lowercase 'spo2'. Replace with the correct casing
-- so out-of-range SpO2 values are rejected at the DB layer.
ALTER TABLE public.vitals DROP CONSTRAINT IF EXISTS vitals_spo2_range;
ALTER TABLE public.vitals
  ADD CONSTRAINT vitals_spo2_range
  CHECK (type != 'spo2' OR (value >= 50 AND value <= 100));

-- ── 5. Add updated_at trigger to family_profiles ──────────────────────────
-- The column already existed (migration 001) but had no trigger; the
-- client was setting it manually.
DROP TRIGGER IF EXISTS trg_family_profiles_updated_at ON public.family_profiles;
CREATE TRIGGER trg_family_profiles_updated_at
  BEFORE UPDATE ON public.family_profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 6. Ensure sos_events has resolved_at ───────────────────────────────────
-- Used by the new resolveSos flow. Some early deployments may not have it.
ALTER TABLE public.sos_events
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

COMMIT;

-- Verification (run manually after applying):
-- SELECT 1 FROM pg_policies WHERE policyname = 'Public can read avatars';
-- (should return 0 rows)
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'medical_records' AND column_name = 'updated_at';
-- (should return 1 row)
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'symptom_logs' AND column_name = 'updated_at';
-- (should return 1 row)
-- SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'vitals_spo2_range';
-- (should show lowercase 'spo2')

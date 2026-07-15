-- ============================================================================
-- Migration 011: Missing RLS policies + support ticket hardening
-- ============================================================================
-- Purpose:
--   1. Add the missing UPDATE policy on medical_records (audit L-6).
--      Users could SELECT, INSERT, DELETE but not UPDATE — the only way to
--      edit a record was delete+reinsert, losing the original created_at.
--
--   2. Add a BEFORE INSERT trigger on support_tickets that forces status='open'
--      and clamps priority for user-submitted rows (audit L-7). RLS cannot
--      restrict individual columns, so a malicious client could INSERT with
--      status='resolved' to queue-jump support.
--
--   3. Add CHECK constraints on vitals.value for physiological ranges
--      (audit L-3). The client now validates (vital.dart), but the DB
--      should also enforce as defense-in-depth.
--
--   4. Add CHECK constraint on health_passports.blood_type (audit L-1).
--      The users table has the constraint; passports didn't.
--
--   5. Make the handle_new_user trigger idempotent (audit L-18).
-- ============================================================================

BEGIN;

-- ── 1. medical_records UPDATE policy (audit L-6) ──────────────────────────
CREATE POLICY "Users can update own medical records"
  ON public.medical_records
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── 2. support_tickets hardening (audit L-7) ──────────────────────────────
-- Drop the existing trigger if it exists (idempotent).
DROP TRIGGER IF EXISTS enforce_ticket_defaults_on_insert ON public.support_tickets;

-- Create a function that forces status='open' and clamps priority to
-- 'normal' or 'low' for user-submitted tickets. 'urgent' and 'critical'
-- can only be set by an admin (service-role).
CREATE OR REPLACE FUNCTION public.enforce_ticket_defaults()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Force status to 'open' on insert — users cannot self-resolve.
  NEW.status := 'open';

  -- Clamp priority: users can only set 'low' or 'normal'. Any other value
  -- (including 'urgent', 'critical') is downgraded to 'normal'.
  IF NEW.priority NOT IN ('low', 'normal') THEN
    NEW.priority := 'normal';
  END IF;

  -- Ensure user_id matches the authenticated user (defense-in-depth —
  -- RLS already enforces this, but a bug in RLS would be caught here).
  IF auth.uid() IS NOT NULL THEN
    NEW.user_id := auth.uid();
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_ticket_defaults_on_insert
  BEFORE INSERT ON public.support_tickets
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_ticket_defaults();

-- ── 3. vitals value range CHECK constraints (audit L-3) ───────────────────
-- These mirror the client-side validation in vital.dart. Values outside
-- these ranges are rejected at the DB level as defense-in-depth.
-- We use ALTER TABLE ADD CONSTRAINT IF NOT EXISTS (Postgres 9.6+ supports
-- IF NOT EXISTS on constraints? Actually no — we use DO blocks).

DO $$
BEGIN
  -- Heart rate: 20-250 bpm
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'vitals_heart_rate_range') THEN
    ALTER TABLE public.vitals
      ADD CONSTRAINT vitals_heart_rate_range
      CHECK (type != 'heart_rate' OR (value >= 20 AND value <= 250));
  END IF;

  -- Blood pressure systolic: 50-300 mmHg
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'vitals_bp_systolic_range') THEN
    ALTER TABLE public.vitals
      ADD CONSTRAINT vitals_bp_systolic_range
      CHECK (type != 'blood_pressure' OR (value >= 50 AND value <= 300));
  END IF;

  -- SpO2: 50-100 %
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'vitals_spo2_range') THEN
    ALTER TABLE public.vitals
      ADD CONSTRAINT vitals_spo2_range
      CHECK (type != 'spO2' OR (value >= 50 AND value <= 100));
  END IF;

  -- Temperature: 30-45 °C
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'vitals_temperature_range') THEN
    ALTER TABLE public.vitals
      ADD CONSTRAINT vitals_temperature_range
      CHECK (type != 'temperature' OR (value >= 30 AND value <= 45));
  END IF;

  -- Weight: 2-500 kg
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'vitals_weight_range') THEN
    ALTER TABLE public.vitals
      ADD CONSTRAINT vitals_weight_range
      CHECK (type != 'weight' OR (value >= 2 AND value <= 500));
  END IF;
END $$;

-- ── 4. health_passports blood_type CHECK (audit L-1) ──────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'passport_blood_type_valid') THEN
    ALTER TABLE public.health_passports
      ADD CONSTRAINT passport_blood_type_valid
      CHECK (blood_type IS NULL OR blood_type IN (
        'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
      ));
  END IF;
END $$;

-- ── 5. Make handle_new_user idempotent (audit L-18) ───────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Use ON CONFLICT to make this idempotent — if the row already exists
  -- (e.g. trigger fired twice), update the email instead of failing.
  INSERT INTO public.users (id, email, full_name, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    updated_at = NOW();
  RETURN NEW;
END;
$$;

COMMIT;

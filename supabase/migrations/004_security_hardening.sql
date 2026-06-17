-- ============================================================================
-- Migration 004: Security hardening + RLS fixes + updated_at triggers
-- ============================================================================
-- This migration addresses several critical security issues identified in the
-- VitalSeker backend:
--
--   1. RLS hole on weekly_insights: previously used `WITH CHECK (true)` /
--      `USING (true)` policies, which let ANY authenticated user insert or
--      update insights for ANY other user. Replaced with service-role-only
--      policies (auth.role() = 'service_role'), so only the weekly-insights
--      edge function (running with the service key) can write. Regular users
--      retain SELECT-only access on their own rows.
--
--   2. UNIQUE constraint on health_passports.user_id: previously missing,
--      so `generate-qr` upsert `onConflict: 'user_id'` silently failed and
--      users could accumulate duplicate passport rows.
--
--   3. DELETE policies on weekly_insights and subscriptions: previously
--      absent, so even owners couldn't delete their own rows.
--
--   4. updated_at auto-touch triggers: columns existed on users,
--      health_passports, medications, appointments, and subscriptions but
--      were never auto-updated by Postgres. App code had to set them
--      manually (which it did inconsistently). Added a generic trigger.
--
-- Before deploying: review the impact on existing rows. The UNIQUE constraint
-- will FAIL to add if duplicate (user_id) rows already exist in
-- health_passports — clean those up first:
--
--   SELECT user_id, count(*) FROM public.health_passports
--   GROUP BY user_id HAVING count(*) > 1;
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. UNIQUE constraint on health_passports.user_id
-- ----------------------------------------------------------------------------
-- If duplicates exist, the constraint add will fail-safe (the migration aborts
-- and no changes are applied). Resolve duplicates manually before re-running.
ALTER TABLE public.health_passports
  ADD CONSTRAINT health_passports_user_id_key UNIQUE (user_id);

-- ----------------------------------------------------------------------------
-- 2. RLS hardening on weekly_insights
-- ----------------------------------------------------------------------------
-- Drop the wide-open policies.
DROP POLICY IF EXISTS "System can insert insights" ON public.weekly_insights;
DROP POLICY IF EXISTS "System can update insights" ON public.weekly_insights;

-- Owner-scoped SELECT (regular users can read their own insights only).
CREATE POLICY "Users can read own insights"
  ON public.weekly_insights
  FOR SELECT
  USING (auth.uid() = user_id);

-- Service-role-only INSERT (weekly-insights edge function uses service key).
CREATE POLICY "Service role can insert insights"
  ON public.weekly_insights
  FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- Service-role-only UPDATE.
CREATE POLICY "Service role can update insights"
  ON public.weekly_insights
  FOR UPDATE
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Owner-scoped DELETE (users can delete their own insights).
CREATE POLICY "Users can delete own insights"
  ON public.weekly_insights
  FOR DELETE
  USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 3. DELETE policy on subscriptions (was missing)
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can delete own subscription"
  ON public.subscriptions
  FOR DELETE
  USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 4. updated_at auto-touch triggers
-- ----------------------------------------------------------------------------
-- Generic function: sets NEW.updated_at = now() on every UPDATE.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Apply per-table. Each CREATE TRIGGER IF NOT EXISTS guards re-runs.
DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY[
    'users',
    'health_passports',
    'medications',
    'appointments',
    'subscriptions'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format(
      'CREATE TRIGGER IF NOT EXISTS trg_%s_updated_at
         BEFORE UPDATE ON public.%I
         FOR EACH ROW
         EXECUTE FUNCTION public.set_updated_at();',
      t, t
    );
  END LOOP;
END $$;

COMMIT;

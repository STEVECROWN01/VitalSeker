-- ============================================================================
-- Migration 009: Subscriptions RLS hardening + weekly_insights dedup
-- ============================================================================
-- Purpose:
--   1. Tighten RLS on `subscriptions` so authenticated users can only SELECT
--      their own row. INSERT/UPDATE/DELETE are restricted to the service_role
--      (used by the RevenueCat webhook). This closes the payment-bypass vector
--      where any client could write {plan:'pro', status:'active'} to their own
--      row without going through Apple/Google in-app purchase.
--
--   2. Add UNIQUE constraint on (user_id, week_start) for weekly_insights so
--      the weekly-insights cron can use ON CONFLICT DO UPDATE instead of
--      inserting duplicate rows when run multiple times for the same week.
--
--   3. Add UNIQUE constraint on (user_id) for subscriptions so a user can
--      have at most one subscription row (the RevenueCat webhook updates the
--      existing row rather than creating duplicates).
--
--   4. Add CHECK constraint on users.emergency_contacts ensuring it's a JSON
--      array — prevents the SOS edge function from crashing if a non-array
--      value is ever stored (audit C-3 server-side fix).
--
-- Audit findings addressed: C-1, C-3, C-7 (server side), H-5, H-34
-- ============================================================================

BEGIN;

-- ── 1. Subscriptions: tighten RLS ──────────────────────────────────────────
-- Drop the existing permissive INSERT/UPDATE policies and replace with
-- SELECT-only for authenticated users. The service_role bypasses RLS, so
-- the RevenueCat webhook (which uses the service role key) can still write.

-- Drop existing policies on subscriptions
DROP POLICY IF EXISTS "Users can view own subscription" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can insert own subscription" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can update own subscription" ON public.subscriptions;

-- Recreate as SELECT-only for authenticated users
CREATE POLICY "Users can view own subscription"
  ON public.subscriptions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- NOTE: No INSERT/UPDATE/DELETE policies for authenticated role.
-- Only the service_role (RevenueCat webhook, used by edge functions with
-- SUPABASE_SERVICE_ROLE_KEY) can write — and service_role bypasses RLS.

-- Add UNIQUE constraint on user_id so a user can have at most one
-- subscription row. If the RevenueCat webhook fires twice for the same
-- purchase, the second call updates the existing row instead of creating
-- a duplicate.
-- First, dedup any existing duplicates (keep the most recent).
DELETE FROM public.subscriptions s1
  USING public.subscriptions s2
  WHERE s1.user_id = s2.user_id
    AND s1.id < s2.id;

ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_user_id_unique UNIQUE (user_id);

-- ── 2. weekly_insights: UNIQUE (user_id, week_start) ───────────────────────
-- Dedup any existing duplicates (keep the most recent).
DELETE FROM public.weekly_insights w1
  USING public.weekly_insights w2
  WHERE w1.user_id = w2.user_id
    AND w1.week_start = w2.week_start
    AND w1.id < w2.id;

ALTER TABLE public.weekly_insights
  ADD CONSTRAINT weekly_insights_user_week_unique
  UNIQUE (user_id, week_start);

-- ── 3. users.emergency_contacts: enforce JSON array ────────────────────────
-- Prevents the SOS edge function from crashing if a non-array value is
-- ever stored (audit C-3 server-side fix).
ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_emergency_contacts_is_array;
ALTER TABLE public.users
  ADD CONSTRAINT users_emergency_contacts_is_array
  CHECK (jsonb_typeof(emergency_contacts) = 'array');

COMMIT;

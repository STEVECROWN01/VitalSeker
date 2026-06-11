-- VitalSeker Schema Extensions
-- Adds: gender, height, weight, notification preferences to users table

-- ============================================
-- ADD MISSING COLUMNS TO USERS TABLE
-- ============================================
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gender TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS height_cm DOUBLE PRECISION;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS weight_kg DOUBLE PRECISION;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS notification_prefs JSONB DEFAULT '{}'::jsonb;

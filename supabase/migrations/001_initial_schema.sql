-- VitalSeker Initial Schema
-- Created: 2024-01-01
-- Description: Complete database schema for VitalSeker AI Health Companion

-- ============================================
-- 1. USERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  phone TEXT,
  avatar_url TEXT,
  date_of_birth DATE,
  blood_type TEXT CHECK (blood_type IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  allergies TEXT[] DEFAULT '{}',
  chronic_conditions TEXT[] DEFAULT '{}',
  emergency_contacts JSONB DEFAULT '[]'::jsonb,
  preferred_language TEXT DEFAULT 'en',
  theme_preference TEXT DEFAULT 'system' CHECK (theme_preference IN ('light','dark','system')),
  onboarding_completed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 2. HEALTH PASSPORTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.health_passports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  qr_token TEXT UNIQUE,
  vital_score INTEGER DEFAULT 0 CHECK (vital_score >= 0 AND vital_score <= 100),
  last_assessment_date TIMESTAMPTZ,
  blood_type TEXT,
  allergies TEXT[] DEFAULT '{}',
  medications TEXT[] DEFAULT '{}',
  chronic_conditions TEXT[] DEFAULT '{}',
  emergency_contacts JSONB DEFAULT '[]'::jsonb,
  insurance_provider TEXT,
  insurance_policy_number TEXT,
  is_active BOOLEAN DEFAULT true,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 3. SYMPTOM LOGS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.symptom_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  symptoms TEXT[] NOT NULL,
  severity INTEGER NOT NULL CHECK (severity >= 1 AND severity <= 10),
  duration TEXT,
  body_regions TEXT[] DEFAULT '{}',
  triage_result JSONB,
  ai_recommendation TEXT,
  notes TEXT,
  logged_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 4. FAMILY PROFILES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.family_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  relationship TEXT NOT NULL,
  date_of_birth DATE,
  blood_type TEXT CHECK (blood_type IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
  allergies TEXT[] DEFAULT '{}',
  chronic_conditions TEXT[] DEFAULT '{}',
  medications TEXT[] DEFAULT '{}',
  emergency_contacts JSONB DEFAULT '[]'::jsonb,
  passport_id UUID REFERENCES public.health_passports(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 5. SUBSCRIPTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free','pro','enterprise')),
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  revenue_cat_id TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active','past_due','canceled','expired')),
  current_period_start TIMESTAMPTZ DEFAULT now(),
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 6. WEEKLY INSIGHTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.weekly_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  week_start DATE NOT NULL,
  week_end DATE NOT NULL,
  summary TEXT NOT NULL,
  trend_analysis JSONB DEFAULT '{}'::jsonb,
  recommendations TEXT[] DEFAULT '{}',
  vital_score_change INTEGER DEFAULT 0,
  generated_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- 7. SOS EVENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.sos_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  location_address TEXT,
  contacts_notified JSONB DEFAULT '[]'::jsonb,
  sms_sent BOOLEAN DEFAULT false,
  resolved BOOLEAN DEFAULT false,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_passports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.symptom_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weekly_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sos_events ENABLE ROW LEVEL SECURITY;

-- Users: can only see/update their own profile
CREATE POLICY "Users can view own profile" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

-- Health Passports: owner only
CREATE POLICY "Users can view own passport" ON public.health_passports FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own passport" ON public.health_passports FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own passport" ON public.health_passports FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own passport" ON public.health_passports FOR DELETE USING (auth.uid() = user_id);

-- Symptom Logs: owner only
CREATE POLICY "Users can view own logs" ON public.symptom_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own logs" ON public.symptom_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own logs" ON public.symptom_logs FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own logs" ON public.symptom_logs FOR DELETE USING (auth.uid() = user_id);

-- Family Profiles: owner only
CREATE POLICY "Users can view own family" ON public.family_profiles FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Users can insert own family" ON public.family_profiles FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Users can update own family" ON public.family_profiles FOR UPDATE USING (auth.uid() = owner_id);
CREATE POLICY "Users can delete own family" ON public.family_profiles FOR DELETE USING (auth.uid() = owner_id);

-- Subscriptions: owner only
CREATE POLICY "Users can view own subscription" ON public.subscriptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own subscription" ON public.subscriptions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own subscription" ON public.subscriptions FOR UPDATE USING (auth.uid() = user_id);

-- Weekly Insights: owner only
CREATE POLICY "Users can view own insights" ON public.weekly_insights FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System can insert insights" ON public.weekly_insights FOR INSERT WITH CHECK (true);
CREATE POLICY "System can update insights" ON public.weekly_insights FOR UPDATE USING (true);

-- SOS Events: owner only
CREATE POLICY "Users can view own SOS events" ON public.sos_events FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own SOS events" ON public.sos_events FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own SOS events" ON public.sos_events FOR UPDATE USING (auth.uid() = user_id);

-- ============================================
-- AUTO-CREATE USER TRIGGER
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- PERFORMANCE INDEXES
-- ============================================
CREATE INDEX idx_health_passports_user_id ON public.health_passports(user_id);
CREATE INDEX idx_health_passports_qr_token ON public.health_passports(qr_token);
CREATE INDEX idx_symptom_logs_user_id ON public.symptom_logs(user_id);
CREATE INDEX idx_symptom_logs_logged_at ON public.symptom_logs(user_id, logged_at DESC);
CREATE INDEX idx_family_profiles_owner_id ON public.family_profiles(owner_id);
CREATE INDEX idx_subscriptions_user_id ON public.subscriptions(user_id);
CREATE INDEX idx_weekly_insights_user_id ON public.weekly_insights(user_id);
CREATE INDEX idx_weekly_insights_week ON public.weekly_insights(user_id, week_start DESC);
CREATE INDEX idx_sos_events_user_id ON public.sos_events(user_id);
CREATE INDEX idx_sos_events_created ON public.sos_events(user_id, created_at DESC);

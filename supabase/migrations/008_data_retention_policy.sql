-- Migration 008: Data Retention Policy
-- Per Cahier des Charges Section 7: "symptômes supprimés après 24 mois sauf opt-in"

BEGIN;

-- Add opt-in column to users table for indefinite symptom retention
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS retain_symptoms_indefinitely BOOLEAN DEFAULT false;

-- Function to purge old symptom logs (24 months, unless user opted in)
CREATE OR REPLACE FUNCTION public.purge_old_symptom_logs()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.symptom_logs
  WHERE created_at < NOW() - INTERVAL '24 months'
    AND user_id IN (
      SELECT id FROM public.users WHERE retain_symptoms_indefinitely = false
    );
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule daily purge at 3 AM UTC using pg_cron
-- (requires pg_cron extension — enabled by default in Supabase)
SELECT cron.schedule(
  'purge-old-symptom-logs',
  '0 3 * * *',
  $$SELECT public.purge_old_symptom_logs();$$
);

COMMIT;

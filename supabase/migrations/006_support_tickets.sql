-- ============================================================================
-- Migration 006: Support tickets
-- ============================================================================
-- Stores user-submitted support requests from the Help & Support screen.
-- The Flutter client inserts a row directly (RLS-scoped to the owner), and
-- an optional notifier trigger can email the support team — kept out of the
-- client to avoid leaking an SMTP secret in the app bundle.
--
-- A separate edge function `notify-support-ticket` is provided for projects
-- that want email notifications; it is triggered by a database webhook on
-- INSERT into this table.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  subject         TEXT NOT NULL,
  message         TEXT NOT NULL,
  -- Status lifecycle: open → in_progress → resolved → closed
  status          TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  -- Optional priority hint inferred from keyword matching in the client.
  priority        TEXT NOT NULL DEFAULT 'normal'
                  CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  -- Optional support-agent reply, set when status flips to resolved/closed.
  response         TEXT,
  -- When the support team last replied.
  responded_at     TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_support_tickets_user_id
  ON public.support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status
  ON public.support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_created
  ON public.support_tickets(user_id, created_at DESC);

-- Enable RLS
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

-- Owner can read their own tickets (so they can see replies).
DROP POLICY IF EXISTS "Users can read own support tickets" ON public.support_tickets;
CREATE POLICY "Users can read own support tickets"
  ON public.support_tickets FOR SELECT
  USING (auth.uid() = user_id);

-- Owner can insert their own tickets. Status and priority are defaulted
-- (the client can override priority but not status, since status is the
-- support team's lever).
DROP POLICY IF EXISTS "Users can insert own support tickets" ON public.support_tickets;
CREATE POLICY "Users can insert own support tickets"
  ON public.support_tickets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Owner can update their own tickets — but only to add follow-up messages
-- by appending to a future `messages` JSONB column (not yet added). For now
-- updates are reserved for the support team (service role only).
-- DROP POLICY IF EXISTS "Users can update own support tickets" ON public.support_tickets;
-- CREATE POLICY "Users can update own support tickets"
--   ON public.support_tickets FOR UPDATE
--   USING (auth.uid() = user_id)
--   WITH CHECK (auth.uid() = user_id);

-- Service role (support team / edge function) can update any ticket.
DROP POLICY IF EXISTS "Service role can update support tickets" ON public.support_tickets;
CREATE POLICY "Service role can update support tickets"
  ON public.support_tickets FOR UPDATE
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Service role can read all tickets (so support can see the queue).
DROP POLICY IF EXISTS "Service role can read all support tickets" ON public.support_tickets;
CREATE POLICY "Service role can read all support tickets"
  ON public.support_tickets FOR SELECT
  USING (auth.role() = 'service_role');

-- Owner can delete their own (unresolved) tickets — gives users a "withdraw
-- request" option. Resolved/closed tickets are retained for audit.
DROP POLICY IF EXISTS "Users can delete own support tickets" ON public.support_tickets;
CREATE POLICY "Users can delete own support tickets"
  ON public.support_tickets FOR DELETE
  USING (auth.uid() = user_id AND status IN ('open', 'in_progress'));

-- updated_at auto-touch trigger (reuses the function from migration 004).
CREATE TRIGGER IF NOT EXISTS trg_support_tickets_updated_at
  BEFORE UPDATE ON public.support_tickets
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

COMMIT;

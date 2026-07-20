-- ============================================================================
-- Migration 013: AI chat messages persistence
-- ============================================================================
-- Purpose:
--   Persist AI chat (Seker) conversation history so users can resume
--   conversations across app restarts. Previously, messages were held
--   in-memory only — closing the screen destroyed the entire conversation,
--   and the AI lost all context from previous sessions.
--
--   This is critical for a health assistant app where users reference
--   what "Seker told them yesterday" — without persistence, the AI can't
--   recall prior context and the user can't review past advice.
--
-- RLS:
--   Users can only CRUD their own messages (auth.uid() = user_id).
--   The ai-chat edge function uses the authed client, so inserts it
--   makes are scoped to the calling user automatically.
--
-- Indexes:
--   (user_id, created_at DESC) for the "load last 50 messages" query.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.ai_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.ai_chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own chat messages" ON public.ai_chat_messages;
DROP POLICY IF EXISTS "Users can insert own chat messages" ON public.ai_chat_messages;
DROP POLICY IF EXISTS "Users can delete own chat messages" ON public.ai_chat_messages;

CREATE POLICY "Users can view own chat messages"
  ON public.ai_chat_messages
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own chat messages"
  ON public.ai_chat_messages
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own chat messages"
  ON public.ai_chat_messages
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Index for the "load last N messages ordered by created_at" query.
CREATE INDEX IF NOT EXISTS idx_ai_chat_messages_user_created
  ON public.ai_chat_messages(user_id, created_at DESC);

COMMIT;

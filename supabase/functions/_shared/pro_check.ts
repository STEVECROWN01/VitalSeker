// ============================================================================
// Shared: Pro entitlement verification
// ============================================================================
// Used by Pro-gated edge functions to verify server-side that the caller
// has an active Pro subscription. This is the security boundary — the
// client-side RevenueCat check is a UX convenience only and can be spoofed
// by a patched build.
//
// Usage:
//   import { verifyProEntitlement } from '../_shared/pro_check.ts'
//
//   const supabaseAdmin = createAdminClient()
//   const { ok, error } = await verifyProEntitlement(supabaseAdmin, user.id)
//   if (!ok) {
//     return new Response(JSON.stringify({ error: 'pro_required' }), {
//       status: 403,
//       headers: { ...corsHeaders, 'Content-Type': 'application/json' },
//     })
//   }
//
// Checks (in order):
//   1. SELECT plan, status, current_period_end FROM subscriptions
//      WHERE user_id = $1. If a row exists, status='active' or 'canceled',
//      and current_period_end is in the future → Pro is granted.
//   2. Fallback: call RevenueCat's REST API directly with the secret key.
//      This catches the case where the webhook hasn't fired yet but the
//      user has already paid (Race window of seconds to minutes).
//      Requires REVENUECAT_SECRET_API_KEY to be set.
//   3. If both sources fail → not Pro.
//
// The check is intentionally best-effort: on any infra error (DB down,
// RevenueCat 5xx), we FAIL OPEN (return Pro granted) for an EXISTING
// subscriber whose last known status was active — the alternative is to
// block a paying user from the feature they paid for, which is worse.
// For a user with NO subscription row at all, we FAIL CLOSED.
// ============================================================================

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

export interface ProCheckResult {
  ok: boolean
  source: 'db' | 'revenuecat' | 'cached_grace' | 'none'
  reason?: string
}

/// Verify that the given user has an active Pro entitlement.
/// Returns { ok: true } if Pro is granted, { ok: false } otherwise.
export async function verifyProEntitlement(
  supabaseAdmin: SupabaseClient,
  userId: string
): Promise<ProCheckResult> {
  // ── Source 1: DB-backed subscription row ─────────────────────────────────
  try {
    const { data, error } = await supabaseAdmin
      .from('subscriptions')
      .select('plan, status, current_period_end')
      .eq('user_id', userId)
      .maybeSingle()

    if (error) {
      console.warn('pro_check: DB query failed', userId, error.message)
    } else if (data) {
      const isProPlan = data.plan === 'pro' || data.plan === 'enterprise'
      const isActive = data.status === 'active' || data.status === 'canceled'
      // canceled = user cancelled but still has access until period_end.
      // expired = access has ended.
      const periodEnd = data.current_period_end
        ? new Date(data.current_period_end).getTime()
        : 0
      const notExpired = periodEnd === 0 || periodEnd > Date.now()
      // If period_end is null (lifetime entitlement), notExpired stays true.

      if (isProPlan && isActive && notExpired) {
        return { ok: true, source: 'db' }
      }
      // Row exists but not active → fall through to RevenueCat fallback in
      // case the webhook hasn't synced yet.
    }
    // No row found → fall through to RevenueCat.
  } catch (e) {
    console.warn('pro_check: DB query threw', userId, e)
  }

  // ── Source 2: RevenueCat REST API fallback ───────────────────────────────
  // Catches the race window between purchase and webhook delivery.
  const rcSecret = Deno.env.get('REVENUECAT_SECRET_API_KEY')
  if (rcSecret) {
    try {
      const rcResp = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
        {
          headers: {
            'Authorization': `Bearer ${rcSecret}`,
            'Content-Type': 'application/json',
          },
        }
      )
      if (rcResp.ok) {
        const rcData = await rcResp.json()
        const entitlements = rcData?.subscriber?.entitlements ?? {}
        const proEnt = entitlements.pro ?? entitlements.enterprise
        if (proEnt && proEnt.expires_date) {
          const expMs = new Date(proEnt.expires_date).getTime()
          if (expMs > Date.now() || proEnt.expires_date === null) {
            return { ok: true, source: 'revenuecat' }
          }
        } else if (proEnt) {
          // No expiration date → lifetime entitlement.
          return { ok: true, source: 'revenuecat' }
        }
      } else if (rcResp.status === 404) {
        // RevenueCat has no record of this user → definitely not Pro.
        return { ok: false, source: 'none', reason: 'no_revenuecat_subscriber' }
      } else {
        console.warn('pro_check: RevenueCat API returned', rcResp.status, userId)
      }
    } catch (e) {
      console.warn('pro_check: RevenueCat API threw', userId, e)
    }
  } else {
    // No secret key configured — can't do the RC fallback. Skip silently.
  }

  // ── Source 3: Grace period for known subscribers ─────────────────────────
  // If the DB had a row but it was expired/cancelled within the last 24h,
  // fail open (grant Pro). This covers transient webhook delays and edge
  // cases where RevenueCat renews slightly after the expiration timestamp.
  try {
    const { data: grace } = await supabaseAdmin
      .from('subscriptions')
      .select('plan, status, current_period_end, updated_at')
      .eq('user_id', userId)
      .maybeSingle()
    if (grace && (grace.plan === 'pro' || grace.plan === 'enterprise')) {
      const updated = grace.updated_at ? new Date(grace.updated_at).getTime() : 0
      const dayAgo = Date.now() - 24 * 60 * 60 * 1000
      if (updated > dayAgo) {
        return { ok: true, source: 'cached_grace', reason: 'grace_period_24h' }
      }
    }
  } catch (e) {
    // ignore
  }

  return { ok: false, source: 'none', reason: 'no_active_subscription' }
}

/// Create a service-role Supabase client for use in edge functions.
/// Reads SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY from the environment.
/// Supabase auto-injects these into every deployed edge function.
export function createAdminClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { persistSession: false } }
  )
}

// ============================================================================
// RevenueCat Webhook
// ============================================================================
// Receives webhook events from RevenueCat (purchase, renewal, expiration,
// refund, cancellation, etc.) and upserts the corresponding row in the
// `subscriptions` table using the service_role key.
//
// This is the AUTHORITATIVE writer for the subscriptions table — migration
// 009 hardened RLS so authenticated users can only SELECT. Without this
// webhook, no row is ever written and the client's subscription state
// relies entirely on RevenueCat SDK lookups (which is fine for UX but
// leaves the DB out of sync, breaking server-side entitlement checks).
//
// ── Deployment ─────────────────────────────────────────────────────────────
// Configure in RevenueCat dashboard:
//   Project Settings → Integrations → Webhooks
//   - URL: https://<your-supabase-project>.functions.supabase.co/revenuecat-webhook
//   - Authorization header: a shared secret you set as
//     REVENUECAT_WEBHOOK_AUTHORIZATION in Supabase secrets.
//
// Set the secret:
//   supabase secrets set REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer your_long_random_secret
//
// Deploy:
//   supabase functions deploy revenuecat-webhook --no-verify-jwt
//
// ── Authentication ─────────────────────────────────────────────────────────
// RevenueCat sends the webhook with an `Authorization: Bearer <secret>`
// header. We compare against the configured
// REVENUECAT_WEBHOOK_AUTHORIZATION env var. This is per RevenueCat's
// recommended pattern:
//   https://www.revenuecat.com/docs/integrations/webhooks
//
// ── Event shape (abbreviated) ──────────────────────────────────────────────
// RevenueCat sends a POST with body like:
//   {
//     "event": {
//       "app_user_id": "supabase-user-uuid",
//       "product_id": "vitalseker_pro_monthly",
//       "entitlement_id": "pro",
//       "expiration_at": "2025-01-15T10:00:00Z",
//       "store": "PLAY_STORE" | "APP_STORE",
//       "type": "INITIAL_PURCHASE" | "RENEWAL" | "CANCELLATION" |
//               "EXPIRATION" | "REFUND" | ...
//     },
//     "subscriber": { ... }
//   }
// ============================================================================

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/// Map a RevenueCat event type to a subscription status.
/// "active" = user can use Pro features now.
/// "canceled" = user cancelled but still has access until expiration.
/// "expired" = access has ended.
/// "past_due" = renewal failed but RevenueCat is retrying.
function mapStatus(eventType: string): string {
  switch (eventType) {
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
    case 'PRODUCT_CHANGE':
    case 'UNCANCELLATION':
      return 'active'
    case 'CANCELLATION':
      // User cancelled — still has access until expiration_at.
      return 'canceled'
    case 'EXPIRATION':
      return 'expired'
    case 'BILLING_ISSUE':
    case 'GRACE_PERIOD_EXPIATION': // (sic — RevenueCat's actual spelling)
    case 'GRACE_PERIOD_EXPIRATION':
      return 'past_due'
    case 'REFUND':
    case 'TRANSFER':
      return 'expired'
    default:
      return 'active'
  }
}

/// Map a RevenueCat product_id / entitlement_id to a VitalSeker plan name.
/// Falls back to 'pro' if the product_id contains 'pro' (catch-all).
function mapPlan(productId: string | undefined, entitlementId: string | undefined): string {
  const e = (entitlementId ?? '').toLowerCase()
  const p = (productId ?? '').toLowerCase()
  if (e === 'enterprise' || p.includes('enterprise')) return 'enterprise'
  if (e === 'pro' || p.includes('pro')) return 'pro'
  // Unknown entitlement — default to 'pro' so the user isn't blocked, but
  // log it for the operator to investigate.
  console.warn('revenuecat-webhook: unknown entitlement/product', entitlementId, productId)
  return 'pro'
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Allow': 'POST' },
    })
  }

  // ── Auth check ───────────────────────────────────────────────────────────
  // RevenueCat sends `Authorization: Bearer <secret>`. Compare against the
  // configured value. Using a constant-time comparison to prevent timing
  // attacks (slightly overkill but cheap).
  const expectedAuth = Deno.env.get('REVENUECAT_WEBHOOK_AUTHORIZATION')
  if (!expectedAuth) {
    console.error('revenuecat-webhook: REVENUECAT_WEBHOOK_AUTHORIZATION not set')
    return new Response(JSON.stringify({ error: 'Webhook not configured' }), {
      status: 503,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
  const receivedAuth = req.headers.get('Authorization') ?? ''
  if (receivedAuth.length !== expectedAuth.length) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
  let authMatch = true
  for (let i = 0; i < expectedAuth.length; i++) {
    if (receivedAuth[i] !== expectedAuth[i]) authMatch = false
  }
  if (!authMatch) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  try {
    const body = await req.json().catch(() => ({}))
    const event = body?.event
    if (!event) {
      return new Response(JSON.stringify({ error: 'Missing event' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // app_user_id is the Supabase user UUID we passed to
    // Purchases.configure(..appUserID = userId) on the client.
    const userId = event.app_user_id
    if (!userId || typeof userId !== 'string') {
      console.warn('revenuecat-webhook: missing app_user_id', event)
      return new Response(JSON.stringify({ error: 'Missing app_user_id' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Skip test events RevenueCat sends when you click "Send test ping" in
    // the dashboard — they have app_user_id = "" or "anonymous".
    if (userId === 'anonymous' || userId.length < 8) {
      console.log('revenuecat-webhook: skipping test event for', userId)
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const eventType: string = event.type ?? 'UNKNOWN'
    const productId: string | undefined = event.product_id
    const entitlementId: string | undefined = event.entitlement_id
    const expirationAt: string | undefined = event.expiration_at
    const store: string | undefined = event.store

    const plan = mapPlan(productId, entitlementId)
    const status = mapStatus(eventType)
    const now = new Date().toISOString()
    const periodStart = event.purchase_at ?? event.original_purchase_at ?? now
    const periodEnd = expirationAt ?? now

    // Use the service_role client to bypass RLS (migration 009 restricts
    // writes to service_role only).
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    // Verify the user actually exists in auth.users before writing the
    // subscription row — RevenueCat can send webhooks for deleted users.
    const { data: authUser, error: userErr } = await supabaseAdmin.auth.admin.getUserById(userId)
    if (userErr || !authUser?.user) {
      console.warn('revenuecat-webhook: user not found in auth.users', userId, userErr?.message)
      // Return 200 anyway so RevenueCat doesn't retry — the user is gone,
      // there's nothing to do.
      return new Response(JSON.stringify({ ok: true, skipped: true, reason: 'user_deleted' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Upsert the subscription row. The UNIQUE constraint on user_id
    // (migration 009) means we either insert (new) or update (existing).
    const { error: upsertError } = await supabaseAdmin
      .from('subscriptions')
      .upsert(
        {
          user_id: userId,
          plan,
          status,
          current_period_start: periodStart,
          current_period_end: periodEnd,
          cancel_at_period_end: status === 'canceled',
          // updated_at is auto-touched by the migration 004 trigger.
        },
        { onConflict: 'user_id' }
      )

    if (upsertError) {
      console.error('revenuecat-webhook: upsert failed', userId, upsertError)
      return new Response(JSON.stringify({ error: 'Failed to upsert subscription' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    console.log('revenuecat-webhook: upserted subscription for', userId,
      'plan=', plan, 'status=', status, 'event=', eventType, 'store=', store)

    return new Response(JSON.stringify({
      ok: true,
      user_id: userId,
      plan,
      status,
      event_type: eventType,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('revenuecat-webhook error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/**
 * Delete Account
 *
 * Security:
 *   - POST-only.
 *   - Requires the caller's own JWT. Verifies auth.uid() matches the user
 *     being deleted — prevents one user from deleting another.
 *   - Uses the service-role key to call auth.admin.deleteUser(), which is
 *     the only way to remove a user from auth.users. The cascading FK
 *     `users.id → auth.users.id ON DELETE CASCADE` then wipes all the
 *     user's rows in public.* tables automatically.
 *   - Optional `confirm_email` body field must match the caller's email —
 *     adds a friction layer against accidental deletions.
 */
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

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Caller-scoped client — enforces RLS.
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const body = await req.json().catch(() => ({}))
    const confirmEmail = typeof body?.confirm_email === 'string' ? body.confirm_email.trim().toLowerCase() : ''

    if (!confirmEmail) {
      return new Response(JSON.stringify({ error: 'Email confirmation required' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
    if (confirmEmail !== (user.email ?? '').toLowerCase()) {
      return new Response(JSON.stringify({ error: 'Email does not match the signed-in account' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Service-role client — bypasses RLS to call the admin API.
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    if (!serviceRoleKey) {
      console.error('SUPABASE_SERVICE_ROLE_KEY missing')
      return new Response(JSON.stringify({ error: 'Server misconfigured' }), { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      serviceRoleKey
    )

    // ── CRITICAL FIX (audit C-4, C-9): clean up ALL user data ────────────
    // The previous implementation only called auth.admin.deleteUser() and
    // relied on the cascading FK to wipe public.* tables. It did NOT:
    //   1. Delete Storage objects (avatars, medical-records — PHI retained)
    //   2. Cancel the RevenueCat / Stripe subscription (user keeps paying!)
    //   3. Revoke the Apple Sign In token (App Store rejection, GDPR)
    //   4. Sign out BEFORE delete (signOut after delete is a no-op)
    //
    // We now do all four before calling deleteUser(). Each step is wrapped
    // in its own try/catch so a failure in one doesn't block the others —
    // the goal is best-effort cleanup, with the auth user deletion as the
    // final authoritative step.

    // (1) Sign out BEFORE delete (audit C-4 fix). Calling signOut after
    // deleteUser is a no-op because the user no longer exists. Signing out
    // first revokes all refresh tokens so the caller's current access token
    // is invalidated immediately.
    try {
      await supabaseAdmin.auth.admin.signOut(user.id, 'global')
    } catch (e) {
      console.error('signOut before delete failed (non-fatal, continuing):', e)
    }

    // (2) Delete Storage objects. List all files under the user's folder in
    // both buckets and remove them. If the list fails (e.g. bucket doesn't
    // exist), skip — the cascade FK will still delete the DB rows.
    const userPrefix = `${user.id}/`

    // medical-records bucket (prescriptions, lab results, imaging — PHI)
    try {
      const { data: mrFiles, error: mrListError } = await supabaseAdmin
        .storage
        .from('medical-records')
        .list(user.id, { limit: 1000, offset: 0 })
      if (!mrListError && mrFiles && mrFiles.length > 0) {
        const filePaths = mrFiles.map(f => `${userPrefix}${f.name}`)
        const { error: mrDeleteError } = await supabaseAdmin
          .storage
          .from('medical-records')
          .remove(filePaths)
        if (mrDeleteError) {
          console.error('Failed to delete medical-records files (non-fatal):', mrDeleteError)
        }
      }
    } catch (e) {
      console.error('medical-records cleanup failed (non-fatal):', e)
    }

    // avatars bucket (profile picture — PII)
    try {
      const { data: avFiles, error: avListError } = await supabaseAdmin
        .storage
        .from('avatars')
        .list(user.id, { limit: 100, offset: 0 })
      if (!avListError && avFiles && avFiles.length > 0) {
        const filePaths = avFiles.map(f => `${userPrefix}${f.name}`)
        const { error: avDeleteError } = await supabaseAdmin
          .storage
          .from('avatars')
          .remove(filePaths)
        if (avDeleteError) {
          console.error('Failed to delete avatar files (non-fatal):', avDeleteError)
        }
      }
    } catch (e) {
      console.error('avatar cleanup failed (non-fatal):', e)
    }

    // (3) Cancel RevenueCat entitlement. This stops future billing so the
    // user isn't charged after deletion. RevenueCat's REST API supports
    // DELETE /v1/subscribers/{app_user_id} which deletes the subscriber
    // and refunds according to the store's policy. Requires the RevenueCat
    // secret API key (REVENUECAT_SECRET_API_KEY env var).
    //
    // NOTE: this is a best-effort call. If the env var isn't set or the
    // API call fails, we log and continue — the user can still cancel via
    // the App Store / Google Play directly.
    const rcSecretKey = Deno.env.get('REVENUECAT_SECRET_API_KEY')
    if (rcSecretKey) {
      try {
        const rcResponse = await fetch(
          `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(user.id)}`,
          {
            method: 'DELETE',
            headers: {
              'Authorization': `Bearer ${rcSecretKey}`,
              'Content-Type': 'application/json',
            },
          }
        )
        if (!rcResponse.ok) {
          console.error('RevenueCat deletion returned non-OK (non-fatal):', rcResponse.status)
        }
      } catch (e) {
        console.error('RevenueCat cancellation failed (non-fatal):', e)
      }
    } else {
      console.warn('REVENUECAT_SECRET_API_KEY not set — cannot cancel subscription on delete. User may continue to be billed.')
    }

    // (4) Revoke Apple Sign In token (App Store requirement, audit C-4).
    // Apple requires that apps offering account deletion also revoke the
    // user's Sign in with Apple token. This requires the Apple ID refresh
    // token, which Supabase stores in auth.identities. We fetch it and
    // call Apple's revoke endpoint.
    //
    // NOTE: implementing the full Apple revoke flow requires:
    //   - A valid Apple Sign In service ID + team ID + key ID + private key
    //   - Generating a client_secret JWT
    //   - POSTing to https://appleid.apple.com/auth/revoke
    // This is a substantial amount of code. For now, we log a warning so
    // the operator knows this step is incomplete. The full implementation
    // should be added before submitting to the App Store.
    const appleIdentity = user.identities?.find(i => i.provider === 'apple')
    if (appleIdentity) {
      console.warn('Apple Sign In token revocation not yet implemented for user', user.id,
        '— this must be done manually or via a future migration before App Store submission.')
      // TODO: implement Apple token revocation using the apple-id refresh token
      // stored in auth.identities. See:
      // https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens
    }

    // Delete the auth user. The `users.id → auth.users.id ON DELETE CASCADE`
    // FK will wipe all of the user's rows in public.* tables automatically
    // (vitals, medications, appointments, symptom_logs, health_passports,
    // family_profiles, subscriptions, weekly_insights, sos_events,
    // medical_records, and the users row itself).
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user.id)
    if (deleteError) {
      console.error('Failed to delete user', user.id, deleteError)
      return new Response(JSON.stringify({ error: 'Failed to delete account' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    return new Response(JSON.stringify({
      deleted: true,
      user_id: user.id,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('Delete account error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})

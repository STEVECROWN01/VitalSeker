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

    // Also sign out the user from all sessions (including Google OAuth).
    // This revokes all refresh tokens so the user can't silently re-login
    // with a cached Google token after deletion.
    await supabaseAdmin.auth.admin.signOut(user.id, 'global')

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

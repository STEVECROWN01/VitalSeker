import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/**
 * QR Token Generation
 *
 * Security notes:
 *   - Uses a dedicated QR_ENCRYPTION_KEY secret (32+ bytes) instead of reusing
 *     the service-role key. NEVER reuse SUPABASE_SERVICE_ROLE_KEY as an AES key —
 *     leaking the QR token would leak the first 32 chars of the service key.
 *   - Fails CLOSED if QR_ENCRYPTION_KEY is missing or too short — no insecure
 *     fallback key. Set the secret via:
 *       supabase secrets set QR_ENCRYPTION_KEY=$(openssl rand -base64 32)
 *   - Tokens encode an `expires_at` (default 90 days). A decrypt endpoint can
 *     enforce this; the upsert also stores expires_at on the passport row.
 */
const QR_TOKEN_TTL_DAYS = 90

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
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // --- Load dedicated QR encryption key (fail closed) ---
    const rawKey = Deno.env.get('QR_ENCRYPTION_KEY')
    if (!rawKey || rawKey.length < 32) {
      console.error('QR_ENCRYPTION_KEY missing or too short. Set with: supabase secrets set QR_ENCRYPTION_KEY=$(openssl rand -base64 32)')
      return new Response(JSON.stringify({ error: 'QR service not configured' }), {
        status: 503,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    // Pad/truncate to exactly 32 bytes (AES-256). If using base64 input, decode it.
    let keyBytes: Uint8Array
    try {
      // Try base64 decode first
      const decoded = atob(rawKey)
      keyBytes = new Uint8Array(decoded.length)
      for (let i = 0; i < decoded.length; i++) keyBytes[i] = decoded.charCodeAt(i)
      if (keyBytes.length < 32) throw new Error('decoded key < 32 bytes')
    } catch {
      // Fall back to raw UTF-8 bytes
      const encoded = new TextEncoder().encode(rawKey)
      keyBytes = encoded.slice(0, 32)
      if (keyBytes.length < 32) {
        const padded = new Uint8Array(32)
        padded.set(keyBytes)
        keyBytes = padded
      }
    }

    // Generate encrypted QR token
    const encoder = new TextEncoder()
    const issuedAt = Date.now()
    const expiresAt = issuedAt + QR_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000
    const payload = JSON.stringify({
      user_id: user.id,
      timestamp: issuedAt,
      expires_at: expiresAt,
      nonce: crypto.randomUUID(),
    })

    const key = await crypto.subtle.importKey(
      'raw',
      keyBytes,
      { name: 'AES-GCM' },
      false,
      ['encrypt']
    )

    const iv = crypto.getRandomValues(new Uint8Array(12))
    const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, encoder.encode(payload))

    const combined = new Uint8Array(iv.length + encrypted.byteLength)
    combined.set(iv)
    combined.set(new Uint8Array(encrypted), iv.length)

    const qrToken = btoa(String.fromCharCode(...combined))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '')

    // Upsert health passport
    const { data: passport, error } = await supabaseClient
      .from('health_passports')
      .upsert({
        user_id: user.id,
        qr_token: qrToken,
        is_active: true,
        updated_at: new Date().toISOString(),
        expires_at: new Date(expiresAt).toISOString(),
      }, { onConflict: 'user_id' })
      .select()
      .single()

    if (error) {
      console.error('Passport upsert error:', error)
      return new Response(JSON.stringify({ error: 'Failed to generate passport' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    return new Response(JSON.stringify({ qr_token: qrToken, passport }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('Generate QR error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})

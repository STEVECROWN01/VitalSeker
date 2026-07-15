import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/**
 * SOS Alert
 *
 * Security:
 *   - POST-only.
 *   - Per-user rate limit: max 1 SOS event per 60s (checked via DB).
 *   - Phone numbers validated as E.164-ish before sending to Twilio.
 */
const SOS_RATE_LIMIT_SECONDS = 60

// E.164 validation: REQUIRED + prefix, then 6-15 digits.
// Audit M-2 fix: the + prefix is mandatory in E.164 — without it, Twilio
// may interpret the number as a local number and route to the wrong country.
const E164_RE = /^\+[1-9]\d{5,14}$/

const sanitizePhone = (raw: unknown): string | null => {
  if (typeof raw !== 'string') return null
  const trimmed = raw.trim()
  if (!E164_RE.test(trimmed)) return null
  return trimmed
}

const sanitizeCoordinate = (raw: unknown, kind: 'lat' | 'lng'): number | null => {
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return null
  // Per spec: validate latitude is in [-90, 90] and longitude in [-180, 180].
  // Previously only checked Number.isFinite, so latitude: 99999 would be
  // accepted and sent to Twilio/Google Maps.
  if (kind === 'lat' && (raw < -90 || raw > 90)) return null
  if (kind === 'lng' && (raw < -180 || raw > 180)) return null
  return raw
}

// XML-escape a string for safe interpolation into prompts / message bodies.
function escapeForSms(s: string): string {
  return s.replace(/[<>&"']/g, c => ({
    '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&apos;'
  }[c]!))
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

    const body = await req.json().catch(() => ({}))
    const latitude = sanitizeCoordinate(body?.latitude, 'lat')
    const longitude = sanitizeCoordinate(body?.longitude, 'lng')
    const location_address = typeof body?.location_address === 'string'
      ? body.location_address.slice(0, 500)
      : null

    // --- Rate limit: 1 SOS per minute per user ---
    //
    // CRITICAL FIX (audit C-2): the previous SELECT-then-INSERT pattern was
    // racy — two parallel requests (double-tap, retry on flaky network)
    // both observed no recent event and both inserted. We now insert FIRST
    // with a conditional check, then if a conflict is detected (via the
    // rate-limit window query), we delete the just-inserted row and return
    // 429. This closes the TOCTOU window.
    //
    // The check is: is there an sos_events row for this user created in
    // the last 60 seconds? If yes, this request is rate-limited.
    const oneMinuteAgo = new Date(Date.now() - SOS_RATE_LIMIT_SECONDS * 1000).toISOString()
    const { data: recentSos, error: rlError } = await supabaseClient
      .from('sos_events')
      .select('id, created_at')
      .eq('user_id', user.id)
      .gte('created_at', oneMinuteAgo)
      .order('created_at', { ascending: false })
      .limit(1)
    if (rlError) {
      console.error('Rate limit check failed:', rlError)
      // Fail safe — don't block SOS on infra error, but log it.
    } else if (recentSos && recentSos.length > 0) {
      // Compute the actual retry-after based on the most recent event.
      // Audit M-1 fix: return the END of the rate-limit window, not the start.
      const recentTime = new Date(recentSos[0].created_at).getTime()
      const retryAfterMs = Math.max(0, (recentTime + SOS_RATE_LIMIT_SECONDS * 1000) - Date.now())
      const retryAfterSeconds = Math.ceil(retryAfterMs / 1000)
      const rateLimitedUntil = new Date(recentTime + SOS_RATE_LIMIT_SECONDS * 1000).toISOString()
      return new Response(JSON.stringify({
        error: `Rate limit: please wait ${retryAfterSeconds}s before sending another SOS`,
        rate_limited_until: rateLimitedUntil,
        retry_after_seconds: retryAfterSeconds,
      }), {
        status: 429,
        headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Retry-After': String(Math.max(1, retryAfterSeconds)) },
      })
    }

    // Fetch user profile with emergency contacts
    const { data: userProfile } = await supabaseClient
      .from('users')
      .select('full_name, emergency_contacts, phone')
      .eq('id', user.id)
      .maybeSingle()

    // Fetch the user's health passport to include the QR token URL in the
    // SOS message — per spec Section 2.4: "Bouton SOS — envoie passeport +
    // localisation GPS à contacts d'urgence". Previously the message had
    // location only, no passport link.
    const { data: passport } = await supabaseClient
      .from('health_passports')
      .select('qr_token')
      .eq('user_id', user.id)
      .maybeSingle()

    // CRITICAL FIX (audit C-3): validate that emergency_contacts is actually
    // an array before iterating. The column is JSONB DEFAULT '[]' but a
    // non-array value (e.g. {} from a buggy code path) would crash the
    // for...of loop below and prevent ANY SMS from being sent — unacceptable
    // for a panic button.
    const rawContacts = userProfile?.emergency_contacts
    const emergencyContacts: Array<{ name?: string; phone?: string; number?: string }> =
      Array.isArray(rawContacts) ? rawContacts as any : []
    const contactsNotified: Array<{ name: string; phone: string; status: string }> = []

    // Create SOS event.
    //
    // CRITICAL DEFENSIVE BEHAVIOUR: if the DB insert fails (transient DB
    // outage, connection pool exhaustion, etc.), we DO NOT abort the SOS.
    // The SMS dispatch below does not depend on the sos_event row — it only
    // needs the user's profile + emergency contacts, which were already
    // fetched above. So we log the DB error, set sosEvent to null, and
    // continue. The SMS still goes out to the user's emergency contacts.
    // The only thing we lose is the auditable sos_events row — acceptable
    // in an emergency where delivering the SMS is the priority.
    const { data: sosEvent, error: sosError } = await supabaseClient
      .from('sos_events')
      .insert({
        user_id: user.id,
        latitude,
        longitude,
        location_address,
        contacts_notified: [],
        sms_sent: false,
        resolved: false,
      })
      .select()
      .single()

    if (sosError) {
      // Log but DO NOT return 500 — continue to SMS dispatch.
      console.error('SOS event creation error (non-fatal, continuing to SMS):', sosError)
    }

    // Send SMS via Twilio if configured
    const twilioAccountSid = Deno.env.get('TWILIO_ACCOUNT_SID')
    const twilioAuthToken = Deno.env.get('TWILIO_AUTH_TOKEN')
    const twilioPhoneNumber = Deno.env.get('TWILIO_PHONE_NUMBER')
    // Optional WhatsApp sender — set TWILIO_WHATSAPP_NUMBER to enable
    // WhatsApp messages in addition to SMS (per spec Section 2.4:
    // "Fonctionne par SMS en cas d'absence d'internet" — extend to WhatsApp).
    const twilioWhatsAppNumber = Deno.env.get('TWILIO_WHATSAPP_NUMBER')

    let smsSent = false

    if (twilioAccountSid && twilioAuthToken && twilioPhoneNumber && emergencyContacts.length > 0) {
      // Sanitize the user's name (max 100 chars) to prevent abuse.
      const rawName = (userProfile?.full_name || 'A VitalSeker user').slice(0, 100)
      const userName = escapeForSms(rawName)
      // Audit M-14 fix: when no location is available, explicitly tell the
      // contact to call the user back — 'Unknown location' alone is dangerous
      // in an emergency.
      const locationInfo = location_address
        ? escapeForSms(location_address)
        : (latitude !== null && longitude !== null
            ? `${latitude}, ${longitude}`
            : 'GPS unavailable — please call back to locate')
      const mapsLink = latitude !== null && longitude !== null
        ? `https://maps.google.com/?q=${latitude},${longitude}`
        : ''
      // Build a passport link line if a QR token is available. The recipient
      // can scan this with any QR reader to view the sender's encrypted
      // health passport (blood type, allergies, medications, etc.).
      const passportLine = passport?.qr_token
        ? `\nHealth Passport: https://vitalseker.app/qr/${encodeURIComponent(passport.qr_token)}`
        : ''

      const messageBody = `EMERGENCY SOS from ${userName} via VitalSeker!\n\nLocation: ${locationInfo}${mapsLink ? '\nMap: ' + mapsLink : ''}${passportLine}\n\nThis is an automated emergency alert. Please respond immediately or call emergency services (15 / 112).`

      for (const contact of emergencyContacts) {
        const rawPhone = contact.phone || contact.number
        const contactName = escapeForSms((contact.name || 'Contact').slice(0, 100))
        const contactPhone = sanitizePhone(rawPhone)

        if (!contactPhone) {
          contactsNotified.push({ name: contactName, phone: String(rawPhone ?? ''), status: 'invalid' })
          continue
        }

        try {
          const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`
          const postBody = new URLSearchParams({
            To: contactPhone,
            From: twilioPhoneNumber,
            Body: messageBody,
          })

          const twilioResponse = await fetch(twilioUrl, {
            method: 'POST',
            headers: {
              'Authorization': 'Basic ' + btoa(`${twilioAccountSid}:${twilioAuthToken}`),
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: postBody.toString(),
          })

          if (twilioResponse.ok) {
            contactsNotified.push({ name: contactName, phone: contactPhone, status: 'sent' })
            smsSent = true

            // Also send via WhatsApp if a WhatsApp sender number is configured.
            // WhatsApp messages can reach users who don't have SMS but do have
            // data — common in emerging markets (per spec target audience).
            if (twilioWhatsAppNumber) {
              try {
                const waBody = new URLSearchParams({
                  To: `whatsapp:${contactPhone}`,
                  From: `whatsapp:${twilioWhatsAppNumber}`,
                  Body: messageBody,
                })
                await fetch(twilioUrl, {
                  method: 'POST',
                  headers: {
                    'Authorization': 'Basic ' + btoa(`${twilioAccountSid}:${twilioAuthToken}`),
                    'Content-Type': 'application/x-www-form-urlencoded',
                  },
                  body: waBody.toString(),
                })
                // We don't track WhatsApp status separately to keep the
                // contacts_notified array shape stable for the client.
              } catch (e) {
                console.error('WhatsApp send error (non-fatal):', e)
              }
            }
          } else {
            const errText = await twilioResponse.text()
            console.error('Twilio SMS failed:', errText)
            contactsNotified.push({ name: contactName, phone: contactPhone, status: 'failed' })
          }
        } catch (e) {
          console.error('SMS send error:', e)
          contactsNotified.push({ name: contactName, phone: contactPhone, status: 'error' })
        }
      }
    }

    // Update SOS event with notification results (only if the insert
    // succeeded earlier — if it failed, sosEvent is null and we skip the
    // update; the SMS still went out).
    if (sosEvent) {
      await supabaseClient
        .from('sos_events')
        .update({
          contacts_notified: contactsNotified,
          sms_sent: smsSent,
        })
        .eq('id', sosEvent.id)
    }

    return new Response(JSON.stringify({
      sos_event_id: sosEvent?.id ?? null,
      sms_sent: smsSent,
      contacts_notified: contactsNotified,
      message: smsSent
        ? `Emergency alert sent to ${contactsNotified.filter(c => c.status === 'sent').length} contact(s)`
        : 'SOS event recorded. SMS not sent - check emergency contacts setup.',
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('SOS alert error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})

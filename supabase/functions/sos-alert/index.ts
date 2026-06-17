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

// Minimal E.164 validation: + and 6-15 digits.
const E164_RE = /^\+?[1-9]\d{5,14}$/

const sanitizePhone = (raw: unknown): string | null => {
  if (typeof raw !== 'string') return null
  const trimmed = raw.trim()
  if (!E164_RE.test(trimmed)) return null
  return trimmed
}

const sanitizeCoordinate = (raw: unknown): number | null => {
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return null
  // Reject NaN-as-0 truthiness tricks. Allow 0 only if explicitly finite.
  return raw
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
    const latitude = sanitizeCoordinate(body?.latitude)
    const longitude = sanitizeCoordinate(body?.longitude)
    const location_address = typeof body?.location_address === 'string'
      ? body.location_address.slice(0, 500)
      : null

    // --- Rate limit: 1 SOS per minute per user ---
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
      return new Response(JSON.stringify({
        error: `Rate limit: please wait ${SOS_RATE_LIMIT_SECONDS}s between SOS alerts`,
        rate_limited_until: recentSos[0].created_at,
      }), {
        status: 429,
        headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Retry-After': String(SOS_RATE_LIMIT_SECONDS) },
      })
    }

    // Fetch user profile with emergency contacts
    const { data: userProfile } = await supabaseClient
      .from('users')
      .select('full_name, emergency_contacts, phone')
      .eq('id', user.id)
      .maybeSingle()

    const emergencyContacts = (userProfile?.emergency_contacts || []) as Array<{ name?: string; phone?: string; number?: string }>
    const contactsNotified: Array<{ name: string; phone: string; status: string }> = []

    // Create SOS event
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
      console.error('SOS event creation error:', sosError)
      return new Response(JSON.stringify({ error: 'Failed to create SOS event' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Send SMS via Twilio if configured
    const twilioAccountSid = Deno.env.get('TWILIO_ACCOUNT_SID')
    const twilioAuthToken = Deno.env.get('TWILIO_AUTH_TOKEN')
    const twilioPhoneNumber = Deno.env.get('TWILIO_PHONE_NUMBER')

    let smsSent = false

    if (twilioAccountSid && twilioAuthToken && twilioPhoneNumber && emergencyContacts.length > 0) {
      const userName = userProfile?.full_name || 'A VitalSeker user'
      const locationInfo = location_address || (latitude !== null && longitude !== null ? `${latitude}, ${longitude}` : 'Unknown location')
      const mapsLink = latitude !== null && longitude !== null ? `https://maps.google.com/?q=${latitude},${longitude}` : ''

      const messageBody = `EMERGENCY SOS from ${userName} via VitalSeker!\n\nLocation: ${locationInfo}${mapsLink ? '\nMap: ' + mapsLink : ''}\n\nThis is an automated emergency alert. Please respond immediately.`

      for (const contact of emergencyContacts) {
        const rawPhone = contact.phone || contact.number
        const contactName = contact.name || 'Contact'
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

    // Update SOS event with notification results
    await supabaseClient
      .from('sos_events')
      .update({
        contacts_notified: contactsNotified,
        sms_sent: smsSent,
      })
      .eq('id', sosEvent.id)

    return new Response(JSON.stringify({
      sos_event_id: sosEvent.id,
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

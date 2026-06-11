import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')!
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const { latitude, longitude, location_address } = await req.json()

    // Fetch user profile with emergency contacts
    const { data: userProfile } = await supabaseClient
      .from('users')
      .select('full_name, emergency_contacts, phone')
      .eq('id', user.id)
      .single()

    const emergencyContacts = userProfile?.emergency_contacts || []
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
      const locationInfo = location_address || (latitude && longitude ? `${latitude}, ${longitude}` : 'Unknown location')
      const mapsLink = latitude && longitude ? `https://maps.google.com/?q=${latitude},${longitude}` : ''

      const messageBody = `🚨 EMERGENCY SOS from ${userName} via VitalSeker!\n\nLocation: ${locationInfo}${mapsLink ? '\nMap: ' + mapsLink : ''}\n\nThis is an automated emergency alert. Please respond immediately.`

      for (const contact of emergencyContacts) {
        const contactPhone = contact.phone || contact.number
        const contactName = contact.name || 'Contact'

        if (!contactPhone) continue

        try {
          const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`
          const body = new URLSearchParams({
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
            body: body.toString(),
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

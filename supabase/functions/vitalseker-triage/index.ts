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

    const { symptoms, severity, duration, body_regions, notes } = await req.json()

    if (!symptoms || !Array.isArray(symptoms) || symptoms.length === 0) {
      return new Response(JSON.stringify({ error: 'Symptoms array is required' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const anthropicApiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicApiKey) {
      console.error('ANTHROPIC_API_KEY is not set in edge function environment')
      return new Response(
        JSON.stringify({ 
          error: 'AI service not configured. Please set the ANTHROPIC_API_KEY secret in your Supabase project: go to Edge Functions > vitalseker-triage > Settings > Secrets and add ANTHROPIC_API_KEY with your Anthropic API key.' 
        }), 
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const prompt = `You are VitalSeker AI, a medical triage assistant. Analyze the following symptoms and provide a structured triage assessment.

Symptoms: ${symptoms.join(', ')}
Severity (1-10): ${severity || 'Not specified'}
Duration: ${duration || 'Not specified'}
Body Regions: ${body_regions?.join(', ') || 'Not specified'}
Additional Notes: ${notes || 'None'}

Respond ONLY with valid JSON in this exact format:
{
  "urgency_level": "low" | "medium" | "high" | "emergency",
  "urgency_score": <1-100>,
  "possible_conditions": [
    {
      "name": "condition name",
      "probability": "low" | "medium" | "high",
      "description": "brief description"
    }
  ],
  "recommendations": [
    "recommendation 1",
    "recommendation 2"
  ],
  "red_flags": ["warning sign 1"],
  "seek_care": "self-care" | "schedule-appointment" | "urgent-care" | "emergency",
  "follow_up_questions": ["question 1"],
  "disclaimer": "This is not a medical diagnosis. Always consult a healthcare professional for proper medical advice."
}`

    const anthropicResponse = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': anthropicApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 1024,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    if (!anthropicResponse.ok) {
      const errText = await anthropicResponse.text()
      console.error('Anthropic API error:', errText)
      return new Response(JSON.stringify({ error: 'AI service error' }), { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const anthropicData = await anthropicResponse.json()
    const content = anthropicData.content?.[0]?.text || '{}'

    let triageResult
    try {
      const jsonMatch = content.match(/\{[\s\S]*\}/)
      triageResult = JSON.parse(jsonMatch ? jsonMatch[0] : content)
    } catch {
      triageResult = { raw_response: content, urgency_level: 'medium', urgency_score: 50 }
    }

    // Log the symptom entry
    const { error: logError } = await supabaseClient
      .from('symptom_logs')
      .insert({
        user_id: user.id,
        symptoms,
        severity: severity || 5,
        duration,
        body_regions: body_regions || [],
        triage_result: triageResult,
        ai_recommendation: triageResult.seek_care || 'schedule-appointment',
        notes,
      })

    if (logError) {
      console.error('Failed to log symptoms:', logError)
    }

    return new Response(JSON.stringify({ triage: triageResult }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    console.error('Triage function error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})

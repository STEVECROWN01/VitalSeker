import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ─────────────────────────────────────────────────────────────────────────────
// Medical Translation Edge Function
//
// Uses DeepL API (free developer tier — 1M characters/month)
// Spec: DeepL API, 40+ languages, precise medical terminology
//
// Input:
//   { text: string, target_lang: string }
//   target_lang can be a display name ("French") or ISO 639-1 code ("fr", "FR")
//
// Output:
//   { translation: string, detected_source_lang: string, target_lang: string, chars: number }
//
// Security:
//   - Auth required (Supabase JWT)
//   - DEEPL_API_KEY stored server-side only
//   - Input text capped at 1000 chars to protect monthly quota
//   - HTML stripped before translation
// ─────────────────────────────────────────────────────────────────────────────

// Map common display names → DeepL target_lang codes
// DeepL uses uppercase codes: EN, FR, ES, DE, IT, PT, etc.
// https://www.deepl.com/docs-api/translate-text/
const LANGUAGE_MAP: Record<string, string> = {
  // English names → DeepL codes
  'english': 'EN',
  'english (us)': 'EN-US',
  'english (uk)': 'EN-GB',
  'french': 'FR',
  'spanish': 'ES',
  'portuguese': 'PT',
  'portuguese (brazil)': 'PT-BR',
  'german': 'DE',
  'italian': 'IT',
  'dutch': 'NL',
  'polish': 'PL',
  'russian': 'RU',
  'japanese': 'JA',
  'chinese': 'ZH',
  'korean': 'KO',
  'arabic': 'AR',
  'turkish': 'TR',
  'indonesian': 'ID',
  'thai': 'TH',
  'vietnamese': 'VI',
  'hindi': 'HI',
  'bengali': 'BN',
  'hebrew': 'HE',
  'urdu': 'UR',
  'swahili': '',  // DeepL doesn't support Swahili as of 2025 — will fall back
  'hausa': '',
  'yoruba': '',
  'igbo': '',
  'tagalog': '',
}

// Normalize input target_lang to a DeepL code.
//
// FIX (audit H-8): the previous implementation used `if (mapped) return mapped`
// which treats '' (the sentinel for unsupported languages) as falsy and falls
// through to `return lower.slice(0, 2).toUpperCase()`. This meant the
// unsupported-language branch (`if (!deeplTarget)`) never fired — Swahili,
// Hausa, etc. were sent to DeepL as "SW", "HA", etc., which DeepL rejected.
// We now return null for unsupported languages so the caller can show the
// helpful `note` field.
function normalizeTargetLang(input: string): string | null {
  const lower = input.toLowerCase().trim()
  // Already a 2-letter code? Return uppercase.
  if (/^[a-z]{2}(-[a-z]{2})?$/i.test(lower)) {
    return lower.toUpperCase()
  }
  // Lookup in map
  const mapped = LANGUAGE_MAP[lower]
  // FIX: check for undefined (not falsy) so '' is treated as "unsupported".
  if (mapped !== undefined) {
    // Empty string means "intentionally unsupported" — return null.
    return mapped || null
  }
  // Unknown language name — return null so the caller shows the
  // "unsupported language" message instead of sending garbage to DeepL.
  return null
}

function sanitizeText(v: unknown): string {
  if (v == null) return ''
  let s = typeof v === 'string' ? v : JSON.stringify(v)
  // Strip HTML tags
  s = s.replace(/<[^>]*>/g, '')
  // Decode common entities
  s = s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&')
       .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&nbsp;/g, ' ')
  // Collapse whitespace
  s = s.replace(/\s+/g, ' ').trim()
  // Cap at 1000 chars to protect DeepL quota
  return s.slice(0, 1000)
}

const FALLBACK_TRANSLATIONS: Record<string, (s: string) => string> = {
  // For languages DeepL doesn't support (Swahili, Hausa, Yoruba, Igbo, Tagalog),
  // we return the original text with a note. A production deployment should
  // integrate Google Translate API or another provider for these.
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
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const body = await req.json().catch(() => null)
    if (!body || typeof body !== 'object') {
      return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { text, target_lang } = body as { text?: unknown; target_lang?: unknown }

    const safeText = sanitizeText(text)
    if (!safeText) {
      return new Response(JSON.stringify({ error: 'Text is required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const rawTargetLang = sanitizeInput(target_lang, 50)
    if (!rawTargetLang) {
      return new Response(JSON.stringify({ error: 'target_lang is required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const deeplTarget = normalizeTargetLang(rawTargetLang)

    // Check if DeepL supports this language
    if (!deeplTarget) {
      // Unsupported language — return original text with explanation
      return new Response(JSON.stringify({
        translation: safeText,
        translated_text: safeText,
        detected_source_lang: 'unknown',
        target_lang: rawTargetLang,
        chars: safeText.length,
        note: `Translation to ${rawTargetLang} is not yet supported. Showing original text.`,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const deeplApiKey = Deno.env.get('DEEPL_API_KEY')
    if (!deeplApiKey) {
      console.error('DEEPL_API_KEY is not set')
      return new Response(JSON.stringify({
        error: 'Translation service not configured. Please set DEEPL_API_KEY in your Supabase project secrets.'
      }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Call DeepL API
    // Free tier uses https://api-free.deepl.com; paid tier uses https://api.deepl.com
    // We detect which to use based on the key format (free keys end with ":fx")
    const deeplHost = deeplApiKey.endsWith(':fx')
      ? 'https://api-free.deepl.com'
      : 'https://api.deepl.com'

    const params = new URLSearchParams()
    params.append('text', safeText)
    params.append('target_lang', deeplTarget)

    // FIX (audit H-9): add a 15s timeout via AbortController. Without this,
    // a slow DeepL response hangs the edge function until the platform
    // timeout. Every other external call in the codebase (ai-chat) has a
    // timeout; translate didn't.
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 15000)

    let deeplResponse: Response
    try {
      deeplResponse = await fetch(`${deeplHost}/v2/translate`, {
        method: 'POST',
        headers: {
          'Authorization': `DeepL-Auth-Key ${deeplApiKey}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: params.toString(),
        signal: controller.signal,
      })
      clearTimeout(timeoutId)
    } catch (fetchError) {
      clearTimeout(timeoutId)
      console.error('DeepL fetch error (timeout or network):', fetchError)
      return new Response(JSON.stringify({
        translation: safeText,
        translated_text: safeText,
        detected_source_lang: 'unknown',
        target_lang: deeplTarget,
        chars: safeText.length,
        note: 'Translation timed out. Showing original text.',
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (!deeplResponse.ok) {
      const errText = await deeplResponse.text()
      console.error('DeepL API error:', deeplResponse.status, errText)
      // Return the original text rather than failing — translation is non-critical
      return new Response(JSON.stringify({
        translation: safeText,
        translated_text: safeText,
        detected_source_lang: 'unknown',
        target_lang: deeplTarget,
        chars: safeText.length,
        note: 'Translation temporarily unavailable. Showing original text.',
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const deeplData = await deeplResponse.json()
    const translation = deeplData.translations?.[0]?.text ?? safeText
    const detectedSource = deeplData.translations?.[0]?.detected_source_language ?? 'unknown'

    return new Response(JSON.stringify({
      translation,
      translated_text: translation,  // backwards compat with client
      detected_source_lang: detectedSource,
      target_lang: deeplTarget,
      chars: safeText.length,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Translate function error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

// Local helper (defined at end to keep main logic readable)
function sanitizeInput(v: unknown, max: number): string {
  if (v == null) return ''
  let s = typeof v === 'string' ? v : JSON.stringify(v)
  s = s.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim()
  return s.slice(0, max)
}

class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://umncqfyzphvxtosddyae.supabase.co',
  );
  // Publishable API key (replaces the legacy anon key after the 2026-06-18
  // JWT rotation + legacy API key disablement). Safe to ship in the client
  // app — RLS is the gate, not the key.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_2w75vf7pUF_wlxUQive7aA_-SgHPvoR',
  );
}

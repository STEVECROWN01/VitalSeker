class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://umncqfyzphvxtosddyae.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVtbmNxZnl6cGh2eHRvc2RkeWFlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyMjI3ODYsImV4cCI6MjA5NTc5ODc4Nn0.OFFMBp7ZNkYaKxl4au0kTe5iq6l0cGeC49A1ksJzNLQ',
  );
}

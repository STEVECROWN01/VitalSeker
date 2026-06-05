class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://umncqfyzphvxtosddyae.supabase.co',
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVtbmNxZnl6cGh2eHRvc2RkeWFlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg4MjkyOTUsImV4cCI6MjA2NDQwNTI5NX0.4ZoE3w8bxPNvDHNnNlD-uJ0JGXz-1W1rSnY2O1tBnBM',
  );
}

/// Supabase configuration for OmniCore.
///
/// **Auth is strictly optional.** The app functions 100% offline without ever
/// prompting for login. To enable cloud sync, paste your project's URL and
/// anon key below (or provide them via `--dart-define`). When both are empty,
/// [isSupabaseConfigured] is `false` and the app boots in pure-local mode.
class SupabaseConfig {
  SupabaseConfig._();

  /// Replace with your Supabase project URL, or pass via
  /// `--dart-define=SUPABASE_URL=...`.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Replace with your Supabase anon public key, or pass via
  /// `--dart-define=SUPABASE_ANON_KEY=...`.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Google OAuth provider ID used by Supabase Auth.
  static const String googleProvider = 'google';

  /// True only when both credentials are present.
  static bool get isConfigured =>
      url.isNotEmpty && anonKey.isNotEmpty && url.startsWith('http');
}

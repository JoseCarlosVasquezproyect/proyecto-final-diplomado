class AppConfig {
  const AppConfig({
    required this.demoMode,
    required this.supabaseUrl,
    required this.supabaseKey,
  });

  final bool demoMode;
  final String supabaseUrl;
  final String supabaseKey;

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      demoMode: bool.fromEnvironment('DEMO_MODE', defaultValue: true),
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    );
  }

  bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseKey.trim().isNotEmpty;

  bool get useSupabase => !demoMode && hasSupabaseConfig;

  String get modeLabel => useSupabase ? 'SUPABASE' : 'DEMO';
}

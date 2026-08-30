class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.demoExamToken = '',
  });

  factory AppConfig.fromValues({
    required String url,
    required String publishableKey,
    String demoExamToken = '',
  }) => AppConfig(
        supabaseUrl: url.trim(),
        supabasePublishableKey: publishableKey.trim(),
        demoExamToken: demoExamToken.trim(),
      );

  factory AppConfig.fromEnvironment() => AppConfig.fromValues(
        url: const String.fromEnvironment('SUPABASE_URL'),
        publishableKey:
            const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
        demoExamToken: const String.fromEnvironment('DEMO_EXAM_TOKEN'),
      );

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String demoExamToken;

  bool get isConfigured =>
      Uri.tryParse(supabaseUrl)?.hasScheme == true &&
      supabasePublishableKey.isNotEmpty;

  bool get isStaging => supabaseUrl.contains('yyqeymyopawhaniyemqo');
}

import 'package:flutter_test/flutter_test.dart';
import 'package:marefat_student_demo/core/app_config.dart';

void main() {
  test('configuration rejects missing values', () {
    final config = AppConfig.fromValues(url: '', publishableKey: '');
    expect(config.isConfigured, isFalse);
  });

  test('configuration accepts staging values', () {
    final config = AppConfig.fromValues(
      url: 'https://yyqeymyopawhaniyemqo.supabase.co',
      publishableKey: 'sb_publishable_demo',
    );
    expect(config.isConfigured, isTrue);
    expect(config.isStaging, isTrue);
  });
}

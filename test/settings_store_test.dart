import 'package:ai_subtitle_translator/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'settings are ready with endpoint and model even when api key is empty',
    () {
      const settings = TranslationSettings(
        endpoint: 'http://localhost:8080/v1/chat/completions',
        apiKey: '',
        model: 'local-model',
      );

      expect(settings.isReady, isTrue);
    },
  );

  test('settings are not ready without endpoint or model', () {
    const missingEndpoint = TranslationSettings(
      endpoint: '',
      apiKey: '',
      model: 'local-model',
    );
    const missingModel = TranslationSettings(
      endpoint: 'http://localhost:8080/v1/chat/completions',
      apiKey: '',
      model: '',
    );

    expect(missingEndpoint.isReady, isFalse);
    expect(missingModel.isReady, isFalse);
  });
}

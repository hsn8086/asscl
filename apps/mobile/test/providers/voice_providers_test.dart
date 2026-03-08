import 'package:flutter_test/flutter_test.dart';
import 'package:asscl/providers/ai_providers.dart';

void main() {
  group('extractBaseUrl', () {
    test('strips /chat/completions from OpenAI URL', () {
      expect(
        extractBaseUrl('https://api.openai.com/v1/chat/completions'),
        'https://api.openai.com/v1',
      );
    });

    test('strips /audio/transcriptions', () {
      expect(
        extractBaseUrl('https://api.openai.com/v1/audio/transcriptions'),
        'https://api.openai.com/v1',
      );
    });

    test('returns URL as-is if already a base URL', () {
      expect(
        extractBaseUrl('https://api.openai.com/v1'),
        'https://api.openai.com/v1',
      );
    });

    test('strips trailing slash', () {
      expect(
        extractBaseUrl('https://api.openai.com/v1/'),
        'https://api.openai.com/v1',
      );
    });

    test('handles custom proxy URLs', () {
      expect(
        extractBaseUrl('https://my-proxy.com/v1/chat/completions'),
        'https://my-proxy.com/v1',
      );
    });
  });
}

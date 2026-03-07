import 'package:flutter_test/flutter_test.dart';
import 'package:asscl/providers/voice_providers.dart';

void main() {
  group('deriveTranscriptionUrl', () {
    test('derives from OpenAI chat completions URL', () {
      expect(
        deriveTranscriptionUrl('https://api.openai.com/v1/chat/completions'),
        'https://api.openai.com/v1/audio/transcriptions',
      );
    });

    test('derives from custom endpoint with /v1/ path', () {
      expect(
        deriveTranscriptionUrl('https://my-proxy.com/v1/chat/completions'),
        'https://my-proxy.com/v1/audio/transcriptions',
      );
    });

    test('handles URL with extra path segments', () {
      expect(
        deriveTranscriptionUrl('https://api.example.com/api/v1/chat/completions'),
        'https://api.example.com/api/v1/audio/transcriptions',
      );
    });

    test('returns original URL if no /v1/ found', () {
      expect(
        deriveTranscriptionUrl('https://api.example.com/chat/completions'),
        'https://api.example.com/chat/completions',
      );
    });

    test('handles URL ending with /v1/', () {
      expect(
        deriveTranscriptionUrl('https://api.example.com/v1/'),
        'https://api.example.com/v1/audio/transcriptions',
      );
    });
  });
}

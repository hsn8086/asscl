import 'dart:convert';
import 'dart:io';

import 'package:data/data.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('SttServiceImpl', () {
    test('sends correct multipart request and parses response', () async {
      String? capturedContentType;
      String? capturedAuth;
      String? capturedBody;

      final client = MockClient((request) async {
        capturedContentType = request.headers['content-type'];
        capturedAuth = request.headers['Authorization'];
        capturedBody = request.body;

        expect(request.method, 'POST');
        expect(request.url.toString(),
            'https://api.openai.com/v1/audio/transcriptions');

        return http.Response(
          jsonEncode({'text': '你好世界'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final stt = SttServiceImpl(
        endpoint: 'https://api.openai.com/v1/audio/transcriptions',
        apiKey: 'sk-test-key',
        model: 'whisper-1',
        client: client,
      );

      // Create a temporary file for testing
      final tempDir = await Directory.systemTemp.createTemp('stt_test_');
      final tempFile = File('${tempDir.path}/test.m4a');
      await tempFile.writeAsBytes([0, 1, 2, 3]); // dummy content

      try {
        final result = await stt.transcribe(filePath: tempFile.path);
        expect(result, '你好世界');
        expect(capturedAuth, 'Bearer sk-test-key');
        expect(capturedContentType, contains('multipart/form-data'));
        expect(capturedBody, contains('whisper-1'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('sends language field when provided', () async {
      String? capturedBody;

      final client = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({'text': 'hello'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final stt = SttServiceImpl(
        endpoint: 'https://api.openai.com/v1/audio/transcriptions',
        apiKey: 'sk-test',
        model: 'whisper-1',
        client: client,
      );

      final tempDir = await Directory.systemTemp.createTemp('stt_test_');
      final tempFile = File('${tempDir.path}/test.m4a');
      await tempFile.writeAsBytes([0, 1, 2, 3]);

      try {
        await stt.transcribe(filePath: tempFile.path, language: 'zh');
        expect(capturedBody, contains('zh'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('throws on non-200 response', () async {
      final client = MockClient((request) async {
        return http.Response('{"error": "bad request"}', 400);
      });

      final stt = SttServiceImpl(
        endpoint: 'https://api.openai.com/v1/audio/transcriptions',
        apiKey: 'sk-test',
        model: 'whisper-1',
        client: client,
      );

      final tempDir = await Directory.systemTemp.createTemp('stt_test_');
      final tempFile = File('${tempDir.path}/test.m4a');
      await tempFile.writeAsBytes([0, 1, 2, 3]);

      try {
        expect(
          () => stt.transcribe(filePath: tempFile.path),
          throwsA(isA<Exception>()),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('throws on empty text response', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'text': ''}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final stt = SttServiceImpl(
        endpoint: 'https://api.openai.com/v1/audio/transcriptions',
        apiKey: 'sk-test',
        model: 'whisper-1',
        client: client,
      );

      final tempDir = await Directory.systemTemp.createTemp('stt_test_');
      final tempFile = File('${tempDir.path}/test.m4a');
      await tempFile.writeAsBytes([0, 1, 2, 3]);

      try {
        expect(
          () => stt.transcribe(filePath: tempFile.path),
          throwsA(isA<Exception>()),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}

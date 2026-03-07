import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;

class SttServiceImpl implements SttService {
  final String endpoint;
  final String apiKey;
  final String model;
  final http.Client _client;

  SttServiceImpl({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    required http.Client client,
  }) : _client = client;

  @override
  Future<String> transcribe({
    required String filePath,
    String? language,
  }) async {
    final uri = Uri.parse(endpoint);
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['model'] = model;
    if (language != null) {
      request.fields['language'] = language;
    }

    request.files.add(
      await http.MultipartFile.fromPath('file', filePath),
    );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('STT 请求失败 (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = json['text'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('STT 返回空结果');
    }
    return text;
  }
}

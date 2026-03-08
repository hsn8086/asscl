import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// WebDAV connection configuration.
class WebDavConfig {
  final String url;
  final String username;
  final String password;
  final String remotePath;

  const WebDavConfig({
    required this.url,
    required this.username,
    required this.password,
    this.remotePath = '/asscl',
  });

  bool get isValid => url.isNotEmpty && username.isNotEmpty;

  String get _basicAuth =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  Map<String, String> get _headers => {
        'Authorization': _basicAuth,
      };

  /// Full URL for the backup file.
  Uri get backupUri {
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final path =
        remotePath.startsWith('/') ? remotePath : '/$remotePath';
    return Uri.parse('$base$path/asscl_backup.json');
  }

  /// Directory URL (for MKCOL).
  Uri get directoryUri {
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final path =
        remotePath.startsWith('/') ? remotePath : '/$remotePath';
    return Uri.parse('$base$path/');
  }
}

/// Minimal WebDAV client using standard HTTP methods.
class WebDavService {
  final http.Client _client;
  final WebDavConfig config;

  WebDavService({required this.config, http.Client? client})
      : _client = client ?? http.Client();

  /// Upload data to the backup file via PUT.
  Future<void> upload(Uint8List data) async {
    // Ensure directory exists (ignore errors — some servers auto-create).
    try {
      await _client.send(http.Request('MKCOL', config.directoryUri)
        ..headers.addAll(config._headers));
    } catch (_) {}

    final response = await _client.put(
      config.backupUri,
      headers: {
        ...config._headers,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: data,
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw WebDavException('上传失败: HTTP ${response.statusCode}');
    }
  }

  /// Download the backup file via GET.
  Future<Uint8List> download() async {
    final response = await _client.get(
      config.backupUri,
      headers: config._headers,
    );

    if (response.statusCode != 200) {
      throw WebDavException('下载失败: HTTP ${response.statusCode}');
    }

    return response.bodyBytes;
  }

  /// Test the connection by sending an OPTIONS request.
  Future<bool> testConnection() async {
    try {
      final request = http.Request('OPTIONS', config.directoryUri)
        ..headers.addAll(config._headers);
      final streamed = await _client.send(request);
      final status = streamed.statusCode;
      // Accept common success codes.
      return status >= 200 && status < 400;
    } catch (_) {
      return false;
    }
  }
}

class WebDavException implements Exception {
  final String message;
  const WebDavException(this.message);

  @override
  String toString() => 'WebDavException: $message';
}

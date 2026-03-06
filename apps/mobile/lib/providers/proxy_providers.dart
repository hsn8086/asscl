import 'dart:io';

import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'database_provider.dart';

/// Network proxy configuration.
class ProxyConfig {
  final bool enabled;
  final String host;
  final int port;

  const ProxyConfig({
    this.enabled = false,
    this.host = '',
    this.port = 0,
  });

  bool get isValid => enabled && host.isNotEmpty && port > 0;

  String get proxyUrl => 'PROXY $host:$port';
}

/// Reads proxy settings from the database.
final proxyConfigProvider = FutureProvider<ProxyConfig>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);
  final enabled = await dao.getValue('proxyEnabled');
  if (enabled != 'true') return const ProxyConfig();

  final host = await dao.getValue('proxyHost');
  final port = await dao.getValue('proxyPort');

  return ProxyConfig(
    enabled: true,
    host: host ?? '',
    port: int.tryParse(port ?? '') ?? 0,
  );
});

/// Provides an [http.Client] that respects proxy settings.
/// All network-calling services should use this instead of creating
/// their own clients.
final httpClientProvider = Provider<http.Client>((ref) {
  final proxy = ref.watch(proxyConfigProvider).valueOrNull;
  if (proxy != null && proxy.isValid) {
    final ioClient = HttpClient()
      ..findProxy = (uri) => proxy.proxyUrl;
    return IOClient(ioClient);
  }
  return http.Client();
});

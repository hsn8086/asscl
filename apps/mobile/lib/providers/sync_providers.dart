import 'package:data/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';
import 'proxy_providers.dart';

/// Reads WebDAV configuration from the database.
final webDavConfigProvider = FutureProvider<WebDavConfig>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final dao = SettingsDao(db);
  final url = await dao.getValue('webdavUrl');
  final username = await dao.getValue('webdavUsername');
  final password = await dao.getValue('webdavPassword');
  final remotePath = await dao.getValue('webdavRemotePath');

  return WebDavConfig(
    url: url ?? '',
    username: username ?? '',
    password: password ?? '',
    remotePath: remotePath ?? '/asscl',
  );
});

/// Provides a [SyncService] wired up with the current WebDAV config.
final syncServiceProvider = Provider<SyncService?>((ref) {
  final config = ref.watch(webDavConfigProvider).valueOrNull;
  if (config == null || !config.isValid) return null;

  final client = ref.watch(httpClientProvider);
  final db = ref.watch(appDatabaseProvider);
  final webdav = WebDavService(config: config, client: client);
  return SyncService(db: db, webdav: webdav);
});

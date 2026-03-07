import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'database_provider.dart';
import 'proxy_providers.dart';

/// 天气功能是否启用
final weatherEnabledProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final val = await SettingsDao(db).getValue('weatherEnabled');
  return val == 'true';
});

/// WeatherService 实例
final weatherServiceProvider = Provider<WeatherService>((ref) {
  final client = ref.watch(httpClientProvider);
  return WeatherServiceImpl(client: client);
});

/// 获取当前上下文（时间 + 位置 + 天气），供 AI 工具调用
Future<String> fetchCurrentContext({
  required bool weatherEnabled,
  required WeatherService weatherService,
}) async {
  final now = DateTime.now();
  final timeFmt = DateFormat('yyyy-MM-dd HH:mm:ss (EEEE)', 'zh_CN');
  final timeStr = timeFmt.format(now);

  if (!weatherEnabled) {
    return '当前时间：$timeStr\n天气功能未开启，请在设置中启用。';
  }

  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return '当前时间：$timeStr\n无法获取位置：位置权限未授予。';
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );

    final weather = await weatherService
        .getWeather(position.latitude, position.longitude);

    final buf = StringBuffer()
      ..writeln('当前时间：$timeStr')
      ..writeln('位置：${weather.location} (${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)})')
      ..writeln('天气：${weather.condition}')
      ..writeln('温度：${weather.tempC}°C（体感 ${weather.feelsLikeC}°C）')
      ..writeln('湿度：${weather.humidity}%')
      ..writeln('风速：${weather.windSpeedKmph} km/h ${weather.windDir}');

    if (weather.forecast.isNotEmpty) {
      buf.writeln('\n未来预报：');
      for (final f in weather.forecast) {
        final dateStr = DateFormat('MM-dd (E)', 'zh_CN').format(f.date);
        buf.writeln('  $dateStr: ${f.condition} ${f.minTempC}~${f.maxTempC}°C');
      }
    }

    return buf.toString();
  } catch (e) {
    return '当前时间：$timeStr\n获取天气信息失败：$e';
  }
}

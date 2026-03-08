import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;

/// 7Timer 天气服务实现（免费，无需 API Key，基于 NOAA GFS 模型）
class SevenTimerWeatherService implements WeatherService {
  final http.Client _client;

  SevenTimerWeatherService({required http.Client client}) : _client = client;

  @override
  Future<WeatherInfo> getWeather(double lat, double lon) async {
    // 并行请求 civil（3h 间隔详细数据）和 civillight（每日摘要）
    final civilUrl = Uri.parse(
      'https://www.7timer.info/bin/civil.php'
      '?lat=$lat&lon=$lon&output=json&unit=metric',
    );
    final lightUrl = Uri.parse(
      'https://www.7timer.info/bin/civillight.php'
      '?lat=$lat&lon=$lon&output=json&unit=metric',
    );

    final results = await Future.wait([
      _client.get(civilUrl),
      _client.get(lightUrl),
    ]);

    if (results[0].statusCode != 200) {
      throw Exception('7Timer civil API 请求失败: ${results[0].statusCode}');
    }
    if (results[1].statusCode != 200) {
      throw Exception('7Timer civillight API 请求失败: ${results[1].statusCode}');
    }

    final civilJson =
        jsonDecode(results[0].body) as Map<String, dynamic>;
    final lightJson =
        jsonDecode(results[1].body) as Map<String, dynamic>;

    return _parse(civilJson, lightJson, lat, lon);
  }

  WeatherInfo _parse(
    Map<String, dynamic> civil,
    Map<String, dynamic> light,
    double lat,
    double lon,
  ) {
    // 取第一个 timepoint 作为"当前"
    final series = civil['dataseries'] as List<dynamic>? ?? [];
    if (series.isEmpty) {
      throw Exception('7Timer 返回数据为空');
    }
    final current = series.first as Map<String, dynamic>;

    final tempC = (current['temp2m'] as num?)?.toDouble() ?? 0;
    final humidity = _parseHumidity(current['rh2m']);
    final wind = current['wind10m'] as Map<String, dynamic>? ?? {};
    final windSpeed = _windSpeedToKmph((wind['speed'] as num?)?.toInt() ?? 1);
    final windDir = wind['direction']?.toString() ?? '';
    final weather = current['weather']?.toString() ?? '';
    final condition = _weatherToCondition(weather);

    // civillight 提供每日预报
    final lightSeries = light['dataseries'] as List<dynamic>? ?? [];
    final forecast = <WeatherForecast>[];
    for (final day in lightSeries) {
      final d = day as Map<String, dynamic>;
      final dateStr = d['date']?.toString() ?? '';
      final temp2m = d['temp2m'] as Map<String, dynamic>? ?? {};
      forecast.add(WeatherForecast(
        date: _parseDate(dateStr),
        maxTempC: (temp2m['max'] as num?)?.toDouble() ?? 0,
        minTempC: (temp2m['min'] as num?)?.toDouble() ?? 0,
        condition: _weatherToCondition(d['weather']?.toString() ?? ''),
      ));
    }

    return WeatherInfo(
      location: '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}',
      tempC: tempC,
      feelsLikeC: tempC, // 7Timer 不提供体感温度
      condition: condition,
      humidity: humidity,
      windSpeedKmph: windSpeed,
      windDir: windDir,
      forecast: forecast,
    );
  }

  /// 7Timer rh2m 格式为百分比字符串或数字
  static int _parseHumidity(dynamic rh) {
    if (rh is int) return rh;
    final s = rh?.toString() ?? '';
    return int.tryParse(s.replaceAll('%', '')) ?? 0;
  }

  /// 7Timer 风速等级 (1-8) → 近似 km/h
  static double _windSpeedToKmph(int level) {
    // 1: <0.3m/s ≈ 1 km/h
    // 2: 0.3-3.4 ≈ 7 km/h
    // 3: 3.4-8.0 ≈ 20 km/h
    // 4: 8.0-10.8 ≈ 34 km/h
    // 5: 10.8-17.2 ≈ 50 km/h
    // 6: 17.2-24.5 ≈ 75 km/h
    // 7: 24.5-32.6 ≈ 103 km/h
    // 8: >32.6 ≈ 120 km/h
    const speeds = [1.0, 7.0, 20.0, 34.0, 50.0, 75.0, 103.0, 120.0];
    if (level < 1) return 0;
    if (level > speeds.length) return speeds.last;
    return speeds[level - 1];
  }

  /// 解析 7Timer 日期格式 (yyyyMMdd)
  static DateTime _parseDate(String s) {
    if (s.length != 8) return DateTime.now();
    final y = int.tryParse(s.substring(0, 4)) ?? 2026;
    final m = int.tryParse(s.substring(4, 6)) ?? 1;
    final d = int.tryParse(s.substring(6, 8)) ?? 1;
    return DateTime(y, m, d);
  }

  /// 7Timer weather 字段 → 中文天气描述
  static String _weatherToCondition(String weather) {
    final w = weather.toLowerCase();
    if (w.contains('clear')) return '晴';
    if (w.contains('pcloudy')) return '少云';
    if (w.contains('mcloudy')) return '多云';
    if (w.contains('cloudy')) return '阴天';
    if (w.contains('humid')) return '潮湿';
    if (w.contains('lightrain')) return '小雨';
    if (w.contains('oshower')) return '偶有阵雨';
    if (w.contains('ishower')) return '间歇阵雨';
    if (w.contains('rain')) return '雨';
    if (w.contains('lightsnow')) return '小雪';
    if (w.contains('snow')) return '雪';
    if (w.contains('ts')) return '雷暴';
    if (w.contains('fog')) return '雾';
    if (w.contains('windy')) return '大风';
    return weather;
  }
}

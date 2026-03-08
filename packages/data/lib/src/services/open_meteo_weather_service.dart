import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;

/// Open-Meteo 天气服务实现（免费，无需 API Key）
class OpenMeteoWeatherService implements WeatherService {
  final http.Client _client;

  OpenMeteoWeatherService({required http.Client client}) : _client = client;

  @override
  Future<WeatherInfo> getWeather(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,apparent_temperature'
      ',weather_code,wind_speed_10m,wind_direction_10m'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min'
      '&timezone=auto&forecast_days=3',
    );

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception('Open-Meteo API 请求失败: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parse(json, lat, lon);
  }

  WeatherInfo _parse(Map<String, dynamic> json, double lat, double lon) {
    final current = json['current'] as Map<String, dynamic>;

    final tempC = (current['temperature_2m'] as num?)?.toDouble() ?? 0;
    final feelsLikeC =
        (current['apparent_temperature'] as num?)?.toDouble() ?? 0;
    final humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 0;
    final windSpeed =
        (current['wind_speed_10m'] as num?)?.toDouble() ?? 0;
    final windDeg =
        (current['wind_direction_10m'] as num?)?.toDouble() ?? 0;
    final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;

    final daily = json['daily'] as Map<String, dynamic>?;
    final forecast = <WeatherForecast>[];
    if (daily != null) {
      final times = daily['time'] as List<dynamic>? ?? [];
      final codes = daily['weather_code'] as List<dynamic>? ?? [];
      final maxTemps = daily['temperature_2m_max'] as List<dynamic>? ?? [];
      final minTemps = daily['temperature_2m_min'] as List<dynamic>? ?? [];
      for (var i = 0; i < times.length; i++) {
        forecast.add(WeatherForecast(
          date: DateTime.tryParse(times[i].toString()) ?? DateTime.now(),
          maxTempC: (maxTemps.length > i ? maxTemps[i] as num : 0).toDouble(),
          minTempC: (minTemps.length > i ? minTemps[i] as num : 0).toDouble(),
          condition: _wmoToCondition(
              codes.length > i ? (codes[i] as num).toInt() : 0),
        ));
      }
    }

    return WeatherInfo(
      location: '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}',
      tempC: tempC,
      feelsLikeC: feelsLikeC,
      condition: _wmoToCondition(weatherCode),
      humidity: humidity,
      windSpeedKmph: windSpeed,
      windDir: _degreeToDirection(windDeg),
      forecast: forecast,
    );
  }

  static String _degreeToDirection(double deg) {
    const directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
    ];
    final index = ((deg + 11.25) % 360 / 22.5).floor();
    return directions[index];
  }

  static String _wmoToCondition(int code) {
    return switch (code) {
      0 => '晴',
      1 => '大部晴朗',
      2 => '多云',
      3 => '阴天',
      45 || 48 => '雾',
      51 => '小毛毛雨',
      53 => '毛毛雨',
      55 => '大毛毛雨',
      56 || 57 => '冻毛毛雨',
      61 => '小雨',
      63 => '中雨',
      65 => '大雨',
      66 || 67 => '冻雨',
      71 => '小雪',
      73 => '中雪',
      75 => '大雪',
      77 => '雪粒',
      80 => '小阵雨',
      81 => '中阵雨',
      82 => '大阵雨',
      85 => '小阵雪',
      86 => '大阵雪',
      95 => '雷暴',
      96 || 99 => '雷暴伴冰雹',
      _ => '未知',
    };
  }
}

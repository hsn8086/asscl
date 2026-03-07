import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;

class WeatherServiceImpl implements WeatherService {
  final http.Client _client;

  WeatherServiceImpl({required http.Client client}) : _client = client;

  @override
  Future<WeatherInfo> getWeather(double lat, double lon) async {
    final url = Uri.parse(
      'https://wttr.in/$lat,$lon?format=j1&lang=zh',
    );

    final response = await _client.get(url, headers: {
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('天气 API 请求失败: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseWeatherJson(json);
  }

  WeatherInfo _parseWeatherJson(Map<String, dynamic> json) {
    final current = (json['current_condition'] as List).first
        as Map<String, dynamic>;

    final location = _extractLocation(json);
    final tempC = double.tryParse(current['temp_C']?.toString() ?? '') ?? 0;
    final feelsLikeC =
        double.tryParse(current['FeelsLikeC']?.toString() ?? '') ?? 0;
    final humidity =
        int.tryParse(current['humidity']?.toString() ?? '') ?? 0;
    final windSpeedKmph =
        double.tryParse(current['windspeedKmph']?.toString() ?? '') ?? 0;
    final windDir = current['winddir16Point']?.toString() ?? '';

    // 中文天气描述
    final descList = current['lang_zh'] as List<dynamic>?;
    final condition = descList != null && descList.isNotEmpty
        ? (descList.first as Map<String, dynamic>)['value']?.toString() ?? ''
        : current['weatherDesc'] is List
            ? ((current['weatherDesc'] as List).first
                    as Map<String, dynamic>)['value']
                ?.toString() ??
                ''
            : '';

    // 未来预报
    final weatherList = json['weather'] as List<dynamic>? ?? [];
    final forecast = weatherList.map((day) {
      final d = day as Map<String, dynamic>;
      return WeatherForecast(
        date: DateTime.tryParse(d['date']?.toString() ?? '') ?? DateTime.now(),
        maxTempC: double.tryParse(d['maxtempC']?.toString() ?? '') ?? 0,
        minTempC: double.tryParse(d['mintempC']?.toString() ?? '') ?? 0,
        condition: _extractDayCondition(d),
      );
    }).toList();

    return WeatherInfo(
      location: location,
      tempC: tempC,
      feelsLikeC: feelsLikeC,
      condition: condition,
      humidity: humidity,
      windSpeedKmph: windSpeedKmph,
      windDir: windDir,
      forecast: forecast,
    );
  }

  String _extractLocation(Map<String, dynamic> json) {
    final area = json['nearest_area'] as List<dynamic>?;
    if (area == null || area.isEmpty) return '';
    final first = area.first as Map<String, dynamic>;
    final areaName = first['areaName'] as List<dynamic>?;
    if (areaName != null && areaName.isNotEmpty) {
      return (areaName.first as Map<String, dynamic>)['value']?.toString() ??
          '';
    }
    return '';
  }

  String _extractDayCondition(Map<String, dynamic> day) {
    final hourly = day['hourly'] as List<dynamic>?;
    if (hourly == null || hourly.isEmpty) return '';
    // Use noon (index 4 = 12:00) for representative condition
    final noon = hourly.length > 4
        ? hourly[4] as Map<String, dynamic>
        : hourly.first as Map<String, dynamic>;
    final descList = noon['lang_zh'] as List<dynamic>?;
    if (descList != null && descList.isNotEmpty) {
      return (descList.first as Map<String, dynamic>)['value']?.toString() ??
          '';
    }
    return '';
  }
}

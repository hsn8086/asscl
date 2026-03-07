/// 天气数据
class WeatherInfo {
  final String location;
  final double tempC;
  final double feelsLikeC;
  final String condition;
  final int humidity;
  final double windSpeedKmph;
  final String windDir;
  final List<WeatherForecast> forecast;

  const WeatherInfo({
    required this.location,
    required this.tempC,
    required this.feelsLikeC,
    required this.condition,
    required this.humidity,
    required this.windSpeedKmph,
    required this.windDir,
    this.forecast = const [],
  });
}

/// 天气预报（未来几天）
class WeatherForecast {
  final DateTime date;
  final double maxTempC;
  final double minTempC;
  final String condition;

  const WeatherForecast({
    required this.date,
    required this.maxTempC,
    required this.minTempC,
    required this.condition,
  });
}

/// 天气服务接口
abstract interface class WeatherService {
  Future<WeatherInfo> getWeather(double lat, double lon);
}

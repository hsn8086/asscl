import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/database_provider.dart';
import '../../../providers/weather_providers.dart';

class WeatherAlertCard extends ConsumerStatefulWidget {
  const WeatherAlertCard({super.key});

  @override
  ConsumerState<WeatherAlertCard> createState() => _WeatherAlertCardState();
}

class _WeatherAlertCardState extends ConsumerState<WeatherAlertCard> {
  bool _dismissed = false;
  bool _alreadyShownToday = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyShown();
  }

  Future<void> _checkAlreadyShown() async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final lastDate = await dao.getValue('weatherAlertLastDate');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (lastDate == today) {
      if (mounted) setState(() => _alreadyShownToday = true);
    }
  }

  Future<void> _dismiss() async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await dao.setValue('weatherAlertLastDate', today);
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _alreadyShownToday) return const SizedBox.shrink();

    final weatherAsync = ref.watch(currentWeatherProvider);
    final configAsync = ref.watch(weatherAlertConfigProvider);

    return weatherAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (weather) {
        if (weather == null) return const SizedBox.shrink();

        final config = configAsync.valueOrNull ?? const WeatherAlertConfig();
        final alerts = _matchAlerts(weather, config);
        if (alerts.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  _weatherIcon(weather.condition),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${weather.tempC.round()}°C · ${weather.condition}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alerts.join('；'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _dismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _matchAlerts(WeatherInfo weather, WeatherAlertConfig config) {
    final alerts = <String>[];
    final cond = weather.condition.toLowerCase();

    if (config.alertRain && _isRainy(cond)) {
      alerts.add('今日有雨，记得带伞');
    }
    if (config.alertSnow && _isSnowy(cond)) {
      alerts.add('今日有雪，注意保暖');
    }
    if (config.alertHighTemp && weather.tempC >= config.highTempThreshold) {
      alerts.add('今日高温 ${weather.tempC.round()}°C，注意防暑');
    }
    if (config.alertLowTemp && weather.tempC <= config.lowTempThreshold) {
      alerts.add('今日低温 ${weather.tempC.round()}°C，注意保暖');
    }
    return alerts;
  }

  bool _isRainy(String cond) =>
      cond.contains('雨') ||
      cond.contains('rain') ||
      cond.contains('drizzle') ||
      cond.contains('shower');

  bool _isSnowy(String cond) =>
      cond.contains('雪') ||
      cond.contains('snow') ||
      cond.contains('sleet') ||
      cond.contains('blizzard');

  Widget _weatherIcon(String condition) {
    final cond = condition.toLowerCase();
    IconData icon;
    if (_isRainy(cond)) {
      icon = Icons.umbrella;
    } else if (_isSnowy(cond)) {
      icon = Icons.ac_unit;
    } else if (cond.contains('cloud') || cond.contains('阴') || cond.contains('多云')) {
      icon = Icons.cloud;
    } else if (cond.contains('sun') || cond.contains('晴') || cond.contains('clear')) {
      icon = Icons.wb_sunny;
    } else {
      icon = Icons.thermostat;
    }
    return Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary);
  }
}

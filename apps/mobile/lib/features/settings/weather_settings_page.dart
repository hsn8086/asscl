import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/database_provider.dart';
import '../../providers/weather_providers.dart';

class WeatherSettingsPage extends ConsumerStatefulWidget {
  const WeatherSettingsPage({super.key});

  @override
  ConsumerState<WeatherSettingsPage> createState() =>
      _WeatherSettingsPageState();
}

class _WeatherSettingsPageState extends ConsumerState<WeatherSettingsPage> {
  bool _weatherEnabled = false;
  String _weatherSource = 'wttr';
  bool _alertRain = true;
  bool _alertSnow = true;
  bool _alertHighTemp = true;
  double _highTempThreshold = 35;
  bool _alertLowTemp = true;
  double _lowTempThreshold = 0;
  bool _isLoaded = false;

  Future<void> _loadSettings() async {
    if (_isLoaded) return;
    _isLoaded = true;
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final enabled = await dao.getValue('weatherEnabled');
    final source = await dao.getValue('weatherSource');
    final rain = await dao.getValue('weatherAlertRain');
    final snow = await dao.getValue('weatherAlertSnow');
    final highTemp = await dao.getValue('weatherAlertHighTemp');
    final highThreshold = await dao.getValue('weatherAlertHighTempThreshold');
    final lowTemp = await dao.getValue('weatherAlertLowTemp');
    final lowThreshold = await dao.getValue('weatherAlertLowTempThreshold');
    if (mounted) {
      setState(() {
        _weatherEnabled = enabled == 'true';
        _weatherSource = source ?? 'wttr';
        _alertRain = rain != 'false';
        _alertSnow = snow != 'false';
        _alertHighTemp = highTemp != 'false';
        _highTempThreshold = double.tryParse(highThreshold ?? '') ?? 35;
        _alertLowTemp = lowTemp != 'false';
        _lowTempThreshold = double.tryParse(lowThreshold ?? '') ?? 0;
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要位置权限才能获取天气信息')),
          );
        }
        return;
      }
    }
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    await dao.setValue('weatherEnabled', value.toString());
    ref.invalidate(weatherEnabledProvider);
    setState(() => _weatherEnabled = value);
  }

  Future<void> _setSource(String? value) async {
    if (value == null) return;
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    await dao.setValue('weatherSource', value);
    ref.invalidate(weatherSourceProvider);
    ref.invalidate(weatherServiceProvider);
    ref.invalidate(currentWeatherProvider);
    setState(() => _weatherSource = value);
  }

  Future<void> _toggleAlert(
      String key, bool value, void Function(bool) setter) async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    await dao.setValue(key, value.toString());
    ref.invalidate(weatherAlertConfigProvider);
    setState(() => setter(value));
  }

  Future<void> _setThreshold(
      String key, double value, void Function(double) setter) async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    await dao.setValue(key, value.toString());
    ref.invalidate(weatherAlertConfigProvider);
    setState(() => setter(value));
  }

  @override
  Widget build(BuildContext context) {
    _loadSettings();

    return Scaffold(
      appBar: AppBar(title: const Text('天气提醒')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              secondary: const Icon(Icons.cloud),
              title: const Text('开启天气提醒'),
              subtitle: const Text('开屏时根据天气条件弹出提醒卡片'),
              value: _weatherEnabled,
              onChanged: _toggleEnabled,
            ),
          ),
          if (_weatherEnabled) ...[
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    leading: Icon(Icons.dns),
                    title: Text('数据源'),
                  ),
                  RadioListTile<String>(
                    title: const Text('wttr.in'),
                    subtitle: const Text('默认，中文天气描述'),
                    value: 'wttr',
                    groupValue: _weatherSource,
                    onChanged: _setSource,
                  ),
                  RadioListTile<String>(
                    title: const Text('Open-Meteo'),
                    subtitle: const Text('高精度，更新频繁'),
                    value: 'openmeteo',
                    groupValue: _weatherSource,
                    onChanged: _setSource,
                  ),
                  RadioListTile<String>(
                    title: const Text('7Timer'),
                    subtitle: const Text('NOAA GFS 模型'),
                    value: '7timer',
                    groupValue: _weatherSource,
                    onChanged: _setSource,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.water_drop),
                    title: const Text('下雨提醒'),
                    value: _alertRain,
                    onChanged: (v) => _toggleAlert(
                      'weatherAlertRain', v, (b) => _alertRain = b,
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.ac_unit),
                    title: const Text('下雪提醒'),
                    value: _alertSnow,
                    onChanged: (v) => _toggleAlert(
                      'weatherAlertSnow', v, (b) => _alertSnow = b,
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.thermostat),
                    title: const Text('高温提醒'),
                    subtitle: Text('≥ ${_highTempThreshold.round()}°C'),
                    value: _alertHighTemp,
                    onChanged: (v) => _toggleAlert(
                      'weatherAlertHighTemp', v, (b) => _alertHighTemp = b,
                    ),
                  ),
                  if (_alertHighTemp)
                    ListTile(
                      leading: const SizedBox(width: 24),
                      title: Slider(
                        value: _highTempThreshold,
                        min: 30,
                        max: 45,
                        divisions: 15,
                        label: '${_highTempThreshold.round()}°C',
                        onChanged: (v) =>
                            setState(() => _highTempThreshold = v),
                        onChangeEnd: (v) => _setThreshold(
                          'weatherAlertHighTempThreshold', v,
                          (d) => _highTempThreshold = d,
                        ),
                      ),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [Text('30°C'), Text('45°C')],
                      ),
                    ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(Icons.severe_cold),
                    title: const Text('低温提醒'),
                    subtitle: Text('≤ ${_lowTempThreshold.round()}°C'),
                    value: _alertLowTemp,
                    onChanged: (v) => _toggleAlert(
                      'weatherAlertLowTemp', v, (b) => _alertLowTemp = b,
                    ),
                  ),
                  if (_alertLowTemp)
                    ListTile(
                      leading: const SizedBox(width: 24),
                      title: Slider(
                        value: _lowTempThreshold,
                        min: -10,
                        max: 10,
                        divisions: 20,
                        label: '${_lowTempThreshold.round()}°C',
                        onChanged: (v) =>
                            setState(() => _lowTempThreshold = v),
                        onChangeEnd: (v) => _setThreshold(
                          'weatherAlertLowTempThreshold', v,
                          (d) => _lowTempThreshold = d,
                        ),
                      ),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [Text('-10°C'), Text('10°C')],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

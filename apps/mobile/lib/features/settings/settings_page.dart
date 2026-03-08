import 'package:data/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../providers/database_provider.dart';
import '../../providers/ai_providers.dart';
import '../../providers/shortened_names_provider.dart';
import '../../providers/weather_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _enterToSend = false;
  bool _aiShortenNames = false;
  bool _weatherEnabled = false;
  bool _weatherAlertRain = true;
  bool _weatherAlertSnow = true;
  bool _weatherAlertHighTemp = true;
  double _weatherHighTempThreshold = 35;
  bool _weatherAlertLowTemp = true;
  double _weatherLowTempThreshold = 0;
  bool _isLoaded = false;

  Future<void> _loadSettings() async {
    if (_isLoaded) return;
    _isLoaded = true;
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    final enterToSend = await dao.getValue('enterToSend');
    final aiShortenNames = await dao.getValue('aiShortenNames');
    final weatherEnabled = await dao.getValue('weatherEnabled');
    final weatherAlertRain = await dao.getValue('weatherAlertRain');
    final weatherAlertSnow = await dao.getValue('weatherAlertSnow');
    final weatherAlertHighTemp = await dao.getValue('weatherAlertHighTemp');
    final weatherHighTempThreshold = await dao.getValue('weatherAlertHighTempThreshold');
    final weatherAlertLowTemp = await dao.getValue('weatherAlertLowTemp');
    final weatherLowTempThreshold = await dao.getValue('weatherAlertLowTempThreshold');
    if (mounted) {
      setState(() {
        _enterToSend = enterToSend == 'true';
        _aiShortenNames = aiShortenNames == 'true';
        _weatherEnabled = weatherEnabled == 'true';
        _weatherAlertRain = weatherAlertRain != 'false';
        _weatherAlertSnow = weatherAlertSnow != 'false';
        _weatherAlertHighTemp = weatherAlertHighTemp != 'false';
        _weatherHighTempThreshold = double.tryParse(weatherHighTempThreshold ?? '') ?? 35;
        _weatherAlertLowTemp = weatherAlertLowTemp != 'false';
        _weatherLowTempThreshold = double.tryParse(weatherLowTempThreshold ?? '') ?? 0;
      });
    }
  }

  Future<void> _toggleEnterToSend(bool value) async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    await dao.setValue('enterToSend', value.toString());
    ref.invalidate(enterToSendProvider);
    setState(() => _enterToSend = value);
  }

  Future<void> _toggleAiShortenNames(bool value) async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    await dao.setValue('aiShortenNames', value.toString());
    ref.invalidate(aiShortenNamesEnabledProvider);
    setState(() => _aiShortenNames = value);
  }

  Future<void> _toggleWeather(bool value) async {
    if (value) {
      // Request location permission
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

  Future<void> _toggleWeatherAlert(String key, bool value, void Function(bool) setter) async {
    final db = ref.read(appDatabaseProvider);
    final dao = SettingsDao(db);
    await dao.setValue(key, value.toString());
    ref.invalidate(weatherAlertConfigProvider);
    setState(() => setter(value));
  }

  Future<void> _setWeatherThreshold(String key, double value, void Function(double) setter) async {
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
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── 课程管理 ──
          _SectionHeader('课程管理'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.school,
                  title: '学期管理',
                  subtitle: '创建、切换学期，设置开学日期',
                  onTap: () => context.push('/settings/semesters'),
                ),
                const Divider(height: 1, indent: 56),
                _NavTile(
                  icon: Icons.schedule,
                  title: '节次时间',
                  subtitle: '上下课时间配置',
                  onTap: () => context.push('/settings/period-config'),
                ),
              ],
            ),
          ),

          // ── AI ──
          _SectionHeader('AI'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.key,
                  title: 'AI 配置',
                  subtitle: 'API 地址、密钥、模型',
                  onTap: () => context.push('/settings/ai-config'),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.keyboard_return),
                  title: const Text('回车发送'),
                  subtitle: Text(
                    _enterToSend
                        ? 'Enter 发送，Shift+Enter 换行'
                        : 'Enter 换行',
                  ),
                  value: _enterToSend,
                  onChanged: _toggleEnterToSend,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.short_text),
                  title: const Text('AI 缩短课程名'),
                  subtitle: const Text('在课表格子中显示 AI 简称'),
                  value: _aiShortenNames,
                  onChanged: _toggleAiShortenNames,
                ),
                if (_aiShortenNames) ...[
                  const Divider(height: 1, indent: 56),
                  _NavTile(
                    icon: Icons.text_fields,
                    title: '简称管理',
                    subtitle: '查看、编辑、重新生成',
                    onTap: () => context.push('/settings/shortened-names'),
                  ),
                ],
              ],
            ),
          ),

          // ── 集成 ──
          _SectionHeader('集成'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.cloud),
                  title: const Text('天气提醒'),
                  subtitle: const Text('开屏时根据天气条件弹出提醒卡片'),
                  value: _weatherEnabled,
                  onChanged: _toggleWeather,
                ),
                if (_weatherEnabled) ...[
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const SizedBox(width: 24),
                    title: const Text('下雨提醒'),
                    value: _weatherAlertRain,
                    onChanged: (v) => _toggleWeatherAlert(
                      'weatherAlertRain', v, (b) => _weatherAlertRain = b,
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const SizedBox(width: 24),
                    title: const Text('下雪提醒'),
                    value: _weatherAlertSnow,
                    onChanged: (v) => _toggleWeatherAlert(
                      'weatherAlertSnow', v, (b) => _weatherAlertSnow = b,
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const SizedBox(width: 24),
                    title: const Text('高温提醒'),
                    subtitle: Text('≥ ${_weatherHighTempThreshold.round()}°C'),
                    value: _weatherAlertHighTemp,
                    onChanged: (v) => _toggleWeatherAlert(
                      'weatherAlertHighTemp', v, (b) => _weatherAlertHighTemp = b,
                    ),
                  ),
                  if (_weatherAlertHighTemp)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          const Text('30°C'),
                          Expanded(
                            child: Slider(
                              value: _weatherHighTempThreshold,
                              min: 30,
                              max: 45,
                              divisions: 15,
                              label: '${_weatherHighTempThreshold.round()}°C',
                              onChanged: (v) => setState(() => _weatherHighTempThreshold = v),
                              onChangeEnd: (v) => _setWeatherThreshold(
                                'weatherAlertHighTempThreshold', v,
                                (d) => _weatherHighTempThreshold = d,
                              ),
                            ),
                          ),
                          const Text('45°C'),
                        ],
                      ),
                    ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const SizedBox(width: 24),
                    title: const Text('低温提醒'),
                    subtitle: Text('≤ ${_weatherLowTempThreshold.round()}°C'),
                    value: _weatherAlertLowTemp,
                    onChanged: (v) => _toggleWeatherAlert(
                      'weatherAlertLowTemp', v, (b) => _weatherAlertLowTemp = b,
                    ),
                  ),
                  if (_weatherAlertLowTemp)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          const Text('-10°C'),
                          Expanded(
                            child: Slider(
                              value: _weatherLowTempThreshold,
                              min: -10,
                              max: 10,
                              divisions: 20,
                              label: '${_weatherLowTempThreshold.round()}°C',
                              onChanged: (v) => setState(() => _weatherLowTempThreshold = v),
                              onChangeEnd: (v) => _setWeatherThreshold(
                                'weatherAlertLowTempThreshold', v,
                                (d) => _weatherLowTempThreshold = d,
                              ),
                            ),
                          ),
                          const Text('10°C'),
                        ],
                      ),
                    ),
                ],
                const Divider(height: 1, indent: 56),
                _NavTile(
                  icon: Icons.smart_toy,
                  title: 'Bot 集成',
                  subtitle: 'Telegram 通知转发、AI 助手',
                  onTap: () => context.push('/settings/bot'),
                ),
              ],
            ),
          ),

          // ── 网络 ──
          _SectionHeader('网络'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.vpn_lock,
                  title: '代理设置',
                  subtitle: 'HTTP 代理，用于 AI 和 Bot 请求',
                  onTap: () => context.push('/settings/proxy'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

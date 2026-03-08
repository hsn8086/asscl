import 'dart:async';
import 'dart:convert';

import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/ai_providers.dart';
import '../providers/bot_providers.dart';
import '../providers/course_providers.dart';
import '../providers/semester_providers.dart';
import '../providers/weather_providers.dart';

/// Relay service that bridges Telegram Bot messages with the AI Agent.
///
/// Polls for incoming Telegram messages, forwards them to [AiAgentService],
/// and streams AI responses back via Telegram's sendMessageDraft API.
class BotAgentRelay {
  final Ref _ref;
  StreamSubscription<BotIncomingMessage>? _pollSub;
  TelegramBotService? _botRef;
  bool _active = false;

  BotAgentRelay(this._ref);

  /// Read-only tools that auto-execute without user confirmation.
  static const _autoExecTools = {
    'query_courses',
    'query_semesters',
    'get_current_context',
    'get_time',
  };

  void start() {
    if (_active) return;
    _active = true;

    final config = _ref.read(tgConfigProvider).valueOrNull;
    if (config == null || !config.agentEnabled) return;

    final bot = _ref.read(telegramBotServiceProvider);
    if (bot == null) return;

    _botRef = bot;
    _pollSub = bot.pollMessages().listen(_handleMessage);
  }

  void stop() {
    _active = false;
    _pollSub?.cancel();
    _pollSub = null;
    _botRef?.stopPolling();
    _botRef = null;
  }

  Future<void> _handleMessage(BotIncomingMessage msg) async {
    final agent = _ref.read(aiAgentServiceProvider);
    final bot = _ref.read(telegramBotServiceProvider);
    final config = _ref.read(tgConfigProvider).valueOrNull;
    if (agent == null || bot == null || config == null) return;

    // Only respond to messages from the configured chat — ignore others.
    if (msg.chatId != config.chatId) return;

    try {
      // Show typing indicator while AI is processing.
      await bot.sendChatAction(config.chatId);

      // Stream AI response back to Telegram in real-time.
      final stream = agent.sendStreaming(text: msg.text);
      final result = await _streamResponse(stream, config.chatId, bot);

      // Handle tool calls.
      if (result.toolCalls != null && result.toolCalls!.isNotEmpty) {
        await _handleToolCalls(result.toolCalls!, config.chatId, bot, agent);
      }
    } catch (e) {
      try {
        await bot.sendMessage(config.chatId, '⚠️ AI 处理出错: $e');
      } catch (_) {}
    }
  }

  /// Streams AI deltas to Telegram via [sendMessageStreaming].
  /// Returns any tool calls found in the stream.
  Future<_StreamResult> _streamResponse(
    Stream<ChatStreamDelta> stream,
    String chatId,
    TelegramBotService bot,
  ) async {
    List<ChatToolCall>? pendingToolCalls;
    final textController = StreamController<String>();
    final sendFuture = bot.sendMessageStreaming(chatId, textController.stream);
    bool hasText = false;

    try {
      await for (final delta in stream) {
        if (delta.textDelta != null) {
          hasText = true;
          textController.add(delta.textDelta!);
        }
        if (delta.toolCallDeltas != null) {
          pendingToolCalls ??= [];
          _mergeToolCallDeltas(pendingToolCalls, delta.toolCallDeltas!);
        }
      }
    } finally {
      await textController.close();
    }

    if (hasText) {
      await sendFuture;
    }

    return _StreamResult(toolCalls: pendingToolCalls);
  }

  Future<void> _handleToolCalls(
    List<ChatToolCall> toolCalls,
    String chatId,
    TelegramBotService bot,
    AiAgentService agent,
  ) async {
    for (final tc in toolCalls) {
      if (_autoExecTools.contains(tc.name)) {
        // Show typing while executing tool.
        await bot.sendChatAction(chatId);
        final result = await _executeTool(tc);
        agent.addToolResult(tc.id, result);
      } else {
        // For write operations, just inform the user.
        await bot.sendMessage(
          chatId,
          '🔧 AI 请求执行: *${_toolDisplayName(tc.name)}*\n'
          '写入操作仅在 App 内确认后执行，请打开 App 处理。',
        );
        agent.addToolResult(tc.id, '用户需要在 App 内确认此操作。');
      }
    }

    // Continue the conversation after auto-executed tools — stream the reply.
    if (toolCalls.any((tc) => _autoExecTools.contains(tc.name))) {
      await bot.sendChatAction(chatId);
      final followUp = agent.sendStreaming();
      await _streamResponse(followUp, chatId, bot);
    }
  }

  Future<String> _executeTool(ChatToolCall tc) async {
    try {
      switch (tc.name) {
        case 'query_courses':
          final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
          return _queryCoursesResult(args);
        case 'query_semesters':
          return _querySemestersResult();
        case 'get_current_context':
          return fetchCurrentContext(
            weatherEnabled: _ref.read(weatherEnabledProvider).valueOrNull ?? false,
            weatherService: _ref.read(weatherServiceProvider),
          );
        case 'get_time':
          final now = DateTime.now();
          final timeFmt = DateFormat('yyyy-MM-dd HH:mm:ss (EEEE)', 'zh_CN');
          return '当前时间：${timeFmt.format(now)}';
        default:
          return '不支持的工具: ${tc.name}';
      }
    } catch (e) {
      return '执行失败: $e';
    }
  }

  Future<String> _queryCoursesResult(Map<String, dynamic> args) async {
    final repo = _ref.read(courseRepositoryProvider);
    final semesterId = _ref.read(activeSemesterIdProvider).valueOrNull;
    var courses = await repo.watchAll().first;
    if (semesterId != null) {
      courses = courses.where((c) => c.semesterId == semesterId).toList();
    }

    final nameFilter = args['name'] as String?;
    final weekdayFilter = args['weekday'] as int?;
    if (nameFilter != null) {
      courses = courses
          .where((c) => c.name.toLowerCase().contains(nameFilter.toLowerCase()))
          .toList();
    }
    if (weekdayFilter != null) {
      courses = courses.where((c) => c.weekday == weekdayFilter).toList();
    }

    if (courses.isEmpty) return '未找到匹配的课程。';

    final lines = courses.map((c) {
      final weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return '${c.name} | ${weekdays[c.weekday]} 第${c.startPeriod}-${c.endPeriod}节'
          '${c.location != null ? " | ${c.location}" : ""}';
    });
    return '找到 ${courses.length} 门课程:\n${lines.join("\n")}';
  }

  Future<String> _querySemestersResult() async {
    final repo = _ref.read(semesterRepositoryProvider);
    final semesters = await repo.watchAll().first;
    final activeId = _ref.read(activeSemesterIdProvider).valueOrNull;

    if (semesters.isEmpty) return '暂无学期。';

    final lines = semesters.map((s) {
      final active = s.id == activeId ? ' ✅' : '';
      return '${s.name}$active | 共${s.totalWeeks}周';
    });
    return '学期列表:\n${lines.join("\n")}';
  }

  void _mergeToolCallDeltas(
    List<ChatToolCall> acc,
    List<ChatToolCall> deltas,
  ) {
    for (final d in deltas) {
      final idx = int.tryParse(d.id);
      if (idx != null && idx < acc.length) {
        // Append to existing.
        acc[idx] = ChatToolCall(
          id: acc[idx].id.isEmpty ? d.id : acc[idx].id,
          name: acc[idx].name + d.name,
          arguments: acc[idx].arguments + d.arguments,
        );
      } else {
        acc.add(d);
      }
    }
  }

  String _toolDisplayName(String name) {
    const names = {
      'import_courses': '导入课程',
      'update_course': '修改课程',
      'delete_courses': '删除课程',
      'set_current_week': '设置当前周',
      'add_task': '添加任务',
      'add_reminder': '添加提醒',
      'set_period_times': '设置节次时间',
      'create_semester': '创建学期',
      'update_semester': '修改学期',
      'delete_semester': '删除学期',
    };
    return names[name] ?? name;
  }
}

class _StreamResult {
  final List<ChatToolCall>? toolCalls;
  const _StreamResult({this.toolCalls});
}

import 'dart:async';
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;

import 'ai_import_service_impl.dart' show AiImportConfig;

class AiAgentServiceImpl implements AiAgentService {
  final AiImportConfig config;
  final http.Client _client;
  final http.Client Function() _clientFactory;
  final List<Map<String, dynamic>> _history = [];
  bool _isBusy = false;
  bool _cancelled = false;
  /// Per-request client used for streaming; closed on cancel.
  http.Client? _activeStreamClient;

  static const _systemPrompt = '''
你是一个课程表管理助手 (AI Agent)。你可以帮助用户：
1. 从文本或图片中识别并导入课程表信息
2. 查询、修改、删除课程
3. 设置当前周次（设置第几周为本周）
4. 添加、查询、修改、删除提醒
5. 设置节次时间（每节课的上下课时间）
6. 管理学期（查询、创建、修改、删除学期）
7. 回答关于课程安排的问题
8. 获取当前时间、位置和天气信息

当用户发送课程表信息（文本或图片）时，使用 import_courses 工具来导入。
当用户要查询课程时，使用 query_courses 工具获取数据后回答。
当用户要修改课程时，先用 query_courses 查到课程ID，再用 update_course 修改。
当用户要删除课程时，先用 query_courses 查到课程ID，再用 delete_courses 删除。
当用户要设置当前周次时，使用 set_current_week 工具。
当用户要添加任务时，使用 add_task 工具。
当用户要添加提醒时，使用 add_reminder 工具。
当用户要查询提醒时，使用 query_reminders 工具。
当用户要修改提醒时，先用 query_reminders 查到提醒ID，再用 update_reminder 修改。
当用户要删除提醒时，先用 query_reminders 查到提醒ID，再用 delete_reminder 删除。
当用户要设置节次时间时，使用 set_period_times 工具。
当用户要查询学期时，使用 query_semesters 工具。
当用户要创建学期时，使用 create_semester 工具。
当用户要修改学期时，先用 query_semesters 查到学期ID，再用 update_semester 修改。
当用户要删除学期时，先用 query_semesters 查到学期ID，再用 delete_semester 删除。
当用户询问天气或位置相关问题时，使用 get_current_context 工具。
当用户询问现在几点、今天星期几、当前日期、第几周、第几节课等时间相关问题时，使用 get_time 工具。
不要直接输出 JSON，而是调用工具。

如果用户只是聊天或提问且不涉及上述操作，正常回复即可。
用中文回复。
''';

  static const _courseProperties = {
    'name': {
      'type': 'string',
      'description': '课程名称',
    },
    'location': {
      'type': 'string',
      'description': '上课地点',
    },
    'teacher': {
      'type': 'string',
      'description': '授课教师',
    },
    'weekday': {
      'type': 'integer',
      'description': '星期几，1=周一, 2=周二, ..., 7=周日',
    },
    'startPeriod': {
      'type': 'integer',
      'description': '开始节次，从1开始',
    },
    'endPeriod': {
      'type': 'integer',
      'description': '结束节次',
    },
    'weekMode': {
      'type': 'string',
      'enum': ['every', 'odd', 'even', 'custom'],
      'description': '周模式: every=每周, odd=单周, even=双周, custom=自定义',
    },
    'customWeeks': {
      'type': 'array',
      'items': {'type': 'integer'},
      'description': '当 weekMode 为 custom 时，具体哪几周上课',
    },
  };

  static const _tools = [
    {
      'type': 'function',
      'function': {
        'name': 'import_courses',
        'description': '导入识别到的课程到课程表。当从文本、图片或文件中识别出课程信息时调用此工具。',
        'parameters': {
          'type': 'object',
          'required': ['courses'],
          'properties': {
            'courses': {
              'type': 'array',
              'description': '要导入的课程列表',
              'items': {
                'type': 'object',
                'required': ['name', 'weekday', 'startPeriod', 'endPeriod'],
                'properties': _courseProperties,
              },
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'query_courses',
        'description': '查询当前课程表中的课程。可以按条件筛选。不带参数则返回全部课程。',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': '按课程名称模糊搜索',
            },
            'weekday': {
              'type': 'integer',
              'description': '按星期几筛选 (1-7)',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_course',
        'description': '修改一门已有课程的信息。需要提供课程ID和要修改的字段。',
        'parameters': {
          'type': 'object',
          'required': ['courseId'],
          'properties': {
            'courseId': {
              'type': 'string',
              'description': '要修改的课程ID',
            },
            ..._courseProperties,
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_courses',
        'description': '删除指定的课程。需要提供课程ID列表。',
        'parameters': {
          'type': 'object',
          'required': ['courseIds'],
          'properties': {
            'courseIds': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': '要删除的课程ID列表',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'set_current_week',
        'description': '设置当前是第几周。会自动调整学期开始日期使得指定周变为本周。',
        'parameters': {
          'type': 'object',
          'required': ['weekNumber'],
          'properties': {
            'weekNumber': {
              'type': 'integer',
              'description': '要设置为本周的周次，例如 5 表示设置为第5周',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_task',
        'description': '添加一个新任务/待办事项。',
        'parameters': {
          'type': 'object',
          'required': ['title'],
          'properties': {
            'title': {
              'type': 'string',
              'description': '任务标题',
            },
            'description': {
              'type': 'string',
              'description': '任务详细描述',
            },
            'priority': {
              'type': 'string',
              'enum': ['low', 'medium', 'high'],
              'description': '优先级: low=低, medium=中, high=高',
            },
            'dueDate': {
              'type': 'string',
              'description': '截止日期，ISO 8601 格式，如 2026-03-15T23:59:00',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_reminder',
        'description': '添加一个提醒/闹钟。会在指定时间发送通知。',
        'parameters': {
          'type': 'object',
          'required': ['title', 'scheduledAt'],
          'properties': {
            'title': {
              'type': 'string',
              'description': '提醒标题',
            },
            'body': {
              'type': 'string',
              'description': '提醒内容/描述',
            },
            'scheduledAt': {
              'type': 'string',
              'description': '提醒时间，ISO 8601 格式，如 2026-03-15T08:00:00',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'query_reminders',
        'description': '查询所有提醒/闹钟。返回提醒列表，包含 ID、标题、时间等信息。',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_reminder',
        'description': '修改已有的提醒/闹钟。先用 query_reminders 查到提醒ID。',
        'parameters': {
          'type': 'object',
          'required': ['reminderId'],
          'properties': {
            'reminderId': {
              'type': 'string',
              'description': '提醒ID',
            },
            'title': {
              'type': 'string',
              'description': '新的提醒标题',
            },
            'body': {
              'type': 'string',
              'description': '新的提醒内容/描述',
            },
            'scheduledAt': {
              'type': 'string',
              'description': '新的提醒时间，ISO 8601 格式',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_reminder',
        'description': '删除一个提醒/闹钟。先用 query_reminders 查到提醒ID。',
        'parameters': {
          'type': 'object',
          'required': ['reminderId'],
          'properties': {
            'reminderId': {
              'type': 'string',
              'description': '要删除的提醒ID',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'set_period_times',
        'description': '设置节次时间表。定义每节课的上课和下课时间。',
        'parameters': {
          'type': 'object',
          'required': ['periods'],
          'properties': {
            'totalPeriods': {
              'type': 'integer',
              'description': '总节次数，默认12',
            },
            'periods': {
              'type': 'array',
              'description': '每节课的时间列表',
              'items': {
                'type': 'object',
                'required': [
                  'periodNumber',
                  'startHour',
                  'startMinute',
                  'endHour',
                  'endMinute'
                ],
                'properties': {
                  'periodNumber': {
                    'type': 'integer',
                    'description': '节次编号，从1开始',
                  },
                  'startHour': {
                    'type': 'integer',
                    'description': '上课小时 (0-23)',
                  },
                  'startMinute': {
                    'type': 'integer',
                    'description': '上课分钟 (0-59)',
                  },
                  'endHour': {
                    'type': 'integer',
                    'description': '下课小时 (0-23)',
                  },
                  'endMinute': {
                    'type': 'integer',
                    'description': '下课分钟 (0-59)',
                  },
                },
              },
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'query_semesters',
        'description': '查询所有学期信息，包括学期名称、开始日期、总周数和当前周次。',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'create_semester',
        'description': '创建一个新学期。',
        'parameters': {
          'type': 'object',
          'required': ['name', 'startDate'],
          'properties': {
            'name': {
              'type': 'string',
              'description': '学期名称，如"2025-2026 秋季学期"',
            },
            'startDate': {
              'type': 'string',
              'description': '学期第一周周一的日期，ISO 8601 格式，如 2025-09-01',
            },
            'totalWeeks': {
              'type': 'integer',
              'description': '学期总周数，默认20',
            },
            'setActive': {
              'type': 'boolean',
              'description': '是否设为当前活跃学期，默认true',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_semester',
        'description': '修改一个已有学期的信息。需要提供学期ID和要修改的字段。',
        'parameters': {
          'type': 'object',
          'required': ['semesterId'],
          'properties': {
            'semesterId': {
              'type': 'string',
              'description': '要修改的学期ID',
            },
            'name': {
              'type': 'string',
              'description': '学期名称',
            },
            'startDate': {
              'type': 'string',
              'description': '学期开始日期，ISO 8601 格式',
            },
            'totalWeeks': {
              'type': 'integer',
              'description': '学期总周数',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_semester',
        'description': '删除指定学期。注意：该学期下的所有课程也会失去归属。',
        'parameters': {
          'type': 'object',
          'required': ['semesterId'],
          'properties': {
            'semesterId': {
              'type': 'string',
              'description': '要删除的学期ID',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_current_context',
        'description': '获取当前时间、用户位置和天气信息。当用户询问天气、时间、日期或位置相关问题时调用。',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_time',
        'description': '获取当前日期和时间。当用户询问现在几点、今天星期几、当前日期等时间相关问题时调用。',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
  ];

  AiAgentServiceImpl({
    required this.config,
    http.Client? client,
    http.Client Function()? clientFactory,
  })  : _client = client ?? http.Client(),
        _clientFactory = clientFactory ?? http.Client.new;

  @override
  bool get isBusy => _isBusy;

  @override
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  @override
  void restoreHistory(List<Map<String, dynamic>> history) {
    _history.clear();
    // Always prepend system prompt so AI continues to follow tool protocols.
    _history.add({'role': 'system', 'content': _systemPrompt});
    _history.addAll(history);
  }

  void _ensureSystemPrompt(String? extraPrompt) {
    if (_history.isEmpty) {
      final systemContent = extraPrompt != null
          ? '$_systemPrompt\n额外提示：$extraPrompt'
          : _systemPrompt;
      _history.add({'role': 'system', 'content': systemContent});
    }
  }

  dynamic _buildUserContent(String? text, List<ChatImage> images) {
    final userContent = <dynamic>[];
    if (text != null && text.isNotEmpty) {
      userContent.add({'type': 'text', 'text': text});
    }
    for (final img in images) {
      userContent.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:${img.mimeType};base64,${img.base64Data}',
        },
      });
    }
    return images.isEmpty && text != null ? text : userContent;
  }

  Map<String, dynamic> _buildRequestBody() => {
        'model': config.modelName ?? 'gpt-4o-mini',
        'messages': _history,
        'temperature': 0.3,
        'tools': _tools,
      };

  @override
  Future<ChatMessage> send({
    String? text,
    List<ChatImage> images = const [],
    String? extraPrompt,
  }) async {
    _isBusy = true;
    _cancelled = false;
    try {
      _ensureSystemPrompt(extraPrompt);
      if (text != null || images.isNotEmpty) {
        _history.add(
            {'role': 'user', 'content': _buildUserContent(text, images)});
      }

      final body = jsonEncode(_buildRequestBody());

      final response = await _client.post(
        Uri.parse(config.chatCompletionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception(
            'AI API 请求失败: ${response.statusCode} ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final message = json['choices'][0]['message'] as Map<String, dynamic>;
      final assistantText = message['content'] as String?;
      final toolCallsRaw = message['tool_calls'] as List<dynamic>?;

      // Save assistant message to history (including tool_calls for proper conversation flow)
      final historyEntry = <String, dynamic>{
        'role': 'assistant',
      };
      if (assistantText != null) historyEntry['content'] = assistantText;
      if (toolCallsRaw != null) historyEntry['tool_calls'] = toolCallsRaw;
      _history.add(historyEntry);

      final toolCalls = toolCallsRaw?.map((tc) {
        final fn = tc['function'] as Map<String, dynamic>;
        return ChatToolCall(
          id: tc['id'] as String,
          name: fn['name'] as String,
          arguments: fn['arguments'] as String,
        );
      }).toList();

      // Parse courses from tool call arguments
      List<AiParsedCourse>? parsedCourses;
      if (toolCalls != null) {
        for (final tc in toolCalls) {
          if (tc.name == 'import_courses') {
            parsedCourses = _parseCoursesFromToolArgs(tc.arguments);
          }
        }
      }
      // Fallback: also try extracting from text (for models that don't support tools)
      if (parsedCourses == null && assistantText != null) {
        final courses = extractCourses(assistantText);
        if (courses.isNotEmpty) parsedCourses = courses;
      }

      return ChatMessage(
        role: ChatRole.assistant,
        text: assistantText,
        parsedCourses: parsedCourses,
        toolCalls: toolCalls,
      );
    } finally {
      _isBusy = false;
    }
  }

  @override
  Stream<ChatStreamDelta> sendStreaming({
    String? text,
    List<ChatImage> images = const [],
    String? extraPrompt,
  }) async* {
    _isBusy = true;
    _cancelled = false;

    try {
      _ensureSystemPrompt(extraPrompt);
      if (text != null || images.isNotEmpty) {
        _history.add(
            {'role': 'user', 'content': _buildUserContent(text, images)});
      }

      final request = http.Request('POST', Uri.parse(config.chatCompletionsUrl));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer ${config.apiKey}';
      request.body = jsonEncode({
        ..._buildRequestBody(),
        'stream': true,
      });

      // Use a per-request client so cancel() can close it without
      // affecting the shared _client. Uses _clientFactory to respect proxy.
      _activeStreamClient = _clientFactory();
      final streamedResponse = await _activeStreamClient!.send(request);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        throw Exception(
            'AI API 请求失败: ${streamedResponse.statusCode} $body');
      }

      final fullText = StringBuffer();
      final toolCallAccumulators = <String, _ToolCallAccumulator>{};
      var buffer = '';

      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        if (_cancelled) break;

        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed == 'data: [DONE]') continue;
          if (!trimmed.startsWith('data: ')) continue;

          final jsonStr = trimmed.substring(6);
          try {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            final choices = json['choices'] as List<dynamic>;
            if (choices.isEmpty) continue;

            final delta =
                choices[0]['delta'] as Map<String, dynamic>? ?? {};
            final content = delta['content'] as String?;
            final tcDeltas = delta['tool_calls'] as List<dynamic>?;

            List<ChatToolCall>? parsedToolCalls;
            if (tcDeltas != null) {
              for (final tc in tcDeltas) {
                final index = tc['index'] as int;
                final key = index.toString();
                final fn = tc['function'] as Map<String, dynamic>?;

                toolCallAccumulators.putIfAbsent(
                    key, () => _ToolCallAccumulator());
                if (tc['id'] != null) {
                  toolCallAccumulators[key]!.id = tc['id'] as String;
                }
                if (fn != null) {
                  if (fn['name'] != null) {
                    toolCallAccumulators[key]!.name = fn['name'] as String;
                  }
                  if (fn['arguments'] != null) {
                    toolCallAccumulators[key]!.arguments +=
                        fn['arguments'] as String;
                  }
                }
              }

              parsedToolCalls = toolCallAccumulators.values
                  .where((tc) => tc.id != null && tc.name != null)
                  .map((tc) => ChatToolCall(
                        id: tc.id!,
                        name: tc.name!,
                        arguments: tc.arguments,
                      ))
                  .toList();
            }

            if (content != null) {
              fullText.write(content);
            }

            yield ChatStreamDelta(
              textDelta: content,
              toolCallDeltas:
                  parsedToolCalls?.isNotEmpty == true ? parsedToolCalls : null,
            );
          } catch (_) {}
        }
      }

      // Save to history (including tool_calls)
      final finalText = fullText.toString();
      final historyEntry = <String, dynamic>{'role': 'assistant'};
      if (finalText.isNotEmpty) historyEntry['content'] = finalText;
      if (toolCallAccumulators.isNotEmpty) {
        historyEntry['tool_calls'] = toolCallAccumulators.values
            .where((tc) => tc.id != null && tc.name != null)
            .map((tc) => {
                  'id': tc.id,
                  'type': 'function',
                  'function': {
                    'name': tc.name,
                    'arguments': tc.arguments,
                  },
                })
            .toList();
      }
      _history.add(historyEntry);

      yield const ChatStreamDelta(isDone: true);
    } finally {
      _activeStreamClient?.close();
      _activeStreamClient = null;
      _isBusy = false;
    }
  }

  @override
  void addToolResult(String toolCallId, String result) {
    _history.add({
      'role': 'tool',
      'tool_call_id': toolCallId,
      'content': result,
    });
  }

  @override
  void cancel() {
    _cancelled = true;
    if (_isBusy) {
      _activeStreamClient?.close();
      _activeStreamClient = null;
      _isBusy = false;
      if (_history.isNotEmpty && _history.last['role'] == 'user') {
        _history.removeLast();
      }
    }
  }

  @override
  List<AiParsedCourse> extractCourses(String text) {
    try {
      final jsonStr = _extractJson(text);
      if (jsonStr == null) return [];
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return _parseCourseList(list);
    } catch (_) {
      return [];
    }
  }

  @override
  List<AiParsedCourse> parseCoursesFromToolCall(String arguments) =>
      _parseCoursesFromToolArgs(arguments);

  List<AiParsedCourse> _parseCoursesFromToolArgs(String arguments) {
    try {
      final json = jsonDecode(arguments) as Map<String, dynamic>;
      final courses = json['courses'] as List<dynamic>;
      return _parseCourseList(courses);
    } catch (_) {
      return [];
    }
  }

  List<AiParsedCourse> _parseCourseList(List<dynamic> list) {
    return list.map((item) {
      final m = item as Map<String, dynamic>;
      return AiParsedCourse(
        name: m['name'] as String,
        location: m['location'] as String?,
        teacher: m['teacher'] as String?,
        weekday: m['weekday'] as int,
        startPeriod: m['startPeriod'] as int,
        endPeriod: m['endPeriod'] as int,
        weekMode: _parseWeekMode(m['weekMode'] as String?),
        customWeeks: (m['customWeeks'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [],
      );
    }).toList();
  }

  @override
  void clearHistory() => _history.clear();

  String? _extractJson(String content) {
    final codeBlockMatch =
        RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(content);
    if (codeBlockMatch != null) {
      final candidate = codeBlockMatch.group(1)!.trim();
      if (candidate.startsWith('[')) return candidate;
    }
    // Also handle bare JSON arrays (e.g. from persisted parsedCoursesJson).
    final trimmed = content.trim();
    if (trimmed.startsWith('[')) return trimmed;
    return null;
  }

  WeekMode _parseWeekMode(String? value) => switch (value) {
        'odd' => WeekMode.odd,
        'even' => WeekMode.even,
        'custom' => WeekMode.custom,
        _ => WeekMode.every,
      };
}

class _ToolCallAccumulator {
  String? id;
  String? name;
  String arguments = '';
}

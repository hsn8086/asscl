import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../providers/ai_providers.dart';
import '../../providers/bot_providers.dart';
import '../../providers/course_providers.dart';
import '../../providers/database_provider.dart';
import '../../providers/notification_providers.dart';
import '../../providers/period_config_providers.dart';
import '../../providers/reminder_providers.dart';
import '../../providers/semester_providers.dart';
import '../../providers/task_providers.dart';
import '../../providers/weather_providers.dart';
import '../../providers/voice_providers.dart';
import '../../providers/widget_providers.dart';

const _uuid = Uuid();

// ===== Tool call confirmation state =====
enum _ToolCallStatus { pending, confirmed, rejected }

// ===== Per-tool-call data =====
class _PendingToolCall {
  final String id; // tool call ID
  final String name; // tool name
  _ToolCallStatus status = _ToolCallStatus.pending;

  // import_courses
  List<AiParsedCourse>? parsedCourses;
  // update_course
  Course? updateOriginalCourse;
  Map<String, dynamic>? updateFields;
  // delete_courses
  List<Course>? deleteCourses;
  // set_current_week
  int? setWeekNumber;
  // add_task
  Map<String, dynamic>? addTaskFields;
  // add_reminder
  Map<String, dynamic>? addReminderFields;
  // update_reminder
  Reminder? updateReminderOriginal;
  Map<String, dynamic>? updateReminderFields;
  // delete_reminder
  Reminder? deleteReminder;
  // set_period_times
  Map<String, dynamic>? setPeriodTimesFields;
  // create_semester
  Map<String, dynamic>? createSemesterFields;
  // update_semester
  Semester? updateSemesterOriginal;
  Map<String, dynamic>? updateSemesterFields;
  // delete_semester
  Semester? deleteSemester;

  _PendingToolCall({
    required this.id,
    required this.name,
  });
}

// ===== UI message model =====
class _UiMessage {
  final String id;
  final ChatRole role;
  String? text;
  final List<File> imageFiles;
  /// For DB save / text-fallback import
  List<AiParsedCourse>? parsedCourses;
  List<ChatToolCall>? toolCalls;
  bool isStreaming;

  /// Per-tool-call tracking (each has its own status + data)
  final List<_PendingToolCall> pendingToolCalls = [];

  _UiMessage({
    String? id,
    required this.role,
    this.text,
    this.imageFiles = const [],
    this.parsedCourses,
    this.isStreaming = false,
  }) : id = id ?? _uuid.v4();
}

// ===== Module-level persistent state =====
// Survives widget disposal / page navigation.
class _ChatPersistence {
  final messages = <_UiMessage>[];
  final pendingImages = <File>[];
  bool isSending = false;
  String? currentSessionId;
  bool isLoadedFromDb = false;
  StreamSubscription<ChatStreamDelta>? streamSub;

  /// Widget callback — set by the page, cleared on dispose.
  VoidCallback? onChanged;

  void notify() => onChanged?.call();

  void reset() {
    streamSub?.cancel();
    streamSub = null;
    messages.clear();
    pendingImages.clear();
    isSending = false;
    currentSessionId = null;
    isLoadedFromDb = false;
  }
}

final _persistence = _ChatPersistence();

// ===== Page widget =====
class AiImportPage extends ConsumerStatefulWidget {
  const AiImportPage({super.key});

  @override
  ConsumerState<AiImportPage> createState() => _AiImportPageState();
}

class _AiImportPageState extends ConsumerState<AiImportPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;

  // Convenience accessors into persistence
  List<_UiMessage> get _messages => _persistence.messages;
  List<File> get _pendingImages => _persistence.pendingImages;
  bool get _isSending => _persistence.isSending;
  set _isSending(bool v) => _persistence.isSending = v;
  String? get _currentSessionId => _persistence.currentSessionId;
  set _currentSessionId(String? v) => _persistence.currentSessionId = v;

  @override
  void initState() {
    super.initState();
    _persistence.onChanged = _onPersistenceChanged;
    if (!_persistence.isLoadedFromDb) {
      _loadCurrentSession();
    }
    _scrollToBottom();
  }

  @override
  void dispose() {
    _persistence.onChanged = null;
    // DO NOT cancel streaming or clear state — persist across navigation
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _onPersistenceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCurrentSession() async {
    final sessionId = ref.read(currentChatSessionIdProvider);
    if (sessionId != null && !_persistence.isLoadedFromDb) {
      _persistence.isLoadedFromDb = true;
      final dao = ref.read(chatSessionDaoProvider);
      final dbMessages = await dao.getMessages(sessionId);
      if (dbMessages.isNotEmpty && mounted) {
        setState(() {
          _currentSessionId = sessionId;
          _messages.clear();
          for (final m in dbMessages) {
            List<AiParsedCourse>? courses;
            if (m.parsedCoursesJson != null) {
              try {
                final agent = ref.read(aiAgentServiceProvider);
                courses = agent?.extractCourses(m.parsedCoursesJson!);
              } catch (_) {}
            }
            _messages.add(_UiMessage(
              id: m.id,
              role: m.role == 'user' ? ChatRole.user : ChatRole.assistant,
              text: m.content,
              imageFiles: ChatSessionDao.decodeImagePaths(m.imagePaths)
                  .map((p) => File(p))
                  .toList(),
              parsedCourses: courses,
            ));
          }
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pendingImages.add(File(picked.path)));
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'ics', 'xlsx', 'xls', 'csv', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final ext = result.files.single.extension?.toLowerCase() ?? '';

    String content;
    try {
      if (ext == 'xlsx') {
        content = _parseExcel(file);
      } else if (ext == 'xls') {
        // The excel package only supports .xlsx, not legacy .xls (BIFF) format.
        // Try parsing — if it's actually xlsx with wrong extension it may work.
        try {
          content = _parseExcel(file);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('不支持旧版 .xls 格式，请用 Excel 另存为 .xlsx 后重试'),
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      } else {
        content = await file.readAsString();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('读取文件失败: $e')),
        );
      }
      return;
    }

    final prefix = switch (ext) {
      'json' => '以下是 JSON 格式的课程数据，请识别并整理：\n\n',
      'ics' => '以下是 iCalendar (.ics) 格式的日历数据，请从中识别课程信息：\n\n',
      'csv' => '以下是 CSV 格式的课程数据，请识别并整理：\n\n',
      'xlsx' || 'xls' => '以下是从 Excel 文件提取的课程表数据，请识别并整理：\n\n',
      _ => '以下是课程相关文件内容，请识别课程信息：\n\n',
    };

    _textController.text = '$prefix$content';
  }

  String _parseExcel(File file) {
    final bytes = file.readAsBytesSync();
    final excel = xl.Excel.decodeBytes(bytes);
    final buf = StringBuffer();

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;
      buf.writeln('--- Sheet: $sheetName ---');
      for (final row in sheet.rows) {
        final cells = row.map((cell) {
          final raw = cell?.value?.toString() ?? '';
          // CSV-style escaping: quote if contains comma, quote, or newline
          if (raw.contains(',') ||
              raw.contains('"') ||
              raw.contains('\n') ||
              raw.contains('\r')) {
            return '"${raw.replaceAll('"', '""')}"';
          }
          return raw;
        }).toList();
        buf.writeln(cells.join(','));
      }
      buf.writeln();
    }
    return buf.toString();
  }

  void _removePendingImage(int index) {
    setState(() => _pendingImages.removeAt(index));
  }

  Future<String> _ensureSession() async {
    if (_currentSessionId != null) return _currentSessionId!;
    final id = _uuid.v4();
    final now = DateTime.now();
    final dao = ref.read(chatSessionDaoProvider);
    await dao.upsertSession(ChatSessionsTableCompanion.insert(
      id: id,
      title: '新对话',
      createdAt: now,
      updatedAt: now,
    ));
    _currentSessionId = id;
    ref.read(currentChatSessionIdProvider.notifier).state = id;
    return id;
  }

  Future<void> _saveMessageToDb(
      ChatSessionDao dao, String sessionId, _UiMessage msg) async {
    await dao.insertMessage(ChatMessagesTableCompanion.insert(
      id: msg.id,
      sessionId: sessionId,
      role: msg.role == ChatRole.user ? 'user' : 'assistant',
      content: Value(msg.text),
      imagePaths: Value(ChatSessionDao.encodeImagePaths(
          msg.imageFiles.map((f) => f.path).toList())),
      parsedCoursesJson: Value(msg.parsedCourses != null
          ? jsonEncode(msg.parsedCourses!
              .map((c) => {
                    'name': c.name,
                    'location': c.location,
                    'teacher': c.teacher,
                    'weekday': c.weekday,
                    'startPeriod': c.startPeriod,
                    'endPeriod': c.endPeriod,
                    'weekMode': c.weekMode.name,
                    'customWeeks': c.customWeeks,
                  })
              .toList())
          : null),
      createdAt: DateTime.now(),
    ));
    // Update session title from first user message
    if (_messages.where((m) => m.role == ChatRole.user).length == 1 &&
        msg.role == ChatRole.user &&
        msg.text != null) {
      final title = msg.text!.length > 20
          ? '${msg.text!.substring(0, 20)}...'
          : msg.text!;
      await dao.upsertSession(ChatSessionsTableCompanion(
        id: Value(sessionId),
        title: Value(title),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  void _cancelSending() {
    _persistence.streamSub?.cancel();
    _persistence.streamSub = null;
    final agent = ref.read(aiAgentServiceProvider);
    agent?.cancel();
    setState(() {
      if (_messages.isNotEmpty) {
        final last = _messages.last;
        if (last.isStreaming && (last.text ?? '').isEmpty) {
          _messages.removeLast();
        } else if (last.isStreaming) {
          last.isStreaming = false;
        }
      }
      _isSending = false;
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        setState(() => _isRecording = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限才能录音')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音启动失败: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });

      if (path == null) {
        setState(() => _isTranscribing = false);
        return;
      }

      final sttService = ref.read(sttServiceProvider);
      if (sttService == null) {
        setState(() => _isTranscribing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('语音功能未配置，请在 AI 配置中设置')),
          );
        }
        // Clean up temp file
        try { await File(path).delete(); } catch (_) {}
        return;
      }

      try {
        final text = await sttService.transcribe(filePath: path);
        if (text.isNotEmpty && mounted) {
          final current = _textController.text;
          _textController.text = current.isEmpty ? text : '$current $text';
          _textController.selection = TextSelection.collapsed(
            offset: _textController.text.length,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('语音转文字失败: $e')),
          );
        }
      } finally {
        // Clean up temp file
        try { await File(path).delete(); } catch (_) {}
        if (mounted) setState(() => _isTranscribing = false);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });
    }
  }

  Future<void> _send() async {
    final agent = ref.read(aiAgentServiceProvider);
    if (agent == null) {
      final isLoading = ref.read(aiConfigProvider).isLoading;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isLoading ? '配置加载中，请稍后再试' : '请先在设置中配置 AI API'),
        ),
      );
      return;
    }

    final text = _textController.text.trim();
    final images = List<File>.from(_pendingImages);
    if (text.isEmpty && images.isEmpty) return;

    // Build ChatImage list
    final chatImages = <ChatImage>[];
    for (final file in images) {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      final mime = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      chatImages.add(ChatImage(
        base64Data: base64Encode(bytes),
        mimeType: mime,
      ));
    }

    final sessionId = await _ensureSession();

    final userMsg = _UiMessage(
      role: ChatRole.user,
      text: text.isNotEmpty ? text : null,
      imageFiles: images,
    );

    final assistantMsg = _UiMessage(
      role: ChatRole.assistant,
      text: '',
      isStreaming: true,
    );

    setState(() {
      _messages.add(userMsg);
      _messages.add(assistantMsg);
      _textController.clear();
      _pendingImages.clear();
      _isSending = true;
    });
    _scrollToBottom();

    // Capture refs for use in background callbacks
    final dao = ref.read(chatSessionDaoProvider);
    final repo = ref.read(courseRepositoryProvider);

    await _saveMessageToDb(dao, sessionId, userMsg);

    try {
      final config = ref.read(periodConfigProvider).valueOrNull;
      String? extraPrompt;
      if (config?.presetId != null) {
        final preset = kSchoolPresets.cast<SchoolPreset?>().firstWhere(
            (p) => p!.id == config!.presetId,
            orElse: () => null);
        extraPrompt = preset?.aiPromptHint;
      }

      _startStreaming(
        agent: agent,
        assistantMsg: assistantMsg,
        sessionId: sessionId,
        dao: dao,
        repo: repo,
        text: text.isNotEmpty ? text : '请识别这张图片中的课程表信息',
        images: chatImages,
        extraPrompt: _messages.length <= 2 ? extraPrompt : null,
      );
    } catch (e) {
      final isCancelled = e.toString().contains('Client is closed') ||
          e.toString().contains('Connection closed');
      if (mounted) {
        if (isCancelled) {
          setState(() {
            if (_messages.isNotEmpty && _messages.last.isStreaming) {
              _messages.removeLast();
            }
            _isSending = false;
          });
        } else {
          final errMsg = _UiMessage(role: ChatRole.assistant, text: '出错了: $e');
          setState(() {
            _messages.removeLast();
            _messages.add(errMsg);
            _isSending = false;
          });
          _scrollToBottom();
          await _saveMessageToDb(dao, sessionId, errMsg);
        }
      }
    }
  }

  /// Start SSE streaming. Callbacks update _persistence directly and survive
  /// widget unmount.
  void _startStreaming({
    required AiAgentService agent,
    required _UiMessage assistantMsg,
    required String sessionId,
    required ChatSessionDao dao,
    required CourseRepository repo,
    String? text,
    List<ChatImage> images = const [],
    String? extraPrompt,
  }) {
    final Stream<ChatStreamDelta> stream;
    if (text != null) {
      stream = agent.sendStreaming(
        text: text,
        images: images,
        extraPrompt: extraPrompt,
      );
    } else {
      // Continue after tool result (no user text)
      stream = agent.sendStreaming();
    }

    _persistence.streamSub?.cancel();
    _persistence.streamSub = stream.listen(
      (delta) {
        if (delta.textDelta != null) {
          assistantMsg.text = (assistantMsg.text ?? '') + delta.textDelta!;
        }
        if (delta.toolCallDeltas != null) {
          assistantMsg.toolCalls = delta.toolCallDeltas;
        }
        if (delta.isDone) {
          assistantMsg.isStreaming = false;
          _isSending = false;
          if (assistantMsg.toolCalls != null) {
            _handleToolCalls(
              msg: assistantMsg,
              agent: agent,
              sessionId: sessionId,
              dao: dao,
              repo: repo,
            );
          } else {
            // Fallback: extract from text (models without tool support)
            final fullText = assistantMsg.text ?? '';
            if (fullText.isNotEmpty) {
              final courses = agent.extractCourses(fullText);
              if (courses.isNotEmpty) {
                assistantMsg.parsedCourses = courses;
                final ptc = _PendingToolCall(
                  id: 'text_fallback',
                  name: 'import_courses',
                );
                ptc.parsedCourses = courses;
                assistantMsg.pendingToolCalls.add(ptc);
              }
            }
          }
        }
        _persistence.notify();
        if (mounted) _scrollToBottom();
      },
      onError: (e) {
        final isCancelled = e.toString().contains('Client is closed') ||
            e.toString().contains('Connection closed');
        if (isCancelled) {
          assistantMsg.isStreaming = false;
          if ((assistantMsg.text ?? '').isEmpty) {
            _messages.remove(assistantMsg);
          }
        } else {
          assistantMsg.text = '出错了: $e';
          assistantMsg.isStreaming = false;
        }
        _isSending = false;
        _persistence.notify();
      },
      onDone: () async {
        _persistence.streamSub = null;
        if (!assistantMsg.isStreaming) {
          await _saveMessageToDb(dao, sessionId, assistantMsg);
        }
      },
    );
  }

  /// Dispatch tool calls to appropriate handlers.
  Future<void> _handleToolCalls({
    required _UiMessage msg,
    required AiAgentService agent,
    required String sessionId,
    required ChatSessionDao dao,
    required CourseRepository repo,
  }) async {
    for (final tc in msg.toolCalls!) {
      final ptc = _PendingToolCall(id: tc.id, name: tc.name);

      switch (tc.name) {
        case 'import_courses':
          final courses = agent.parseCoursesFromToolCall(tc.arguments);
          if (courses.isNotEmpty) {
            ptc.parsedCourses = courses;
            msg.parsedCourses = courses; // for DB save
          } else {
            ptc.status = _ToolCallStatus.confirmed;
          }
        case 'query_courses':
          await _executeQueryCourses(ptc: ptc, tc: tc, agent: agent, repo: repo);
        case 'update_course':
          await _prepareUpdateCourse(ptc, tc, repo);
        case 'delete_courses':
          await _prepareDeleteCourses(ptc, tc, repo);
        case 'set_current_week':
          _prepareSetCurrentWeek(ptc, tc);
        case 'add_task':
          _prepareAddTask(ptc, tc);
        case 'add_reminder':
          _prepareAddReminder(ptc, tc);
        case 'query_reminders':
          await _executeQueryReminders(ptc: ptc, tc: tc, agent: agent);
        case 'update_reminder':
          await _prepareUpdateReminder(ptc, tc);
        case 'delete_reminder':
          await _prepareDeleteReminder(ptc, tc);
        case 'set_period_times':
          _prepareSetPeriodTimes(ptc, tc);
        case 'query_semesters':
          await _executeQuerySemesters(ptc: ptc, tc: tc, agent: agent);
        case 'create_semester':
          _prepareCreateSemester(ptc, tc);
        case 'update_semester':
          await _prepareUpdateSemester(ptc, tc);
        case 'delete_semester':
          await _prepareDeleteSemester(ptc, tc);
        case 'get_current_context':
          await _executeGetCurrentContext(ptc: ptc, tc: tc, agent: agent);
        case 'get_time':
          _executeGetTime(ptc: ptc, tc: tc, agent: agent);
      }

      msg.pendingToolCalls.add(ptc);
    }
    _persistence.notify();
    _checkAllToolCallsResolved(msg);
  }

  /// Check if all tool calls in a message are resolved, and continue if so.
  void _checkAllToolCallsResolved(_UiMessage msg) {
    final allResolved = msg.pendingToolCalls.every(
        (ptc) => ptc.status != _ToolCallStatus.pending);
    if (!allResolved) return;

    final agent = ref.read(aiAgentServiceProvider);
    if (agent == null) return;

    final dao = ref.read(chatSessionDaoProvider);
    final repo = ref.read(courseRepositoryProvider);
    _continueAfterToolResult(
      agent: agent,
      sessionId: _currentSessionId ?? '',
      dao: dao,
      repo: repo,
    );
  }

  /// Auto-execute query_courses.
  Future<void> _executeQueryCourses({
    required _PendingToolCall ptc,
    required ChatToolCall tc,
    required AiAgentService agent,
    required CourseRepository repo,
  }) async {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      final nameFilter = args['name'] as String?;
      final weekdayFilter = args['weekday'] as int?;

      final allCourses = await repo.watchAll().first;

      var filtered = allCourses;
      if (nameFilter != null && nameFilter.isNotEmpty) {
        filtered = filtered
            .where(
                (c) => c.name.toLowerCase().contains(nameFilter.toLowerCase()))
            .toList();
      }
      if (weekdayFilter != null) {
        filtered = filtered.where((c) => c.weekday == weekdayFilter).toList();
      }

      final resultJson = jsonEncode(filtered
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'location': c.location,
                'teacher': c.teacher,
                'weekday': c.weekday,
                'startPeriod': c.startPeriod,
                'endPeriod': c.endPeriod,
                'weekMode': c.weekMode.name,
                'customWeeks': c.customWeeks,
              })
          .toList());

      agent.addToolResult(
          tc.id, '查询到 ${filtered.length} 门课程：$resultJson');
      ptc.status = _ToolCallStatus.confirmed;
    } catch (e) {
      agent.addToolResult(tc.id, '查询失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  /// Prepare update_course for user confirmation.
  Future<void> _prepareUpdateCourse(
      _PendingToolCall ptc, ChatToolCall tc, CourseRepository repo) async {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      final courseId = args['courseId'] as String;
      final course = await repo.findById(courseId);

      if (course == null) {
        final agent = ref.read(aiAgentServiceProvider);
        agent?.addToolResult(tc.id, '未找到 ID 为 $courseId 的课程');
        ptc.status = _ToolCallStatus.confirmed;
        return;
      }

      final updateFields = Map<String, dynamic>.from(args)..remove('courseId');
      ptc.updateOriginalCourse = course;
      ptc.updateFields = updateFields;
    } catch (e) {
      final agent = ref.read(aiAgentServiceProvider);
      agent?.addToolResult(tc.id, '解析更新参数失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  /// Prepare delete_courses for user confirmation.
  Future<void> _prepareDeleteCourses(
      _PendingToolCall ptc, ChatToolCall tc, CourseRepository repo) async {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      final courseIds = (args['courseIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList();

      final courses = <Course>[];
      for (final id in courseIds) {
        final course = await repo.findById(id);
        if (course != null) courses.add(course);
      }

      if (courses.isEmpty) {
        final agent = ref.read(aiAgentServiceProvider);
        agent?.addToolResult(tc.id, '未找到要删除的课程');
        ptc.status = _ToolCallStatus.confirmed;
        return;
      }

      ptc.deleteCourses = courses;
    } catch (e) {
      final agent = ref.read(aiAgentServiceProvider);
      agent?.addToolResult(tc.id, '解析删除参数失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  // ===== Shared tool-call helpers =====

  /// Submit a tool result to the AI agent for a specific pending tool call.
  void _submitToolResult(_PendingToolCall ptc, _UiMessage msg, String result) {
    final agent = ref.read(aiAgentServiceProvider);
    if (agent != null && msg.toolCalls != null) {
      for (final tc in msg.toolCalls!) {
        if (tc.id == ptc.id) {
          agent.addToolResult(tc.id, result);
        }
      }
    }
  }

  /// Mark a tool call as confirmed, show a snackbar, and check resolution.
  void _confirmToolCall(
    _PendingToolCall ptc,
    _UiMessage msg,
    String toolResult,
    String snackMessage,
  ) {
    _submitToolResult(ptc, msg, toolResult);
    setState(() => ptc.status = _ToolCallStatus.confirmed);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(snackMessage)),
      );
    }
    _checkAllToolCallsResolved(msg);
  }

  /// Mark a tool call as rejected, notify the agent, and check resolution.
  void _rejectToolCall(
    _PendingToolCall ptc,
    _UiMessage msg,
    String toolResult,
  ) {
    _submitToolResult(ptc, msg, toolResult);
    setState(() => ptc.status = _ToolCallStatus.rejected);
    _checkAllToolCallsResolved(msg);
  }

  Future<void> _confirmImport(_PendingToolCall ptc, _UiMessage msg) async {
    final courses = ptc.parsedCourses;
    if (courses == null || courses.isEmpty) return;

    final repo = ref.read(courseRepositoryProvider);
    final now = DateTime.now();
    final semesterId = ref.read(activeSemesterIdProvider).valueOrNull;

    if (semesterId == null) {
      _confirmToolCall(ptc, msg,
        '导入失败：尚未创建学期，请先在设置中创建学期。',
        '导入失败：无活跃学期',
      );
      return;
    }

    for (final parsed in courses) {
      await repo.save(Course(
        id: _uuid.v4(),
        name: parsed.name,
        location: parsed.location,
        teacher: parsed.teacher,
        weekday: parsed.weekday,
        startPeriod: parsed.startPeriod,
        endPeriod: parsed.endPeriod,
        weekMode: parsed.weekMode,
        customWeeks: parsed.customWeeks,
        semesterId: semesterId,
        createdAt: now,
        updatedAt: now,
      ));
    }

    ref.invalidate(watchCoursesProvider);
    refreshWidgets(ref);

    _confirmToolCall(ptc, msg,
      '已成功导入 ${courses.length} 门课程。',
      '已导入 ${courses.length} 门课程',
    );
  }

  void _rejectImport(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了导入操作。');
  }

  Future<void> _confirmUpdate(_PendingToolCall ptc, _UiMessage msg) async {
    final course = ptc.updateOriginalCourse;
    final fields = ptc.updateFields;
    if (course == null || fields == null) return;

    final updated = Course(
      id: course.id,
      name: (fields['name'] as String?) ?? course.name,
      location: (fields['location'] as String?) ?? course.location,
      teacher: (fields['teacher'] as String?) ?? course.teacher,
      weekday: (fields['weekday'] as int?) ?? course.weekday,
      startPeriod: (fields['startPeriod'] as int?) ?? course.startPeriod,
      endPeriod: (fields['endPeriod'] as int?) ?? course.endPeriod,
      weekMode: fields['weekMode'] != null
          ? _parseWeekMode(fields['weekMode'] as String)
          : course.weekMode,
      customWeeks: fields['customWeeks'] != null
          ? (fields['customWeeks'] as List<dynamic>)
              .map((e) => e as int)
              .toList()
          : course.customWeeks,
      color: course.color,
      semesterId: course.semesterId,
      createdAt: course.createdAt,
      updatedAt: DateTime.now(),
    );

    final repo = ref.read(courseRepositoryProvider);
    await repo.save(updated);
    ref.invalidate(watchCoursesProvider);
    refreshWidgets(ref);

    _confirmToolCall(ptc, msg,
      '已成功修改课程「${updated.name}」。',
      '已修改课程「${updated.name}」',
    );
  }

  void _rejectUpdate(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了修改操作。');
  }

  Future<void> _confirmDelete(_PendingToolCall ptc, _UiMessage msg) async {
    final courses = ptc.deleteCourses;
    if (courses == null || courses.isEmpty) return;

    final repo = ref.read(courseRepositoryProvider);
    for (final c in courses) {
      await repo.delete(c.id);
    }
    ref.invalidate(watchCoursesProvider);
    refreshWidgets(ref);

    final names = courses.map((c) => '「${c.name}」').join('、');
    _confirmToolCall(ptc, msg,
      '已成功删除 ${courses.length} 门课程：$names。',
      '已删除 ${courses.length} 门课程',
    );
  }

  void _rejectDelete(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了删除操作。');
  }

  // ===== set_current_week — pending confirmation =====
  void _prepareSetCurrentWeek(_PendingToolCall ptc, ChatToolCall tc) {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      ptc.setWeekNumber = args['weekNumber'] as int;
    } catch (e) {
      final agent = ref.read(aiAgentServiceProvider);
      agent?.addToolResult(tc.id, '解析周次参数失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  Future<void> _confirmSetCurrentWeek(
      _PendingToolCall ptc, _UiMessage msg) async {
    final weekNumber = ptc.setWeekNumber;
    if (weekNumber == null) return;

    final semester = ref.read(activeSemesterProvider);
    if (semester == null) {
      _confirmToolCall(ptc, msg, '当前没有活跃学期，无法设置周次。', '无活跃学期');
      return;
    }

    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final newStartDate =
        thisMonday.subtract(Duration(days: (weekNumber - 1) * 7));

    final updated = Semester(
      id: semester.id,
      name: semester.name,
      startDate: newStartDate,
      totalWeeks: semester.totalWeeks,
      createdAt: semester.createdAt,
    );
    await ref.read(semesterRepositoryProvider).save(updated);

    _confirmToolCall(ptc, msg,
        '已将第$weekNumber周设为本周。', '已设置第$weekNumber周');
  }

  void _rejectSetCurrentWeek(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了设置周次。');
  }

  // ===== Semester tools — auto-execute =====

  Future<void> _executeQuerySemesters({
    required _PendingToolCall ptc,
    required ChatToolCall tc,
    required AiAgentService agent,
  }) async {
    try {
      final semesters =
          await ref.read(semesterRepositoryProvider).watchAll().first;
      final activeId = ref.read(activeSemesterIdProvider).valueOrNull;

      final resultJson = jsonEncode(semesters
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'startDate': s.startDate.toIso8601String().split('T').first,
                'totalWeeks': s.totalWeeks,
                'currentWeek': s.currentWeek(),
                'isActive': s.id == activeId,
              })
          .toList());

      agent.addToolResult(
          tc.id, '查询到 ${semesters.length} 个学期：$resultJson');
      ptc.status = _ToolCallStatus.confirmed;
    } catch (e) {
      agent.addToolResult(tc.id, '查询学期失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  /// Auto-execute get_current_context (read-only).
  Future<void> _executeGetCurrentContext({
    required _PendingToolCall ptc,
    required ChatToolCall tc,
    required AiAgentService agent,
  }) async {
    try {
      final result = await fetchCurrentContext(
        weatherEnabled: ref.read(weatherEnabledProvider).valueOrNull ?? false,
        weatherService: await ref.read(weatherServiceProvider.future),
      );
      agent.addToolResult(tc.id, result);
      ptc.status = _ToolCallStatus.confirmed;
    } catch (e) {
      agent.addToolResult(tc.id, '获取上下文失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  /// Auto-execute get_time (read-only, no permissions needed).
  void _executeGetTime({
    required _PendingToolCall ptc,
    required ChatToolCall tc,
    required AiAgentService agent,
  }) {
    try {
      final now = DateTime.now();
      final timeFmt = DateFormat('yyyy-MM-dd HH:mm:ss (EEEE)', 'zh_CN');
      final buf = StringBuffer('当前时间：${timeFmt.format(now)}');

      // 当前周次
      final week = ref.read(currentWeekProvider);
      buf.write('\n当前学期：第$week周');

      // 当前节次
      final configAsync = ref.read(periodConfigProvider);
      final config = configAsync.valueOrNull;
      if (config != null && config.periods.isNotEmpty) {
        buf.write('\n当前节次：${_currentPeriodString(now, config)}');
      }

      agent.addToolResult(tc.id, buf.toString());
    } catch (e) {
      agent.addToolResult(tc.id, '获取时间失败: $e');
    }
    ptc.status = _ToolCallStatus.confirmed;
  }

  String _currentPeriodString(DateTime now, PeriodConfig config) {
    final nowMinutes = now.hour * 60 + now.minute;
    final periods = config.periods.toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    for (final p in periods) {
      final startMin = p.startHour * 60 + p.startMinute;
      final endMin = p.endHour * 60 + p.endMinute;
      if (nowMinutes < startMin) {
        return '第${p.periodNumber}节课前（${p.startTimeStr}开始）';
      }
      if (nowMinutes < endMin) {
        return '第${p.periodNumber}节（${p.startTimeStr}-${p.endTimeStr}）';
      }
    }
    return '今日课程已结束';
  }

  // ===== create_semester — pending confirmation =====
  void _prepareCreateSemester(_PendingToolCall ptc, ChatToolCall tc) {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      ptc.createSemesterFields = args;
    } catch (e) {
      final agent = ref.read(aiAgentServiceProvider);
      agent?.addToolResult(tc.id, '解析学期参数失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  Future<void> _confirmCreateSemester(
      _PendingToolCall ptc, _UiMessage msg) async {
    final args = ptc.createSemesterFields;
    if (args == null) return;

    final name = args['name'] as String;
    final startDateStr = args['startDate'] as String;
    final totalWeeks = (args['totalWeeks'] as int?) ?? 20;
    final setActive = (args['setActive'] as bool?) ?? true;

    final startDate = DateTime.parse(startDateStr);
    final id = _uuid.v4();

    final semester = Semester(
      id: id,
      name: name,
      startDate: startDate,
      totalWeeks: totalWeeks,
      createdAt: DateTime.now(),
    );

    await ref.read(semesterRepositoryProvider).save(semester);

    if (setActive) {
      final db = ref.read(appDatabaseProvider);
      await SettingsDao(db).setValue('activeSemesterId', id);
      ref.invalidate(activeSemesterIdProvider);
    }

    ref.invalidate(semestersProvider);

    _confirmToolCall(ptc, msg,
        '已创建学期「$name」${setActive ? '并设为活跃学期' : ''}。',
        '已创建学期「$name」');
  }

  void _rejectCreateSemester(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了创建学期。');
  }

  // ===== update_semester — pending confirmation =====
  Future<void> _prepareUpdateSemester(
      _PendingToolCall ptc, ChatToolCall tc) async {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      final semesterId = args['semesterId'] as String;

      final existing =
          await ref.read(semesterRepositoryProvider).findById(semesterId);
      if (existing == null) {
        final agent = ref.read(aiAgentServiceProvider);
        agent?.addToolResult(tc.id, '未找到 ID 为 $semesterId 的学期');
        ptc.status = _ToolCallStatus.confirmed;
        return;
      }

      ptc.updateSemesterOriginal = existing;
      ptc.updateSemesterFields = args;
    } catch (e) {
      final agent = ref.read(aiAgentServiceProvider);
      agent?.addToolResult(tc.id, '解析学期参数失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  Future<void> _confirmUpdateSemester(
      _PendingToolCall ptc, _UiMessage msg) async {
    final existing = ptc.updateSemesterOriginal;
    final args = ptc.updateSemesterFields;
    if (existing == null || args == null) return;

    final updated = Semester(
      id: existing.id,
      name: (args['name'] as String?) ?? existing.name,
      startDate: args['startDate'] != null
          ? DateTime.parse(args['startDate'] as String)
          : existing.startDate,
      totalWeeks: (args['totalWeeks'] as int?) ?? existing.totalWeeks,
      createdAt: existing.createdAt,
    );

    await ref.read(semesterRepositoryProvider).save(updated);
    ref.invalidate(semestersProvider);

    _confirmToolCall(ptc, msg,
        '已修改学期「${updated.name}」。', '已修改学期「${updated.name}」');
  }

  void _rejectUpdateSemester(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了修改学期。');
  }

  // ===== delete_semester — pending confirmation =====
  Future<void> _prepareDeleteSemester(
      _PendingToolCall ptc, ChatToolCall tc) async {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      final semesterId = args['semesterId'] as String;

      final existing =
          await ref.read(semesterRepositoryProvider).findById(semesterId);
      if (existing == null) {
        final agent = ref.read(aiAgentServiceProvider);
        agent?.addToolResult(tc.id, '未找到 ID 为 $semesterId 的学期');
        ptc.status = _ToolCallStatus.confirmed;
        return;
      }

      ptc.deleteSemester = existing;
    } catch (e) {
      final agent = ref.read(aiAgentServiceProvider);
      agent?.addToolResult(tc.id, '解析学期参数失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  Future<void> _confirmDeleteSemester(
      _PendingToolCall ptc, _UiMessage msg) async {
    final semester = ptc.deleteSemester;
    if (semester == null) return;

    // Delete all courses in this semester first
    final courseRepo = ref.read(courseRepositoryProvider);
    final allCourses = await courseRepo.watchAll().first;
    for (final c in allCourses) {
      if (c.semesterId == semester.id) {
        await courseRepo.delete(c.id);
      }
    }

    await ref.read(semesterRepositoryProvider).delete(semester.id);

    // If deleted semester was active, switch to another or clear
    final activeId = ref.read(activeSemesterIdProvider).valueOrNull;
    if (activeId == semester.id) {
      final remaining =
          await ref.read(semesterRepositoryProvider).watchAll().first;
      final db = ref.read(appDatabaseProvider);
      if (remaining.isNotEmpty) {
        await SettingsDao(db)
            .setValue('activeSemesterId', remaining.first.id);
      } else {
        await SettingsDao(db).deleteKey('activeSemesterId');
      }
      ref.invalidate(activeSemesterIdProvider);
    }

    ref.invalidate(semestersProvider);

    _confirmToolCall(ptc, msg,
        '已删除学期「${semester.name}」。', '已删除学期「${semester.name}」');
  }

  void _rejectDeleteSemester(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了删除学期。');
  }

  // ===== add_task — pending confirmation =====
  void _prepareAddTask(_PendingToolCall ptc, ChatToolCall tc) {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      ptc.addTaskFields = args;
    } catch (e) {
      final agent = ref.read(aiAgentServiceProvider);
      agent?.addToolResult(tc.id, '解析任务参数失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  Future<void> _confirmAddTask(_PendingToolCall ptc, _UiMessage msg) async {
    final fields = ptc.addTaskFields;
    if (fields == null) return;

    final now = DateTime.now();
    final priority = switch (fields['priority'] as String?) {
      'low' => Priority.low,
      'high' => Priority.high,
      _ => Priority.medium,
    };
    DateTime? dueDate;
    if (fields['dueDate'] != null) {
      dueDate = DateTime.tryParse(fields['dueDate'] as String);
    }

    final task = Task(
      id: _uuid.v4(),
      title: fields['title'] as String,
      description: fields['description'] as String?,
      priority: priority,
      dueDate: dueDate,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(taskRepositoryProvider).save(task);
    ref.invalidate(watchTasksProvider);

    _confirmToolCall(ptc, msg,
      '已成功添加任务「${task.title}」。',
      '已添加任务「${task.title}」',
    );
  }

  void _rejectAddTask(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了添加任务。');
  }

  // ===== add_reminder — pending confirmation =====
  void _prepareAddReminder(_PendingToolCall ptc, ChatToolCall tc) {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      ptc.addReminderFields = args;
    } catch (e) {
      final agent = ref.read(aiAgentServiceProvider);
      agent?.addToolResult(tc.id, '解析提醒参数失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  Future<void> _confirmAddReminder(_PendingToolCall ptc, _UiMessage msg) async {
    final fields = ptc.addReminderFields;
    if (fields == null) return;

    final scheduledAt = DateTime.parse(fields['scheduledAt'] as String);
    final now = DateTime.now();

    final reminder = Reminder(
      id: _uuid.v4(),
      title: fields['title'] as String,
      body: fields['body'] as String?,
      scheduledAt: scheduledAt,
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(reminderRepositoryProvider).save(reminder);
    // Schedule local notification for the new reminder.
    if (reminder.isActive && scheduledAt.isAfter(DateTime.now())) {
      await ref.read(notificationServiceProvider).schedule(reminder);
    }
    forwardReminderToTg(ref, reminder);
    ref.invalidate(watchRemindersProvider);

    final timeStr = '${scheduledAt.month}/${scheduledAt.day} ${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}';
    _confirmToolCall(ptc, msg,
      '已成功添加提醒「${reminder.title}」，将在 $timeStr 提醒。',
      '已添加提醒「${reminder.title}」',
    );
  }

  void _rejectAddReminder(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了添加提醒。');
  }

  // ===== query_reminders — auto execute =====
  Future<void> _executeQueryReminders({
    required _PendingToolCall ptc,
    required ChatToolCall tc,
    required AiAgentService agent,
  }) async {
    final repo = ref.read(reminderRepositoryProvider);
    final reminders = await repo.watchAll().first;

    if (reminders.isEmpty) {
      agent.addToolResult(tc.id, '当前没有任何提醒。');
    } else {
      final list = reminders.map((r) {
        final time = DateFormat('yyyy-MM-dd HH:mm').format(r.scheduledAt);
        return {
          'id': r.id,
          'title': r.title,
          if (r.body != null) 'body': r.body,
          'scheduledAt': time,
          'type': r.type.name,
          'isActive': r.isActive,
        };
      }).toList();
      agent.addToolResult(tc.id, jsonEncode(list));
    }
    ptc.status = _ToolCallStatus.confirmed;
  }

  // ===== update_reminder — pending confirmation =====
  Future<void> _prepareUpdateReminder(_PendingToolCall ptc, ChatToolCall tc) async {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      final reminderId = args['reminderId'] as String;
      final repo = ref.read(reminderRepositoryProvider);
      final original = await repo.findById(reminderId);
      if (original == null) {
        final agent = ref.read(aiAgentServiceProvider);
        agent?.addToolResult(tc.id, '找不到 ID 为 $reminderId 的提醒。');
        ptc.status = _ToolCallStatus.confirmed;
        return;
      }
      ptc.updateReminderOriginal = original;
      ptc.updateReminderFields = args;
    } catch (e) {
      final agent = ref.read(aiAgentServiceProvider);
      agent?.addToolResult(tc.id, '解析修改提醒参数失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  Future<void> _confirmUpdateReminder(_PendingToolCall ptc, _UiMessage msg) async {
    final original = ptc.updateReminderOriginal;
    final fields = ptc.updateReminderFields;
    if (original == null || fields == null) return;

    final updated = original.copyWith(
      title: fields['title'] as String? ?? original.title,
      body: fields.containsKey('body') ? () => fields['body'] as String? : null,
      scheduledAt: fields['scheduledAt'] != null
          ? DateTime.parse(fields['scheduledAt'] as String)
          : original.scheduledAt,
      updatedAt: DateTime.now(),
    );

    await ref.read(reminderRepositoryProvider).save(updated);
    // Sync notification: cancel old, schedule new if active and future.
    final ns = ref.read(notificationServiceProvider);
    await ns.cancel(updated.id);
    if (updated.isActive && updated.scheduledAt.isAfter(DateTime.now())) {
      await ns.schedule(updated);
    }
    ref.invalidate(watchRemindersProvider);

    _confirmToolCall(ptc, msg,
      '已修改提醒「${updated.title}」。',
      '已修改提醒「${updated.title}」',
    );
  }

  void _rejectUpdateReminder(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了修改提醒。');
  }

  // ===== delete_reminder — pending confirmation =====
  Future<void> _prepareDeleteReminder(_PendingToolCall ptc, ChatToolCall tc) async {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      final reminderId = args['reminderId'] as String;
      final repo = ref.read(reminderRepositoryProvider);
      final reminder = await repo.findById(reminderId);
      if (reminder == null) {
        final agent = ref.read(aiAgentServiceProvider);
        agent?.addToolResult(tc.id, '找不到 ID 为 $reminderId 的提醒。');
        ptc.status = _ToolCallStatus.confirmed;
        return;
      }
      ptc.deleteReminder = reminder;
    } catch (e) {
      final agent = ref.read(aiAgentServiceProvider);
      agent?.addToolResult(tc.id, '解析删除提醒参数失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  Future<void> _confirmDeleteReminder(_PendingToolCall ptc, _UiMessage msg) async {
    final reminder = ptc.deleteReminder;
    if (reminder == null) return;

    // Cancel notification before deleting the reminder.
    await ref.read(notificationServiceProvider).cancel(reminder.id);
    await ref.read(reminderRepositoryProvider).delete(reminder.id);
    ref.invalidate(watchRemindersProvider);

    _confirmToolCall(ptc, msg,
      '已删除提醒「${reminder.title}」。',
      '已删除提醒「${reminder.title}」',
    );
  }

  void _rejectDeleteReminder(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了删除提醒。');
  }

  // ===== set_period_times — pending confirmation =====
  void _prepareSetPeriodTimes(_PendingToolCall ptc, ChatToolCall tc) {
    try {
      final args = jsonDecode(tc.arguments) as Map<String, dynamic>;
      ptc.setPeriodTimesFields = args;
    } catch (e) {
      final agent = ref.read(aiAgentServiceProvider);
      agent?.addToolResult(tc.id, '解析节次时间参数失败: $e');
      ptc.status = _ToolCallStatus.confirmed;
    }
  }

  Future<void> _confirmSetPeriodTimes(_PendingToolCall ptc, _UiMessage msg) async {
    final fields = ptc.setPeriodTimesFields;
    if (fields == null) return;

    final periodsRaw = fields['periods'] as List<dynamic>;
    final totalPeriods = (fields['totalPeriods'] as int?) ?? periodsRaw.length;

    final periods = periodsRaw.map((p) {
      final m = p as Map<String, dynamic>;
      return PeriodTime(
        periodNumber: m['periodNumber'] as int,
        startHour: m['startHour'] as int,
        startMinute: m['startMinute'] as int,
        endHour: m['endHour'] as int,
        endMinute: m['endMinute'] as int,
      );
    }).toList();

    final config = PeriodConfig(
      totalPeriods: totalPeriods,
      periods: periods,
    );

    await ref.read(periodConfigRepositoryProvider).saveConfig(config);
    ref.invalidate(periodConfigProvider);

    _confirmToolCall(ptc, msg,
      '已成功设置 ${periods.length} 个节次的时间。',
      '已设置 ${periods.length} 个节次时间',
    );
  }

  void _rejectSetPeriodTimes(_PendingToolCall ptc, _UiMessage msg) {
    _rejectToolCall(ptc, msg, '用户拒绝了设置节次时间。');
  }

  /// Continue conversation after a tool result.
  void _continueAfterToolResult({
    required AiAgentService agent,
    required String sessionId,
    required ChatSessionDao dao,
    required CourseRepository repo,
  }) {
    final assistantMsg = _UiMessage(
      role: ChatRole.assistant,
      text: '',
      isStreaming: true,
    );

    _messages.add(assistantMsg);
    _isSending = true;
    _persistence.notify();
    if (mounted) _scrollToBottom();

    _startStreaming(
      agent: agent,
      assistantMsg: assistantMsg,
      sessionId: sessionId,
      dao: dao,
      repo: repo,
    );
  }

  WeekMode _parseWeekMode(String value) => switch (value) {
        'odd' => WeekMode.odd,
        'even' => WeekMode.even,
        'custom' => WeekMode.custom,
        _ => WeekMode.every,
      };

  void _startNewConversation() {
    _persistence.streamSub?.cancel();
    _persistence.streamSub = null;
    ref.read(aiAgentServiceProvider)?.clearHistory();
    ref.read(currentChatSessionIdProvider.notifier).state = null;
    setState(() {
      _messages.clear();
      _currentSessionId = null;
      _persistence.isLoadedFromDb = false;
      _isSending = false;
    });
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) {
            final sessionsAsync = ref.watch(chatSessionsProvider);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('对话历史',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Expanded(
                  child: sessionsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('错误: $e')),
                    data: (sessions) {
                      if (sessions.isEmpty) {
                        return const Center(child: Text('暂无历史记录'));
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: sessions.length,
                        itemBuilder: (_, i) {
                          final s = sessions[i];
                          final isActive = s.id == _currentSessionId;
                          return ListTile(
                            leading: Icon(
                              isActive
                                  ? Icons.chat_bubble
                                  : Icons.chat_bubble_outline,
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _formatDate(s.updatedAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () async {
                                final dao = ref.read(chatSessionDaoProvider);
                                await dao.deleteSession(s.id);
                                if (s.id == _currentSessionId) {
                                  _startNewConversation();
                                }
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _loadSession(s.id);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadSession(String sessionId) async {
    ref.read(aiAgentServiceProvider)?.clearHistory();
    ref.read(currentChatSessionIdProvider.notifier).state = sessionId;

    final dao = ref.read(chatSessionDaoProvider);
    final dbMessages = await dao.getMessages(sessionId);

    final agent = ref.read(aiAgentServiceProvider);
    if (agent != null) {
      final historyMaps = <Map<String, dynamic>>[];
      for (final m in dbMessages) {
        if (m.role == 'user') {
          historyMaps.add({'role': 'user', 'content': m.content ?? ''});
        } else if (m.role == 'assistant') {
          historyMaps.add({'role': 'assistant', 'content': m.content ?? ''});
        }
      }
      agent.restoreHistory(historyMaps);
    }

    if (mounted) {
      setState(() {
        _currentSessionId = sessionId;
        _messages.clear();
        for (final m in dbMessages) {
          List<AiParsedCourse>? courses;
          if (m.parsedCoursesJson != null) {
            try {
              courses = agent?.extractCourses(m.parsedCoursesJson!);
            } catch (_) {}
          }
          _messages.add(_UiMessage(
            id: m.id,
            role: m.role == 'user' ? ChatRole.user : ChatRole.assistant,
            text: m.content,
            imageFiles: ChatSessionDao.decodeImagePaths(m.imagePaths)
                .map((p) => File(p))
                .toList(),
            parsedCourses: courses,
          ));
        }
      });
      _scrollToBottom();
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '今天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static const _weekdayNames = [
    '',
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enterToSend = ref.watch(enterToSendProvider).valueOrNull ?? false;
    final voiceEnabled = ref.watch(voiceEnabledProvider).valueOrNull ?? false;
    // Eagerly watch so aiConfigProvider's future starts resolving immediately
    final agentReady = ref.watch(aiAgentServiceProvider) != null;
    final configLoading = ref.watch(aiConfigProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '对话历史',
            onPressed: _showHistory,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'new':
                  _startNewConversation();
                case 'clear':
                  ref.read(aiAgentServiceProvider)?.clearHistory();
                  setState(() => _messages.clear());
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'new',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('新建对话'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep),
                  title: Text('清空当前对话'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 48, color: theme.colorScheme.primary),
                          const SizedBox(height: 16),
                          Text('AI 课程助手',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            '发送课表文本、拍照或导入文件，AI 帮你自动识别课程\n'
                            '也可以让 AI 查询、修改、删除课程',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildMessage(_messages[i]),
                  ),
          ),
          if (!agentReady && _messages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                configLoading ? '正在加载 AI 配置...' : '请先在设置中配置 AI API',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          if (_pendingImages.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _pendingImages.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_pendingImages[i],
                            width: 70, height: 70, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _removePendingImage(i),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Input bar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: '更多',
                    enabled: !_isSending,
                    onSelected: (value) {
                      switch (value) {
                        case 'gallery':
                          _pickImage(ImageSource.gallery);
                        case 'camera':
                          _pickImage(ImageSource.camera);
                        case 'file':
                          _pickDocument();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'gallery',
                        child: ListTile(
                          leading: Icon(Icons.photo_library),
                          title: Text('选择图片'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'camera',
                        child: ListTile(
                          leading: Icon(Icons.camera_alt),
                          title: Text('拍照'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'file',
                        child: ListTile(
                          leading: Icon(Icons.attach_file),
                          title: Text('导入文件'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  if (voiceEnabled && !_isTranscribing && !_isRecording)
                    IconButton(
                      icon: const Icon(Icons.mic),
                      tooltip: '语音输入',
                      onPressed: _isSending ? null : _toggleRecording,
                    ),
                  if (_isTranscribing)
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_isRecording)
                    IconButton(
                      icon: Icon(
                        Icons.stop_circle,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: '停止录音',
                      onPressed: _toggleRecording,
                    ),
                  Expanded(
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: enterToSend
                          ? (event) {
                              if (event is KeyDownEvent &&
                                  event.logicalKey ==
                                      LogicalKeyboardKey.enter &&
                                  !HardwareKeyboard.instance.isShiftPressed) {
                                _send();
                              }
                            }
                          : null,
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: enterToSend
                              ? '输入消息，Enter 发送...'
                              : '输入文本或发送图片...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: enterToSend
                            ? TextInputAction.send
                            : TextInputAction.newline,
                        onSubmitted: enterToSend ? (_) => _send() : null,
                      ),
                    ),
                  ),
                  if (_isSending)
                    IconButton(
                      icon: const Icon(Icons.stop_circle),
                      tooltip: '停止生成',
                      color: theme.colorScheme.error,
                      onPressed: _cancelSending,
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _send,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_UiMessage msg) {
    final isUser = msg.role == ChatRole.user;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.imageFiles.isNotEmpty)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: msg.imageFiles
                    .map((f) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(f,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                    width: 150,
                                    height: 150,
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.broken_image),
                                  )),
                        ))
                    .toList(),
              ),
            // Tool call indicator
            if (msg.toolCalls != null && msg.toolCalls!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: msg.toolCalls!
                      .map((tc) {
                        final ptc = msg.pendingToolCalls
                            .cast<_PendingToolCall?>()
                            .firstWhere((p) => p!.id == tc.id,
                                orElse: () => null);
                        return _buildToolCallChip(tc, ptc, theme);
                      })
                      .toList(),
                ),
              ),
            if (msg.text != null && msg.text!.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: isUser
                          ? SelectableText(
                              msg.text!,
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : GptMarkdown(
                              msg.text!,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                    ),
                    if (msg.isStreaming) ...[
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            // Copy button for messages.
            if (msg.text != null &&
                msg.text!.isNotEmpty &&
                !msg.isStreaming)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  height: 28,
                  child: IconButton(
                    icon: Icon(
                      Icons.copy,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    constraints: const BoxConstraints(),
                    tooltip: '复制',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: msg.text!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Show streaming indicator for empty text
            if ((msg.text == null || msg.text!.isEmpty) && msg.isStreaming)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            // Per-tool-call confirm cards
            for (final ptc in msg.pendingToolCalls)
              _buildToolCallConfirmCard(ptc, msg, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCallChip(
      ChatToolCall tc, _PendingToolCall? ptc, ThemeData theme) {
    final status = ptc?.status;
    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final String label;

    final friendlyName = switch (tc.name) {
      'import_courses' => '导入课程',
      'query_courses' => '查询课程',
      'update_course' => '修改课程',
      'delete_courses' => '删除课程',
      'set_current_week' => '设置本周',
      'add_task' => '添加任务',
      'add_reminder' => '添加提醒',
      'query_reminders' => '查询提醒',
      'update_reminder' => '修改提醒',
      'delete_reminder' => '删除提醒',
      'set_period_times' => '设置节次时间',
      'query_semesters' => '查询学期',
      'create_semester' => '创建学期',
      'update_semester' => '修改学期',
      'delete_semester' => '删除学期',
      'get_time' => '获取时间',
      _ => tc.name,
    };

    if (status == _ToolCallStatus.confirmed) {
      bgColor = theme.colorScheme.primaryContainer;
      fgColor = theme.colorScheme.onPrimaryContainer;
      icon = Icons.check_circle;
      label = '$friendlyName (已确认)';
    } else if (status == _ToolCallStatus.rejected) {
      bgColor = theme.colorScheme.errorContainer;
      fgColor = theme.colorScheme.onErrorContainer;
      icon = Icons.cancel;
      label = '$friendlyName (已拒绝)';
    } else {
      bgColor = theme.colorScheme.tertiaryContainer;
      fgColor = theme.colorScheme.onTertiaryContainer;
      icon = Icons.build;
      label = friendlyName;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: fgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dispatch to the correct confirm card based on tool call type.
  Widget _buildToolCallConfirmCard(
      _PendingToolCall ptc, _UiMessage msg, ThemeData theme) {
    // Skip auto-executed tools (they have no confirmation UI)
    switch (ptc.name) {
      case 'import_courses':
        if (ptc.parsedCourses != null && ptc.parsedCourses!.isNotEmpty) {
          return _buildCourseConfirmCard(ptc, msg, theme);
        }
      case 'update_course':
        if (ptc.updateOriginalCourse != null) {
          return _buildUpdateConfirmCard(ptc, msg, theme);
        }
      case 'delete_courses':
        if (ptc.deleteCourses != null && ptc.deleteCourses!.isNotEmpty) {
          return _buildDeleteConfirmCard(ptc, msg, theme);
        }
      case 'add_task':
        if (ptc.addTaskFields != null) {
          return _buildAddTaskConfirmCard(ptc, msg, theme);
        }
      case 'add_reminder':
        if (ptc.addReminderFields != null) {
          return _buildAddReminderConfirmCard(ptc, msg, theme);
        }
      case 'update_reminder':
        if (ptc.updateReminderOriginal != null) {
          return _buildUpdateReminderConfirmCard(ptc, msg, theme);
        }
      case 'delete_reminder':
        if (ptc.deleteReminder != null) {
          return _buildDeleteReminderConfirmCard(ptc, msg, theme);
        }
      case 'set_period_times':
        if (ptc.setPeriodTimesFields != null) {
          return _buildSetPeriodTimesConfirmCard(ptc, msg, theme);
        }
      case 'set_current_week':
        if (ptc.setWeekNumber != null) {
          return _buildSimpleConfirmCard(
            ptc, msg, theme,
            icon: Icons.date_range,
            title: '设置当前周',
            detail: '将第 ${ptc.setWeekNumber} 周设为本周',
            onConfirm: () => _confirmSetCurrentWeek(ptc, msg),
            onReject: () => _rejectSetCurrentWeek(ptc, msg),
          );
        }
      case 'create_semester':
        if (ptc.createSemesterFields != null) {
          final f = ptc.createSemesterFields!;
          return _buildSimpleConfirmCard(
            ptc, msg, theme,
            icon: Icons.school,
            title: '创建学期',
            detail: '「${f['name']}」共 ${f['totalWeeks'] ?? 20} 周',
            onConfirm: () => _confirmCreateSemester(ptc, msg),
            onReject: () => _rejectCreateSemester(ptc, msg),
          );
        }
      case 'update_semester':
        if (ptc.updateSemesterOriginal != null) {
          return _buildSimpleConfirmCard(
            ptc, msg, theme,
            icon: Icons.edit_calendar,
            title: '修改学期',
            detail: '「${ptc.updateSemesterOriginal!.name}」',
            onConfirm: () => _confirmUpdateSemester(ptc, msg),
            onReject: () => _rejectUpdateSemester(ptc, msg),
          );
        }
      case 'delete_semester':
        if (ptc.deleteSemester != null) {
          return _buildSimpleConfirmCard(
            ptc, msg, theme,
            icon: Icons.delete_forever,
            title: '删除学期',
            detail: '「${ptc.deleteSemester!.name}」及其所有课程',
            onConfirm: () => _confirmDeleteSemester(ptc, msg),
            onReject: () => _rejectDeleteSemester(ptc, msg),
          );
        }
    }
    return const SizedBox.shrink();
  }

  /// Generic confirmation card for simple write operations.
  Widget _buildSimpleConfirmCard(
    _PendingToolCall ptc,
    _UiMessage msg,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String detail,
    required VoidCallback onConfirm,
    required VoidCallback onReject,
  }) {
    final status = ptc.status;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == _ToolCallStatus.confirmed
                        ? Icons.check_circle
                        : status == _ToolCallStatus.rejected
                            ? Icons.cancel
                            : icon,
                    size: 18,
                    color: status == _ToolCallStatus.confirmed
                        ? theme.colorScheme.primary
                        : status == _ToolCallStatus.rejected
                            ? theme.colorScheme.error
                            : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == _ToolCallStatus.confirmed
                        ? '$title (已确认)'
                        : status == _ToolCallStatus.rejected
                            ? '$title (已拒绝)'
                            : title,
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(detail, style: theme.textTheme.bodySmall),
              ),
              if (status == _ToolCallStatus.pending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('确认'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('拒绝'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseConfirmCard(_PendingToolCall ptc, _UiMessage msg, ThemeData theme) {
    final status = ptc.status;
    final courses = ptc.parsedCourses!;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == _ToolCallStatus.confirmed
                        ? Icons.check_circle
                        : status == _ToolCallStatus.rejected
                            ? Icons.cancel
                            : Icons.school,
                    size: 18,
                    color: status == _ToolCallStatus.confirmed
                        ? theme.colorScheme.primary
                        : status == _ToolCallStatus.rejected
                            ? theme.colorScheme.error
                            : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == _ToolCallStatus.confirmed
                        ? '已导入 ${courses.length} 门课程'
                        : status == _ToolCallStatus.rejected
                            ? '已拒绝导入'
                            : '识别到 ${courses.length} 门课程',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...courses.map((c) => Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      '${c.name} · ${_weekdayNames[c.weekday]} '
                      '第${c.startPeriod}-${c.endPeriod}节'
                      '${c.location != null ? ' · ${c.location}' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                  )),
              if (status == _ToolCallStatus.pending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _confirmImport(ptc, msg),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('确认导入'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _rejectImport(ptc, msg),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('拒绝'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateConfirmCard(_PendingToolCall ptc, _UiMessage msg, ThemeData theme) {
    final status = ptc.status;
    final course = ptc.updateOriginalCourse!;
    final fields = ptc.updateFields ?? {};

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == _ToolCallStatus.confirmed
                        ? Icons.check_circle
                        : status == _ToolCallStatus.rejected
                            ? Icons.cancel
                            : Icons.edit,
                    size: 18,
                    color: status == _ToolCallStatus.confirmed
                        ? theme.colorScheme.primary
                        : status == _ToolCallStatus.rejected
                            ? theme.colorScheme.error
                            : theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == _ToolCallStatus.confirmed
                        ? '已修改课程「${course.name}」'
                        : status == _ToolCallStatus.rejected
                            ? '已拒绝修改'
                            : '修改课程「${course.name}」',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final entry in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    '${_fieldLabel(entry.key)}: ${_fieldOldValue(course, entry.key)} → ${entry.value}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (status == _ToolCallStatus.pending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _confirmUpdate(ptc, msg),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('确认修改'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _rejectUpdate(ptc, msg),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('拒绝'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteConfirmCard(_PendingToolCall ptc, _UiMessage msg, ThemeData theme) {
    final status = ptc.status;
    final courses = ptc.deleteCourses!;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        color: status == _ToolCallStatus.pending
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == _ToolCallStatus.confirmed
                        ? Icons.check_circle
                        : status == _ToolCallStatus.rejected
                            ? Icons.cancel
                            : Icons.delete_forever,
                    size: 18,
                    color: status == _ToolCallStatus.confirmed
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == _ToolCallStatus.confirmed
                        ? '已删除 ${courses.length} 门课程'
                        : status == _ToolCallStatus.rejected
                            ? '已拒绝删除'
                            : '删除 ${courses.length} 门课程',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final c in courses)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    '${c.name} · ${_weekdayNames[c.weekday]} '
                    '第${c.startPeriod}-${c.endPeriod}节'
                    '${c.location != null ? ' · ${c.location}' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (status == _ToolCallStatus.pending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _confirmDelete(ptc, msg),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('确认删除'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _rejectDelete(ptc, msg),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('拒绝'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddTaskConfirmCard(_PendingToolCall ptc, _UiMessage msg, ThemeData theme) {
    final status = ptc.status;
    final fields = ptc.addTaskFields!;
    final title = fields['title'] as String? ?? '';
    final description = fields['description'] as String?;
    final priority = fields['priority'] as String?;
    final dueDate = fields['dueDate'] as String?;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == _ToolCallStatus.confirmed
                        ? Icons.check_circle
                        : status == _ToolCallStatus.rejected
                            ? Icons.cancel
                            : Icons.task_alt,
                    size: 18,
                    color: status == _ToolCallStatus.confirmed
                        ? theme.colorScheme.primary
                        : status == _ToolCallStatus.rejected
                            ? theme.colorScheme.error
                            : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == _ToolCallStatus.confirmed
                        ? '已添加任务'
                        : status == _ToolCallStatus.rejected
                            ? '已拒绝添加任务'
                            : '添加任务',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('标题: $title', style: theme.textTheme.bodySmall),
              if (description != null)
                Text('描述: $description', style: theme.textTheme.bodySmall),
              if (priority != null)
                Text(
                    '优先级: ${switch (priority) { 'high' => '高', 'low' => '低', _ => '中' }}',
                    style: theme.textTheme.bodySmall),
              if (dueDate != null)
                Text('截止: $dueDate', style: theme.textTheme.bodySmall),
              if (status == _ToolCallStatus.pending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _confirmAddTask(ptc, msg),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('确认添加'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _rejectAddTask(ptc, msg),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('拒绝'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddReminderConfirmCard(_PendingToolCall ptc, _UiMessage msg, ThemeData theme) {
    final status = ptc.status;
    final fields = ptc.addReminderFields!;
    final title = fields['title'] as String? ?? '';
    final body = fields['body'] as String?;
    final scheduledAt = fields['scheduledAt'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == _ToolCallStatus.confirmed
                        ? Icons.check_circle
                        : status == _ToolCallStatus.rejected
                            ? Icons.cancel
                            : Icons.notifications_active,
                    size: 18,
                    color: status == _ToolCallStatus.confirmed
                        ? theme.colorScheme.primary
                        : status == _ToolCallStatus.rejected
                            ? theme.colorScheme.error
                            : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == _ToolCallStatus.confirmed
                        ? '已添加提醒'
                        : status == _ToolCallStatus.rejected
                            ? '已拒绝添加提醒'
                            : '添加提醒',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('标题: $title', style: theme.textTheme.bodySmall),
              if (body != null)
                Text('内容: $body', style: theme.textTheme.bodySmall),
              Text('提醒时间: $scheduledAt', style: theme.textTheme.bodySmall),
              if (status == _ToolCallStatus.pending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _confirmAddReminder(ptc, msg),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('确认添加'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _rejectAddReminder(ptc, msg),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('拒绝'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateReminderConfirmCard(_PendingToolCall ptc, _UiMessage msg, ThemeData theme) {
    final status = ptc.status;
    final original = ptc.updateReminderOriginal!;
    final fields = ptc.updateReminderFields!;
    final newTitle = fields['title'] as String? ?? original.title;
    final newBody = fields.containsKey('body') ? fields['body'] as String? : original.body;
    final newScheduledAt = fields['scheduledAt'] as String?;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == _ToolCallStatus.confirmed
                        ? Icons.check_circle
                        : status == _ToolCallStatus.rejected
                            ? Icons.cancel
                            : Icons.edit_notifications,
                    size: 18,
                    color: status == _ToolCallStatus.confirmed
                        ? theme.colorScheme.primary
                        : status == _ToolCallStatus.rejected
                            ? theme.colorScheme.error
                            : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == _ToolCallStatus.confirmed
                        ? '已修改提醒'
                        : status == _ToolCallStatus.rejected
                            ? '已拒绝修改提醒'
                            : '修改提醒',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (newTitle != original.title)
                Text('标题: ${original.title} → $newTitle', style: theme.textTheme.bodySmall),
              if (newTitle == original.title)
                Text('标题: $newTitle', style: theme.textTheme.bodySmall),
              if (newBody != original.body && newBody != null)
                Text('内容: $newBody', style: theme.textTheme.bodySmall),
              if (newScheduledAt != null)
                Text('提醒时间: ${DateFormat('yyyy-MM-dd HH:mm').format(original.scheduledAt)} → $newScheduledAt', style: theme.textTheme.bodySmall),
              if (status == _ToolCallStatus.pending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _confirmUpdateReminder(ptc, msg),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('确认修改'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _rejectUpdateReminder(ptc, msg),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('拒绝'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteReminderConfirmCard(_PendingToolCall ptc, _UiMessage msg, ThemeData theme) {
    final status = ptc.status;
    final reminder = ptc.deleteReminder!;
    final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(reminder.scheduledAt);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == _ToolCallStatus.confirmed
                        ? Icons.check_circle
                        : status == _ToolCallStatus.rejected
                            ? Icons.cancel
                            : Icons.notifications_off,
                    size: 18,
                    color: status == _ToolCallStatus.confirmed
                        ? theme.colorScheme.primary
                        : status == _ToolCallStatus.rejected
                            ? theme.colorScheme.error
                            : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == _ToolCallStatus.confirmed
                        ? '已删除提醒'
                        : status == _ToolCallStatus.rejected
                            ? '已拒绝删除提醒'
                            : '删除提醒',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('标题: ${reminder.title}', style: theme.textTheme.bodySmall),
              if (reminder.body != null)
                Text('内容: ${reminder.body}', style: theme.textTheme.bodySmall),
              Text('提醒时间: $timeStr', style: theme.textTheme.bodySmall),
              if (status == _ToolCallStatus.pending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _confirmDeleteReminder(ptc, msg),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('确认删除'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _rejectDeleteReminder(ptc, msg),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('取消'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetPeriodTimesConfirmCard(_PendingToolCall ptc, _UiMessage msg, ThemeData theme) {
    final status = ptc.status;
    final fields = ptc.setPeriodTimesFields!;
    final periodsRaw = fields['periods'] as List<dynamic>;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    status == _ToolCallStatus.confirmed
                        ? Icons.check_circle
                        : status == _ToolCallStatus.rejected
                            ? Icons.cancel
                            : Icons.schedule,
                    size: 18,
                    color: status == _ToolCallStatus.confirmed
                        ? theme.colorScheme.primary
                        : status == _ToolCallStatus.rejected
                            ? theme.colorScheme.error
                            : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == _ToolCallStatus.confirmed
                        ? '已设置 ${periodsRaw.length} 个节次时间'
                        : status == _ToolCallStatus.rejected
                            ? '已拒绝设置节次时间'
                            : '设置 ${periodsRaw.length} 个节次时间',
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...periodsRaw.take(6).map((p) {
                final m = p as Map<String, dynamic>;
                final n = m['periodNumber'];
                final sh = (m['startHour'] as int).toString().padLeft(2, '0');
                final sm =
                    (m['startMinute'] as int).toString().padLeft(2, '0');
                final eh = (m['endHour'] as int).toString().padLeft(2, '0');
                final em = (m['endMinute'] as int).toString().padLeft(2, '0');
                return Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text('第$n节: $sh:$sm - $eh:$em',
                      style: theme.textTheme.bodySmall),
                );
              }),
              if (periodsRaw.length > 6)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('...还有 ${periodsRaw.length - 6} 个节次',
                      style: theme.textTheme.bodySmall),
                ),
              if (status == _ToolCallStatus.pending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _confirmSetPeriodTimes(ptc, msg),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('确认设置'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _rejectSetPeriodTimes(ptc, msg),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('拒绝'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fieldLabel(String key) => switch (key) {
        'name' => '课程名',
        'location' => '地点',
        'teacher' => '教师',
        'weekday' => '星期',
        'startPeriod' => '开始节次',
        'endPeriod' => '结束节次',
        'weekMode' => '周模式',
        'customWeeks' => '自定义周次',
        _ => key,
      };

  String _fieldOldValue(Course course, String key) => switch (key) {
        'name' => course.name,
        'location' => course.location ?? '无',
        'teacher' => course.teacher ?? '无',
        'weekday' => _weekdayNames[course.weekday],
        'startPeriod' => '${course.startPeriod}',
        'endPeriod' => '${course.endPeriod}',
        'weekMode' => course.weekMode.name,
        'customWeeks' => course.customWeeks.toString(),
        _ => '?',
      };
}

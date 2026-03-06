import '../entities/ai_parsed_course.dart';

/// Represents a single message in a chat with the AI agent.
class ChatMessage {
  final ChatRole role;
  final String? text;
  final List<ChatImage> images;
  final List<AiParsedCourse>? parsedCourses;
  final List<ChatToolCall>? toolCalls;

  const ChatMessage({
    required this.role,
    this.text,
    this.images = const [],
    this.parsedCourses,
    this.toolCalls,
  });
}

enum ChatRole { user, assistant, system }

/// An image attachment in a chat message.
class ChatImage {
  /// base64-encoded image data
  final String base64Data;
  final String mimeType;

  const ChatImage({required this.base64Data, required this.mimeType});
}

/// Represents a tool/function call made by the AI.
class ChatToolCall {
  final String id;
  final String name;
  final String arguments;

  const ChatToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

/// A streaming delta event from the AI.
class ChatStreamDelta {
  /// Partial text content appended to the response.
  final String? textDelta;

  /// Tool call deltas (partial tool call info).
  final List<ChatToolCall>? toolCallDeltas;

  /// Whether this is the final event (stream done).
  final bool isDone;

  const ChatStreamDelta({
    this.textDelta,
    this.toolCallDeltas,
    this.isDone = false,
  });
}

/// AI Agent service that maintains conversation context and supports
/// multi-modal input (text + images).
abstract interface class AiAgentService {
  /// Send a message and get a complete response.
  Future<ChatMessage> send({
    String? text,
    List<ChatImage> images,
    String? extraPrompt,
  });

  /// Send a message and stream the response token by token.
  Stream<ChatStreamDelta> sendStreaming({
    String? text,
    List<ChatImage> images,
    String? extraPrompt,
  });

  /// Cancel the current in-flight request.
  void cancel();

  /// Whether the agent is currently processing a request.
  bool get isBusy;

  /// Try to extract structured course data from the last assistant response.
  List<AiParsedCourse> extractCourses(String assistantText);

  /// Parse courses from a tool call's arguments JSON.
  List<AiParsedCourse> parseCoursesFromToolCall(String arguments);

  /// Add a tool result to the conversation history (after user confirms/rejects).
  void addToolResult(String toolCallId, String result);

  /// Clear conversation history.
  void clearHistory();

  /// Restore conversation history from raw message maps (for session loading).
  void restoreHistory(List<Map<String, dynamic>> history);

  /// Get the raw conversation history (for session saving).
  List<Map<String, dynamic>> get history;
}

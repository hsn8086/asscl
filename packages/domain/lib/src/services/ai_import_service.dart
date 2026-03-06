import '../entities/ai_parsed_course.dart';

abstract interface class AiImportService {
  Future<List<AiParsedCourse>> parseText(
    String rawText, {
    String? extraPrompt,
  });
}

/// Speech-to-text service interface.
abstract interface class SttService {
  /// Transcribe an audio file to text.
  ///
  /// [filePath] is the local path to the audio file.
  /// [language] is an optional language hint (e.g. 'zh', 'en').
  Future<String> transcribe({
    required String filePath,
    String? language,
  });
}

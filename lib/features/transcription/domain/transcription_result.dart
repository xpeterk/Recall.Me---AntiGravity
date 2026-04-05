class TranscriptionResult {
  final String text;
  final bool isFinal;

  final double confidence;

  TranscriptionResult({
    required this.text,
    required this.isFinal,
    this.confidence = 1.0,
  });
}

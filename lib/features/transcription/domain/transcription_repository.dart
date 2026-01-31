import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

import 'transcription_result.dart';

abstract class TranscriptionRepository {
  /// Initializes the speech engine. Returns true if available.
  Future<Either<Failure, bool>> initialize();

  /// Starts listening for speech.
  /// Text updates should be pushed to the [transcriptionStream].
  Future<Either<Failure, void>> startListening();

  /// Stops listening.
  Future<Either<Failure, void>> stopListening();

  /// Stream of recognized text results.
  Stream<TranscriptionResult> get transcriptionStream;
  
  /// Stream of listening status (true = listening, false = idle).
  Stream<bool> get isListeningStream;

  /// Stream of sound level (dB or normalized 0-1).
  Stream<double> get soundLevelStream;
}

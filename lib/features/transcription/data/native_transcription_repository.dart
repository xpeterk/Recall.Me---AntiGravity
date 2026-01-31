import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../../core/errors/failures.dart';
import '../domain/transcription_repository.dart';
import '../domain/transcription_result.dart';

class NativeTranscriptionRepository implements TranscriptionRepository {
  final SpeechToText _speechToText = SpeechToText();
  final _transcriptionStreamController = StreamController<TranscriptionResult>.broadcast();
  final _isListeningController = StreamController<bool>.broadcast();
  final _soundLevelController = StreamController<double>.broadcast();
  
  bool _isInitialized = false;
  static const platform = MethodChannel('com.recall_me.native/audio');

  Future<void> startBackgroundService() async {
    try {
      await platform.invokeMethod('startService');
    } on PlatformException catch (e) {
      print("Failed to start service: '${e.message}'.");
    }
  }

  Future<void> stopBackgroundService() async {
    try {
      await platform.invokeMethod('stopService');
    } on PlatformException catch (e) {
       print("Failed to stop service: '${e.message}'.");
    }
  }

  @override
  Stream<TranscriptionResult> get transcriptionStream => _transcriptionStreamController.stream;

  @override
  Stream<bool> get isListeningStream => _isListeningController.stream;

  @override
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  @override
  Future<Either<Failure, bool>> initialize() async {
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          // Ignore timeout errors as they are part of the continuous loop
          if (error.errorMsg != 'error_speech_timeout' && error.errorMsg != 'error_no_match') {
            print('STT Error: $error');
          }
        },
        onStatus: (status) {
           bool isListening = status == 'listening';
           _isListeningController.add(isListening);
        },
      );
      return Right(_isInitialized);
    } catch (e) {
      return Left(VoiceFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> startListening() async {
    if (!_isInitialized) {
       // Try initializing if not ready
       final initResult = await initialize();
       if (initResult.isLeft()) return initResult;
    }

    // Retry logic for 'error_busy'
    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        await _speechToText.listen(
          onResult: (result) {
            _transcriptionStreamController.add(TranscriptionResult(
              text: result.recognizedWords,
              isFinal: result.finalResult,
            ));
          },
          onSoundLevelChange: (level) {
            _soundLevelController.add(level);
          },
          listenFor: const Duration(hours: 1), 
          pauseFor: const Duration(minutes: 30), // Effectively ignore silence timeouts
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        );
        return const Right(null);
      } catch (e) {
        if (e.toString().contains('error_busy') && retries < maxRetries - 1) {
          retries++;
           print("STT Busy. Retrying in 100ms... (Attempt $retries)");
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }
        
        // If critical client error, try re-initializing
        if (e.toString().contains('error_client')) {
           print("STT Client Error. Re-initializing...");
           _isInitialized = false; // Force re-init on next loop or call
           await initialize();
           if (retries < maxRetries - 1) {
              retries++;
              continue;
           }
        }
        
        return Left(VoiceFailure(e.toString()));
      }
    }
    return Left(VoiceFailure("Failed to start listening after $maxRetries retries."));
  }

  @override
  Future<Either<Failure, void>> stopListening() async {
    try {
      await _speechToText.stop();
      return const Right(null);
    } catch (e) {
      return Left(VoiceFailure(e.toString()));
    }
  }
}

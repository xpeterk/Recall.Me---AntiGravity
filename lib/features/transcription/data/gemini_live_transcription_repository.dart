import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../../../core/errors/failures.dart';
import '../../settings/domain/settings_repository.dart';
import '../../settings/data/native_settings_repository.dart';
import '../domain/transcription_repository.dart';
import '../domain/transcription_result.dart';

class GeminiLiveTranscriptionRepository implements TranscriptionRepository {
  final SettingsRepository _settingsRepository;
  final AudioRecorder _audioRecorder = AudioRecorder();

  final _transcriptionStreamController = StreamController<TranscriptionResult>.broadcast();
  final _isListeningController = StreamController<bool>.broadcast();
  final _soundLevelController = StreamController<double>.broadcast();

  WebSocket? _webSocket;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription? _webSocketSubscription;
  
  bool _isListening = false;
  String _currentAccumulatedText = "";
  List<String> _customVocabulary = [];

  GeminiLiveTranscriptionRepository({
    SettingsRepository? settingsRepository,
  }) : _settingsRepository = settingsRepository ?? NativeSettingsRepository();

  void setCustomVocabulary(List<String> vocabulary) {
    _customVocabulary = vocabulary;
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
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        await Permission.microphone.request();
      }
      return const Right(true);
    } catch (e) {
      return Left(VoiceFailure("Initialization failed: ${e.toString()}"));
    }
  }

  @override
  Future<Either<Failure, void>> startListening() async {
    if (_isListening) return const Right(null);

    try {
      // 1. Get API Key (Check settings first, fallback to dotenv)
      String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      final keyResult = await _settingsRepository.getApiKey('gemini');
      keyResult.fold((_) {}, (k) {
        if (k.trim().isNotEmpty) apiKey = k.trim();
      });

      if (apiKey.isEmpty) {
        print("DEBUG: Gemini API Key missing!");
        return const Left(PermissionFailure("Gemini API Key is missing. Please add it in Settings."));
      }

      // 2. Request / Verify microphone permission
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      if (!status.isGranted) {
        print("DEBUG: Microphone permission not granted: $status");
        return const Left(PermissionFailure("Microphone permission denied."));
      }

      _currentAccumulatedText = "";
      _isListening = true;
      _isListeningController.add(true);

      // 3. Start PCM Audio Recording Stream
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      final audioStream = await _audioRecorder.startStream(config);
      print("DEBUG: Audio recording stream started successfully");

      _audioStreamSubscription = audioStream.listen((Uint8List chunk) {
        if (!_isListening) return;

        // Calculate sound level for UI wave visualizer
        _calculateSoundLevel(chunk);

        // Send audio to WebSocket if connected
        if (_webSocket != null) {
          final base64Chunk = base64Encode(chunk);
          final realtimeMessage = {
            "realtimeInput": {
              "mediaChunks": [
                {
                  "mimeType": "audio/pcm;rate=16000",
                  "data": base64Chunk,
                }
              ]
            }
          };

          try {
            _webSocket?.add(jsonEncode(realtimeMessage));
          } catch (e) {
            print("DEBUG: Error sending audio chunk: $e");
          }
        }
      });

      // 4. Connect to Gemini Live WebSocket endpoint (v1alpha)
      final wsUrl = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$apiKey',
      );

      print("DEBUG: Connecting to Gemini Live WebSocket: ${wsUrl.host}...");
      try {
        _webSocket = await WebSocket.connect(wsUrl.toString()).timeout(const Duration(seconds: 8));
        print("DEBUG: Gemini Live WebSocket connected!");
      } catch (wsErr) {
        print("DEBUG: WebSocket connection failed: $wsErr. Trying v1beta fallback...");
        final fallbackUrl = Uri.parse(
          'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=$apiKey',
        );
        _webSocket = await WebSocket.connect(fallbackUrl.toString()).timeout(const Duration(seconds: 8));
        print("DEBUG: Gemini Live WebSocket connected via v1beta!");
      }

      // 5. Send Initial Setup Frame
      String prompt = "You are a real-time speech-to-text transcriber. Transcribe the user's spoken audio directly into clean, properly punctuated and capitalized text in real time. Automatically filter out and remove verbal fillers, stutters, and hesitation sounds such as 'uh', 'um', 'er', 'ah', 'uhm', 'umm', and false starts. Output only clean, fluent spoken words.";
      if (_customVocabulary.isNotEmpty) {
        prompt += "\nCustom vocabulary keywords and context terms: ${_customVocabulary.join(', ')}.";
      }

      final setupMessage = {
        "setup": {
          "model": "models/gemini-3.5-transcribe-live",
          "generationConfig": {
            "responseModalities": ["TEXT"],
            "temperature": 0.0,
          },
          "systemInstruction": {
            "parts": [
              {"text": prompt}
            ]
          }
        }
      };

      _webSocket?.add(jsonEncode(setupMessage));
      print("DEBUG: Gemini Live setup frame sent");

      // 6. Listen to responses from Gemini
      _webSocketSubscription = _webSocket?.listen(
        (data) {
          try {
            final json = jsonDecode(data is String ? data : utf8.decode(data));
            print("DEBUG: Gemini Live response: $json");
            
            if (json['serverContent'] != null) {
              final serverContent = json['serverContent'];

              // 1. Final user transcription
              if (serverContent['inputTranscription'] != null && serverContent['inputTranscription']['text'] != null) {
                final rawText = (serverContent['inputTranscription']['text'] as String).trim();
                final text = _cleanDisfluencies(rawText);
                if (text.isNotEmpty) {
                  _transcriptionStreamController.add(TranscriptionResult(
                    text: text,
                    isFinal: true,
                    confidence: 0.99,
                  ));
                }
              }
              // 2. Interim / Real-time live user transcription
              else if (serverContent['interimInputTranscription'] != null && serverContent['interimInputTranscription']['text'] != null) {
                final rawText = (serverContent['interimInputTranscription']['text'] as String).trim();
                final text = _cleanDisfluencies(rawText);
                if (text.isNotEmpty) {
                  _transcriptionStreamController.add(TranscriptionResult(
                    text: text,
                    isFinal: false,
                    confidence: 0.98,
                  ));
                }
              }
              // 3. Model turn fallback
              else if (serverContent['modelTurn'] != null && serverContent['modelTurn']['parts'] != null) {
                final parts = serverContent['modelTurn']['parts'] as List;
                for (var part in parts) {
                  if (part['text'] != null) {
                    final textChunk = part['text'] as String;
                    _currentAccumulatedText += textChunk;
                    _transcriptionStreamController.add(TranscriptionResult(
                      text: _currentAccumulatedText.trim(),
                      isFinal: false,
                      confidence: 0.98,
                    ));
                  }
                }

                final turnComplete = serverContent['turnComplete'] == true;
                if (turnComplete && _currentAccumulatedText.trim().isNotEmpty) {
                  _transcriptionStreamController.add(TranscriptionResult(
                    text: _currentAccumulatedText.trim(),
                    isFinal: true,
                    confidence: 0.99,
                  ));
                  _currentAccumulatedText = "";
                }
              }
            }
          } catch (e) {
            print("DEBUG: Gemini Live parse error: $e");
          }
        },
        onError: (err) {
          print("DEBUG: Gemini Live WebSocket error: $err");
          stopListening();
        },
        onDone: () {
          print("DEBUG: Gemini Live WebSocket closed");
          if (_isListening) {
            stopListening();
          }
        },
      );

      return const Right(null);
    } catch (e) {
      print("DEBUG: startListening failed with exception: $e");
      _isListening = false;
      _isListeningController.add(false);
      return Left(VoiceFailure("Gemini Live STT error: ${e.toString()}"));
    }
  }

  void _calculateSoundLevel(Uint8List bytes) {
    if (bytes.length < 2) return;
    int sum = 0;
    int count = bytes.length ~/ 2;
    for (int i = 0; i < bytes.length - 1; i += 2) {
      int sample = bytes[i] | (bytes[i + 1] << 8);
      if (sample >= 32768) sample -= 65536;
      sum += sample.abs();
    }
    double avg = sum / count;
    double level = min(1.0, avg / 12000.0);
    _soundLevelController.add(level);
  }

  String _cleanDisfluencies(String text) {
    if (text.isEmpty) return text;
    // Remove filler words like "uh", "um", "uhh", "umm", "er", "ah", "ahm"
    var cleaned = text.replaceAll(RegExp(r'\b(uh|um|uhh|umm|er|ah|ahm|uhm)\b[,.]?', caseSensitive: false), '');
    // Clean up whitespace & punctuation
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[,.]\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+([,.:?!])'), r'$1');
    return cleaned.trim();
  }

  @override
  Future<Either<Failure, void>> stopListening() async {
    _isListening = false;
    _isListeningController.add(false);

    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      await _audioRecorder.stop();
    } catch (_) {}

    try {
      await _webSocketSubscription?.cancel();
      _webSocketSubscription = null;
      await _webSocket?.close();
      _webSocket = null;
    } catch (_) {}

    return const Right(null);
  }
}

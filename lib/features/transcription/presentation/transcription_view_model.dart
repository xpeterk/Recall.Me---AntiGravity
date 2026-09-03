import 'package:flutter/foundation.dart';
import 'dart:async'; // For Timer
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // For MethodChannel
import 'package:flutter/material.dart'; // For Color
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/gemini_ai_service.dart';
import '../../../../core/services/claude_ai_service.dart';
import '../../../../core/services/google_integration_service.dart';
import '../../knowledge/domain/knowledge_repository.dart';
import '../../knowledge/domain/knowledge_repository.dart';
import '../../knowledge/data/native_knowledge_repository.dart';
import '../../recall/data/local_database.dart';
import '../../recall/domain/transcription_segment.dart';
import '../../knowledge/domain/notion_repository.dart';
import '../../knowledge/data/native_notion_repository.dart';
import '../../settings/domain/settings_repository.dart';
import '../../settings/data/native_settings_repository.dart';
import '../domain/transcription_repository.dart';
import '../domain/transcription_result.dart';
import '../data/native_transcription_repository.dart';
import '../data/gemini_live_transcription_repository.dart';
import '../../../../core/services/background_service_manager.dart';
import '../../settings/domain/ai_bubble.dart';
import '../../settings/domain/dynamic_starter.dart';
import '../../knowledge/domain/notion_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/services/link_parser_service.dart';

enum TranscriptionEngineMode {
  native, // On-Device / OS Native SpeechRecognizer
  gemini, // Gemini 3.5 Transcribe Live (WebSocket Stream)
}

class TranscriptionViewModel extends ChangeNotifier {
  final TranscriptionRepository _nativeRepository;
  final GeminiLiveTranscriptionRepository _geminiLiveRepository;
  final TranscriptionRepository _transcriptionRepository;

  TranscriptionEngineMode _engineMode = TranscriptionEngineMode.gemini;
  TranscriptionEngineMode get engineMode => _engineMode;
  bool get isGeminiEngine => _engineMode == TranscriptionEngineMode.gemini;

  TranscriptionRepository get _activeRepository =>
      _engineMode == TranscriptionEngineMode.native ? _nativeRepository : _geminiLiveRepository;

  StreamSubscription<TranscriptionResult>? _transcriptionSubscription;
  StreamSubscription<bool>? _isListeningSubscription;

  // AI Services
  AiService _activeAiService;
  final GeminiAiService _geminiService;
  final ClaudeAiService _claudeService;

  // AI Selection State
  String _selectedProvider = 'gemini'; // 'gemini' or 'claude'
  String _selectedModel = 'gemini-2.5-flash'; // Default

  String get selectedProvider => _selectedProvider;
  String get selectedModel => _selectedModel;

  final KnowledgeRepository _knowledgeRepository;
  final LocalDatabase _db;
  final NotionRepository _notionRepository;
  final SettingsRepository _settingsRepository;
  final GoogleIntegrationService _googleService;

  String _text = "Press the mic to start speaking...";
  
  // Data State
  List<TranscriptionSegment> _segments = [];
  
  // AI State
  String _aiResponse = "";
  List<String> _aiResponseList = [];
  bool _isAiProcessing = false;
  String? _lastFoundNotionUrl;
  String? _lastFoundNotionTitle;
  Set<String> _syncedRootIds = {};
  Set<String> get syncedRootIds => _syncedRootIds;
  
  bool _isListening = false;
  bool _isAvailable = false;

  String get text => _text;
  // Search State
  String _searchQuery = "";
  String get searchQuery => _searchQuery;

  // Context State
  String? _conversationStarter;
  String? get conversationStarter => _conversationStarter;
  
  String _externalContext = "";
  String get externalContext => _externalContext;
  final LinkParserService linkParserService = LinkParserService();

  Future<bool> processExternalLink(String url, {Function(String)? onStatus}) async {
    if (onStatus != null) onStatus("⏳ Reading link...");
    final data = await linkParserService.fetchContextFromUrl(url);
    if (data != null && data.isNotEmpty) {
      _externalContext += "\n\n--- Extracted Link Content ($url) ---\n$data\n------------------------\n";
      if (onStatus != null) onStatus("✓ Link Processed");
      notifyListeners();
      return true;
    } else {
      if (onStatus != null) onStatus("❌ Failed to read link");
      return false;
    }
  }

  void clearExternalContext() {
    _externalContext = "";
    notifyListeners();
  }

  String? _currentLocationName;

  List<String> _starterSuggestions = [];
  List<String> get starterSuggestions => _starterSuggestions;

  List<DynamicStarter> _dynamicStarters = [];
  List<DynamicStarter> get dynamicStarters => _dynamicStarters;

  List<String> _activeAiSuggestions = [];
  List<String> get activeAiSuggestions => _activeAiSuggestions;

  // Starter History
  List<String> _recentStarters = [];
  List<String> get recentStarters => _recentStarters;
  List<String> _pinnedStarters = [];
  List<String> get pinnedStarters => _pinnedStarters;

  List<String>? _cachedCalendarEvents;
  DateTime? _lastCalendarFetch;

  void setConversationStarter(String text) {
    _conversationStarter = text.isEmpty ? null : text;
    if (_conversationStarter != null && !_dynamicStarters.any((s) => s.name == text) && !starterSuggestions.contains(text)) {
       _addRecentStarter(text);
    }
    notifyListeners();
  }

  Future<void> _addRecentStarter(String text) async {
     if (_pinnedStarters.contains(text)) return;
     _recentStarters.remove(text);
     _recentStarters.insert(0, text);
     if (_recentStarters.length > 5) _recentStarters = _recentStarters.sublist(0, 5);
     notifyListeners();
     await _settingsRepository.setPreference('recent_starters', jsonEncode(_recentStarters));
  }

  Future<void> pinStarter(String text) async {
     _recentStarters.remove(text);
     if (!_pinnedStarters.contains(text)) {
        _pinnedStarters.add(text);
     } else {
        _pinnedStarters.remove(text); // toggle off
        _recentStarters.insert(0, text); // put back in recent
     }
     notifyListeners();
     await _settingsRepository.setPreference('recent_starters', jsonEncode(_recentStarters));
     await _settingsRepository.setPreference('pinned_starters', jsonEncode(_pinnedStarters));
  }

  Future<void> processDynamicStarter(DynamicStarter starter) async {
    _isAiProcessing = true;
    notifyListeners();

    String combinedText = "";

    // 1. Fetch latest page from mapped database if Notion ID is provided
    if (starter.notionDatabaseId.isNotEmpty) {
      final result = await _notionRepository.getLatestPageFromDatabase(starter.notionDatabaseId);
      
      await result.fold(
        (failure) async {
          // Could fail silently, continue with any prompt
        },
        (contentString) async {
          // 2. Parse "Summary:" and "Content:" into combined text using the static helper.
          combinedText += parseDynamicStarterContent(contentString);
        }
      );
    }
    
    // Inject prompt if provided
    if (starter.prompt != null && starter.prompt!.isNotEmpty) {
       if (combinedText.isNotEmpty) combinedText += "\n\n";
       combinedText += "=== PROMPT INSTRUCTIONS ===\n${starter.prompt}\n==========================";
    }

    if (combinedText.isNotEmpty) {
      // 3. Add as first message (or newest message)
      final segment = TranscriptionSegment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: combinedText,
        timestamp: DateTime.now(),
        type: SegmentType.aiResponse, // Treat as AI Response/System message
        bubbleName: starter.name,
        bubbleIcon: "📰", // News/Daily brief icon
        isUser: false,
      );
      
      await _db.insertSegment(segment);
      
      // Inject into AI Context directly
      _externalContext += "\n\n--- ${starter.name} ---\n$combinedText\n------------------------\n";
    }

    _isAiProcessing = false;
    await _loadSegments(); // Refresh UI list
  }

  /// Extracted static parsing logic for ease of unit testing handling the Make.com payload.
  static String parseDynamicStarterContent(String contentString) {
      String shortSummary = "";
      String longContent = "";
      
      final summaryIndex = contentString.indexOf("::Summary::");
      final contentIndex = contentString.indexOf("::Content::");
      
      if (summaryIndex != -1 && contentIndex != -1 && summaryIndex < contentIndex) {
          shortSummary = contentString.substring(summaryIndex + "::Summary::".length, contentIndex).trim();
          longContent = contentString.substring(contentIndex + "::Content::".length).trim();
      } else if (summaryIndex != -1) {
          shortSummary = contentString.substring(summaryIndex + "::Summary::".length).trim();
      } else if (contentIndex != -1) {
          longContent = contentString.substring(contentIndex + "::Content::".length).trim();
      } else {
          shortSummary = "Daily Brief fetched.";
          longContent = contentString.trim();
      }
      
      if (longContent.isEmpty) longContent = shortSummary;
      if (shortSummary.isEmpty) shortSummary = "Brief contents attached.";
      
      return "$shortSummary\n\n===LONG_CONTENT===\n\n$longContent";
  }

  Future<void> saveDynamicStarters(List<DynamicStarter> starters) async {
     await _settingsRepository.saveDynamicStarters(starters);
     await refreshDynamicStarters();
  }

  Future<void> refreshDynamicStarters() async {
     // Fetch Notion Starters from DB
     final startersResult = await _settingsRepository.getDynamicStarters();
     startersResult.fold((l) => null, (starters) {
        _dynamicStarters = starters.cast<DynamicStarter>().where((s) => s.isActive).toList();
     });

     _starterSuggestions = [];
     
     // 1. Time Context
     final hour = DateTime.now().hour;
     String timeOfDay = "Morning";
     if (hour >= 12 && hour < 17) timeOfDay = "Afternoon";
     else if (hour >= 17) timeOfDay = "Evening";

     // 2. Location Context
     try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
        }
        
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
            final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
            if (placemarks.isNotEmpty) {
                _currentLocationName = placemarks.first.name; 
            }
        }
     } catch (e) {
        print("Location error: $e");
     }

     // 3. Pattern Matching (Find past segments at this time/location)
     if (_currentLocationName != null && _currentLocationName!.isNotEmpty) {
         final recentMatches = _segments.where((s) {
              if (s.locationName == null) return false;
              bool locMatch = s.locationName!.contains(_currentLocationName!) || _currentLocationName!.contains(s.locationName!);
              bool timeMatch = (s.timestamp.hour - hour).abs() <= 2;
              return locMatch && timeMatch;
         }).toList();

         if (recentMatches.isNotEmpty) {
             _starterSuggestions.add("Pattern: $timeOfDay at $_currentLocationName");
         } else {
             _starterSuggestions.add("$timeOfDay at $_currentLocationName");
         }
     } else {
         _starterSuggestions.add("$timeOfDay Routine");
     }

     // 4. Upcoming Holidays & Birthdays
     if (isGoogleAuthenticated) {
         final specials = await _googleService.getUpcomingSpecials(daysAhead: 14);
         _starterSuggestions.addAll(specials);
     }
     
     notifyListeners();
  }

  Future<void> _fetchCalendarEventsIfNeeded() async {
     if (!isGoogleAuthenticated) return;
     // Cache for 5 minutes
     if (_cachedCalendarEvents != null && _lastCalendarFetch != null) {
        if (DateTime.now().difference(_lastCalendarFetch!).inMinutes < 5) return;
     }
     try {
       _cachedCalendarEvents = await _googleService.getUpcomingEvents(count: 3);
       _lastCalendarFetch = DateTime.now();
     } catch (e) {
       print("Error fetching calendar events for context: $e");
     }
  }

  // System Message State
  bool _showSystemMessages = true;
  bool get showSystemMessages => _showSystemMessages;

  // Bottom Text Input State
  bool _showBottomTextInput = false;
  bool get showBottomTextInput => _showBottomTextInput;

  // Auto-Summary State
  bool _enableAutoSummary = false;
  bool get enableAutoSummary => _enableAutoSummary;
  final Set<String> _unsummarizedSegmentIds = {};
  final Set<String> _expandedSummaryIds = {};
  bool isSummaryExpanded(String id) => _expandedSummaryIds.contains(id);
  
  // Diagnostics State
  bool _showDiagnostics = false;
  bool get showDiagnostics => _showDiagnostics;
  double _currentConfidence = 1.0;

  // Sync State
  DateTime? _lastSyncTime;
  String get lastSyncTimeFormatted {
    if (_lastSyncTime == null) return "Never";
    // Format: MM/dd HH:mm
    final month = _lastSyncTime!.month.toString().padLeft(2, '0');
    final day = _lastSyncTime!.day.toString().padLeft(2, '0');
    final hour = _lastSyncTime!.hour.toString().padLeft(2, '0');
    final minute = _lastSyncTime!.minute.toString().padLeft(2, '0');
    return "$month/$day $hour:$minute";
  }
  
  List<TranscriptionSegment> get segments {
    // Synced Notion data should only be used for context, never shown as chat bubbles
    var list = _segments.where((s) => s.type != SegmentType.notion).toList();

    // Filter Summarized Segments (Collapse Logic)
    final collapsedSummaries = list.where((s) => 
        s.type == SegmentType.summary && !isSummaryExpanded(s.id)
    ).toList();

    final hiddenIds = <String>{};
    for (var summary in collapsedSummaries) {
       hiddenIds.addAll(summary.includedSegmentIds);
    }

    if (hiddenIds.isNotEmpty) {
       list = list.where((s) => !hiddenIds.contains(s.id)).toList();
    }


    // Filter Search
    if (_searchQuery.isNotEmpty) {
      list = list.where((s) => s.text.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    for (var s in list) {
      s.isExpanded = isSummaryExpanded(s.id);
    }
    
    // We return the full list even when frozen, so new segments naturally turn into bubbles at the visual bottom
    return list;
  }
  
  List<TranscriptionSegment> get notionConvoStarters {
    return _segments.where((s) => s.type == SegmentType.notion && s.text.contains("Convo Starter: true")).toList();
  }

  List<TranscriptionSegment> parseConvoStarterBullets(String markdown, String sourceUrl, String contextTopic) {
    final lines = markdown.split('\n');
    final segments = <TranscriptionSegment>[];
    
    String? currentTopBullet;
    final subPoints = <String>[];
    
    void flushCurrent() {
      if (currentTopBullet != null) {
         String cleanTop = currentTopBullet!;
         if (cleanTop.startsWith('- ')) cleanTop = cleanTop.substring(2);
         else if (cleanTop.startsWith('* ')) cleanTop = cleanTop.substring(2);
         
         String text = cleanTop;
         if (subPoints.isNotEmpty) {
            text = "$cleanTop\n===LONG_CONTENT===\n" + subPoints.join('\n');
         }
         
         segments.add(TranscriptionSegment(
           id: DateTime.now().millisecondsSinceEpoch.toString() + "_" + segments.length.toString() + "_starter",
           text: text,
           timestamp: DateTime.now().add(Duration(milliseconds: segments.length)),
           type: SegmentType.aiResponse,
           bubbleName: "Convo Starter",
           bubbleIcon: "💬",
           sourceUrl: sourceUrl,
           contextTopic: contextTopic,
         ));
      }
      subPoints.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      if ((line.startsWith('- ') || line.startsWith('* ')) && !line.startsWith(' ')) {
         flushCurrent();
         currentTopBullet = line;
      } else if (currentTopBullet != null) {
         subPoints.add(line);
      }
    }
    flushCurrent();
    
    return segments;
  }

  Future<void> triggerConvoStarter(TranscriptionSegment convoStarterSegment) async {
     final bullets = parseConvoStarterBullets(
        convoStarterSegment.text, 
        convoStarterSegment.sourceUrl ?? "", 
        convoStarterSegment.contextTopic ?? convoStarterSegment.id
     );
     for (var bullet in bullets) {
        await _db.insertSegment(bullet);
     }
     await _loadSegments();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> toggleSystemMessages(bool value) async {
    _showSystemMessages = value;
    notifyListeners();
    await _settingsRepository.setPreference('show_system_messages', value);
  }

  Future<void> toggleBottomTextInput(bool value) async {
    _showBottomTextInput = value;
    notifyListeners();
    await _settingsRepository.setPreference('show_bottom_text_input', value);
  }

  void toggleSummaryExpansion(String summaryId) {
    if (_expandedSummaryIds.contains(summaryId)) {
      _expandedSummaryIds.remove(summaryId);
    } else {
      _expandedSummaryIds.add(summaryId);
    }
    notifyListeners();
  }

  Future<void> toggleAutoSummary(bool value) async {
    _enableAutoSummary = value;
    notifyListeners();
    await _settingsRepository.setPreference('enable_auto_summary', value);
  }

  Future<void> toggleDiagnostics(bool value) async {
    _showDiagnostics = value;
    notifyListeners();
    await _settingsRepository.setPreference('show_diagnostics', value);
  }
  String get aiResponse => _aiResponse;
  List<String> get aiResponseList => _aiResponseList;
  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  bool get isAiProcessing => _isAiProcessing;
  Stream<double> get soundLevelStream => _activeRepository.soundLevelStream;
  
  // Selection State
  final Set<String> _selectedIds = {};
  bool get isSelectionMode => _selectedIds.isNotEmpty;
  int get selectionCount => _selectedIds.length;
  bool isSelected(String id) => _selectedIds.contains(id);

  // Editing State
  String? _editingSegmentId;
  String? get editingSegmentId => _editingSegmentId;
  bool isEditing(String id) => _editingSegmentId == id;
  
  // AI Viewing State
  String? _viewingAiSegmentId; // If non-null, we are viewing an EXISTING segment
  bool get isViewingExistingAi => _viewingAiSegmentId != null;
  AiBubble? _currentSourceBubble; // Track which bubble generated the current response

  // Google Integration State
  bool get isGoogleAuthenticated => _googleService.isAuthenticated;
  String? get googleUserEmail => _googleService.currentUser?.email;

  Future<String?> connectGoogle() async {
    // Returns null on success, error message on failure
    final error = await _googleService.signIn();
    notifyListeners();
    return error;
  }

  Future<void> disconnectGoogle() async {
    await _googleService.signOut();
    notifyListeners();
  }

  TranscriptionViewModel({
    TranscriptionRepository? repository,
    GeminiLiveTranscriptionRepository? geminiLiveRepository,
    AiService? aiService,
    KnowledgeRepository? knowledgeRepository,
    LocalDatabase? database,
    NotionRepository? notionRepository,
    SettingsRepository? settingsRepository,
    GoogleIntegrationService? googleService,
  })  : _nativeRepository = repository ?? NativeTranscriptionRepository(),
        _geminiLiveRepository = geminiLiveRepository ?? GeminiLiveTranscriptionRepository(settingsRepository: settingsRepository),
        _transcriptionRepository = repository ?? NativeTranscriptionRepository(),
        _geminiService = (aiService is GeminiAiService) ? aiService : GeminiAiService(),
        _claudeService = ClaudeAiService(),
        _activeAiService = (aiService is GeminiAiService) ? aiService : GeminiAiService(), // Default to Gemini initially
        _knowledgeRepository = knowledgeRepository ?? NativeKnowledgeRepository(),
        _db = database ?? LocalDatabase(),
        _notionRepository = notionRepository ?? NativeNotionRepository(),
        _settingsRepository = settingsRepository ?? NativeSettingsRepository(),
        _googleService = googleService ?? GoogleIntegrationService() {
    _init();
  }

  Future<void> setTranscriptionEngine(TranscriptionEngineMode mode, {bool save = true}) async {
    if (_engineMode == mode) return;
    final wasListening = _isListening;
    if (wasListening) {
      await toggleListening();
    }
    _engineMode = mode;
    _subscribeToActiveRepository();
    notifyListeners();
    if (save) {
      await _settingsRepository.setPreference('transcription_engine_mode', mode.name);
    }
    if (wasListening) {
      await toggleListening();
    }
  }

  Future<void> toggleTranscriptionEngine() async {
    final newMode = _engineMode == TranscriptionEngineMode.native 
        ? TranscriptionEngineMode.gemini 
        : TranscriptionEngineMode.native;
    await setTranscriptionEngine(newMode);
  }

  void _updateGeminiCustomVocabulary() {
    final vocab = <String>{};
    for (var s in _segments) {
      if (s.contextTopic != null && s.contextTopic!.isNotEmpty) {
        vocab.add(s.contextTopic!);
      }
    }
    for (var starter in _dynamicStarters) {
      vocab.add(starter.name);
    }
    _geminiLiveRepository.setCustomVocabulary(vocab.toList());
  }

  Future<List<String>> fetchAvailableModels(String provider) async {
    if (provider == 'gemini') {
      return await _geminiService.listModels();
    } else {
      return await _claudeService.listModels();
    }
  }

  bool _isManualStop = false; // Flag to track if user explicitly stopped mic
  bool _isRestarting = false; // Flag to prevent flickering/race conditions during auto-restart

  Timer? _silenceTimer;
  int _processedOffset = 0; // Track how much of the continuous stream we've already "bubbled"

  void _subscribeToActiveRepository() {
    _transcriptionSubscription?.cancel();
    _isListeningSubscription?.cancel();

    _transcriptionSubscription = _activeRepository.transcriptionStream.listen((result) {
      if (_engineMode == TranscriptionEngineMode.native) {
        // Reset silence timer on every new packet
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(seconds: 3), _onSilence);
        
        // Calculate "Pending" text by subtracting what we've already committed
        final fullText = result.text;
        if (result.confidence > 0) {
           _currentConfidence = result.confidence;
        }
        print("DEBUG: STT Stream: $fullText (len: ${fullText.length}) | Conf: $_currentConfidence | Offset: $_processedOffset");
        
        if (fullText.length >= _processedOffset) {
           _text = fullText.substring(_processedOffset);
        } else {
           _processedOffset = 0;
           _text = fullText;
        }
        notifyListeners();
      } else {
        // Gemini Live Streaming logic
        _currentConfidence = result.confidence;
        _text = result.text;
        notifyListeners();

        if (result.isFinal && result.text.trim().isNotEmpty) {
          _commitCurrentText(result.text.trim());
          _text = "";
          notifyListeners();
        }
      }
    });

    _isListeningSubscription = _activeRepository.isListeningStream.listen((listening) async {
      if (!listening) {
        _silenceTimer?.cancel();
        if (_engineMode == TranscriptionEngineMode.native) {
          _onSilence(); // Force commit pending text
          
          if (!_isManualStop && _isAvailable) {
              if (_isRestarting) return;
              _isRestarting = true;
              _processedOffset = 0;
              await Future.delayed(const Duration(milliseconds: 300));
              await _muteBriefly();
              await _activeRepository.startListening();
              _isRestarting = false;
          }
        } else {
          _isListening = false;
          notifyListeners();
        }
      } else {
        if (!_isRestarting) {
          _isListening = listening;
          notifyListeners();
        }
      }
    });
  }

  void _init() async {
    await refreshApiKeys();
    await _loadSegments(); // Load from DB
    await _loadBubbles();
    _loadLastSyncTime();
    
    refreshDynamicStarters();
    
    // Background Pre-fetch Notion Headers for Zero-Latency semantic search
    _knowledgeRepository.getNotionHeaders();

    // Load Engine Preference
    final enginePref = await _settingsRepository.getPreference('transcription_engine_mode');
    enginePref.fold(
      (_) {},
      (val) {
        if (val is String && val == 'native') {
          _engineMode = TranscriptionEngineMode.native;
        } else {
          _engineMode = TranscriptionEngineMode.gemini;
        }
      }
    );

    final autoSummaryPref = await _settingsRepository.getPreference('enable_auto_summary');
    autoSummaryPref.fold(
      (_) {},
      (val) { if (val is bool) _enableAutoSummary = val; }
    );

    // Load Bottom Text Input Preference
    final textInputPref = await _settingsRepository.getPreference('show_bottom_text_input');
    textInputPref.fold(
      (_) {},
      (val) { if (val is bool) _showBottomTextInput = val; }
    );
    
    // Load Diagnostics Preference
    final diagPref = await _settingsRepository.getPreference('show_diagnostics');
    diagPref.fold(
      (_) {},
      (val) { if (val is bool) _showDiagnostics = val; }
    );
    
    // Load Starter History
    final recentPref = await _settingsRepository.getPreference('recent_starters');
    recentPref.fold((_) {}, (val) {
       if (val is String) {
          try { _recentStarters = List<String>.from(jsonDecode(val)); } catch (e) {}
       }
    });

    final pinnedPref = await _settingsRepository.getPreference('pinned_starters');
    pinnedPref.fold((_) {}, (val) {
       if (val is String) {
          try { _pinnedStarters = List<String>.from(jsonDecode(val)); } catch (e) {}
       }
    });
    
    // Trigger Background Sync (Silent)
    backgroundSync(silent: true);

    // Initialize both engines
    await _nativeRepository.initialize();
    await _geminiLiveRepository.initialize();
    _isAvailable = true;
    _updateGeminiCustomVocabulary();
    _subscribeToActiveRepository();
    notifyListeners();
  }

  void _onSilence() {
    print("DEBUG: Silence Detected. Text length: ${_text.length}");
    if (_text.trim().isNotEmpty && !_text.contains("Press the mic")) {
      print("DEBUG: Committing text: $_text");
      
      final String textToProcess = _text; // Capture
      final int committedLength = textToProcess.length;
      
      _commitCurrentText(textToProcess); // Pass value
      
      _processedOffset += committedLength;
      
      _text = ""; // Clear visual buffer (Found: Redundant if commit clears it, but safe)
      notifyListeners();
    }
  }

  // Bubble State
  List<AiBubble> _bubbles = [];
  List<AiBubble> get bubbles => _bubbles;
  // Merged List for UI: User Bubbles + Suggestions (at the end to prevent jiggle)
  // Bubbles Merged List
  List<AiBubble> get allBubbles => [..._bubbles, ..._suggestedBubbles];

  Future<void> addManualMessage(String text) async {
    if (text.isEmpty) return;
    final segment = TranscriptionSegment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      type: SegmentType.audio, // Treat as normal spoken/typed context
      isUser: true,
    );
    await _db.insertSegment(segment);
    await _loadSegments(); // Refresh UI
  }

  Future<void> _loadSegments() async {
    _segments = await _db.getAllSegments();
    notifyListeners();
  }

  Future<void> _loadBubbles() async {
    // Load Preference
    final prefResult = await _settingsRepository.getPreference('show_system_messages');
    prefResult.fold(
      (_) {},
      (val) {
        if (val is bool) {
          _showSystemMessages = val;
        }
      }
    );

    final result = await _settingsRepository.getBubbles();
    await result.fold(
      (failure) async {
         // Error or empty, load defaults if empty
      },
      (data) async {
        if (data.isEmpty) {
          _createDefaultBubbles();
        } else {
          _bubbles = data.map((e) => AiBubble.fromMap(e)).toList();
          
          // MIGRATION: Fix icons for existing users / DB records
          bool needsSave = false;
          for (var b in _bubbles) {
            if (b.id == 'default_notion' && b.icon == '📓') {
              b.icon = 'assets/images/notion_logo.png';
              needsSave = true;
            }
            if (b.id == 'default_smart_assistant' && b.icon == '🤖') {
              b.icon = 'assets/images/gmail_logo.png';
              b.color = const Color(0xFF673AB7); 
              needsSave = true;
            }
            // Update Fact Check to American Flag 🇺🇸 (User Request)
            if (b.id == 'default_factcheck' && (b.icon == '✅' || b.icon == '🧐' || b.name == 'Fact Check')) {
              b.icon = '🇺🇸';
              b.name = 'Quick Fact Check';
              needsSave = true;
            }
            // Update Q&A to Raised Hand and "Quick" name
            if (b.id == 'default_qa' && (b.icon == '❓' || b.name == 'Q&A')) {
              b.icon = '🙋';
              b.name = 'Quick Q&A';
              needsSave = true;
             }
          }
          
          // MIGRATION: One-time addition of new bubbles (v4)
          final prefs = await SharedPreferences.getInstance();
          final outputv4Migrated = prefs.getBool('migration_v4_bubbles_added') ?? false;

          if (!outputv4Migrated) {
             bool migrationNeeded = false;
             
             // Ensure Fact Check exists
             if (!_bubbles.any((b) => b.id == 'default_fact_check')) {
               _bubbles.add(AiBubble(
                 id: 'default_fact_check',
                 name: 'Fact Check',
                 icon: '📊',
                 color: const Color(0xFF4285F4),
                 systemPrompt: "Fact-check the selected text and verify if it is true, providing accurate details and context.",
               ));
               migrationNeeded = true;
             }

             // Ensure Idea exists
             if (!_bubbles.any((b) => b.id == 'default_idea')) {
               _bubbles.add(AiBubble(
                 id: 'default_idea',
                 name: 'Idea',
                 icon: '💡',
                 color: const Color(0xFFFFC107),
                 systemPrompt: "Generate creative, unique ideas or brainstorm suggestions based on the selected text.",
               ));
               migrationNeeded = true;
             }

             // Ensure Define exists
             if (!_bubbles.any((b) => b.id == 'default_define')) {
               _bubbles.add(AiBubble(
                 id: 'default_define',
                 name: 'Define',
                 icon: '📖',
                 color: const Color(0xFF8BC34A),
                 systemPrompt: "Define the selected terms, phrases, or jargon clearly with brief usage examples.",
               ));
               migrationNeeded = true;
             }

             // Ensure Translate exists
             if (!_bubbles.any((b) => b.id == 'default_translate')) {
               _bubbles.add(AiBubble(
                 id: 'default_translate',
                 name: 'Translate',
                 icon: '🌐',
                 color: const Color(0xFF00BCD4),
                 systemPrompt: "Translate the selected text into English. If the text is already in English, translate it to Spanish.",
               ));
               migrationNeeded = true;
             }

             if (migrationNeeded) {
               _saveBubbles();
             }
             
             await prefs.setBool('migration_v4_bubbles_added', true);
          }
        }
        notifyListeners();
      }
    );
  }

  void _createDefaultBubbles() {
    _bubbles = [
      AiBubble(
        id: 'default_fact_check',
        name: 'Fact Check',
        icon: '📊',
        color: const Color(0xFF4285F4),
        systemPrompt: "Fact-check the selected text and verify if it is true, providing accurate details and context.",
      ),
      AiBubble(
        id: 'default_general_ai',
        name: 'Ask AI',
        icon: '🤖',
        color: const Color(0xFF607D8B),
        systemPrompt: "You are a helpful AI assistant. Answer the user's prompt freely.",
      ),
      AiBubble(
        id: 'default_idea',
        name: 'Idea',
        icon: '💡',
        color: const Color(0xFFFFC107),
        systemPrompt: "Generate creative, unique ideas or brainstorm suggestions based on the selected text.",
      ),
      AiBubble(
        id: 'default_define',
        name: 'Define',
        icon: '📖',
        color: const Color(0xFF8BC34A),
        systemPrompt: "Define the selected terms, phrases, or jargon clearly with brief usage examples.",
      ),
      AiBubble(
        id: 'default_translate',
        name: 'Translate',
        icon: '🌐',
        color: const Color(0xFF00BCD4),
        systemPrompt: "Translate the selected text into English. If the text is already in English, translate it to Spanish.",
      ),
      AiBubble(
        id: 'default_notion_v2',
        name: 'Ask Notion',
        icon: 'assets/images/notion_logo.png',
        color: const Color(0xFFE91E63),
        systemPrompt: "Provide the most likely answer using provided Notion context and answer in a short sentance.",
        useNotionContext: true,
        isMultiOutput: true,
        useWebSearch: false,
        additionalPrompts: ["Provide the next most likely answer using provided Notion context and answer in a short sentance"],
      ),
      AiBubble(
        id: 'default_notion_search',
        name: 'Notion Search',
        icon: '🔎',
        color: const Color(0xFFE91E63), 
        systemPrompt: "Review the provided Notion Index. Find the best possible answer for the selected text by displaying a Page title and Link to the top 5 best possible Notion answers. For speed, do not include summaries, ONLY the Title and Link.",
        useNotionContext: true,
        isMultiOutput: true,
        additionalPrompts: ["Review the provided Notion Index. Display the Page title and Link to the next 5 best possible Notion answers. For speed, do not include summaries, ONLY the Title and Link."],
      ),
    ];
    _saveBubbles();
  }

  Future<void> _saveBubbles() async {
    await _settingsRepository.saveBubbles(_bubbles.map((e) => e.toMap()).toList());
  }

  Future<void> saveBubble(AiBubble bubble) async {
    final index = _bubbles.indexWhere((b) => b.id == bubble.id);
    if (index != -1) {
      _bubbles[index] = bubble;
    } else {
      _bubbles.add(bubble);
    }
    await _saveBubbles();
    notifyListeners();
  }

  Future<void> deleteBubble(String id) async {
    _bubbles.removeWhere((b) => b.id == id);
    await _saveBubbles();
    notifyListeners();
  }

  Future<void> reorderBubbles(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final AiBubble item = _bubbles.removeAt(oldIndex);
    _bubbles.insert(newIndex, item);
    await _saveBubbles();
    notifyListeners();
  }

  Future<void> duplicateBubble(AiBubble original) async {
    final newBubble = AiBubble(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: "${original.name} Copy",
      icon: original.icon,
      color: original.color,
      systemPrompt: original.systemPrompt,
      isEnabled: true,
      useNotionContext: original.useNotionContext,
      useGoogleContext: original.useGoogleContext,
      useWebSearch: original.useWebSearch,
      linkedPageIds: List.from(original.linkedPageIds),
      isMultiOutput: original.isMultiOutput,
      additionalPrompts: List.from(original.additionalPrompts),
      isGenerated: original.isGenerated,
    );
    
    _bubbles.add(newBubble);
    await _saveBubbles();
    notifyListeners();
  }

  Future<void> clearAllHistory() async {
    await _db.clearAllSegments();
    await _loadSegments();
  }

  Future<void> clearRawTranscripts() async {
    // Keep AI, Notion, and System segments. Delete only AUDIO/User text.
    await _db.deleteSegmentsByType(SegmentType.audio.index);
    await _loadSegments();
  }


  Future<void> _commitCurrentText(String textToCommit) async {
    if (textToCommit.trim().isEmpty) return;
    
    // Smart Segmentation: Split by Punctuation
    // Regex for sentence endings [.?!] followed by space or end of string
    // Simplified splitting preventing empty chunks
    
    String processingText = textToCommit.trim();
    
    print("DEBUG: Processing Commit for: $processingText");
    
    final sentences = processingText.split(RegExp(r'(?<=[.?!])\s+'));
    final List<String> sentencesProcessedInThisLoop = [];
    final stableTimestamp = DateTime.now(); // Stable timestamp for IDs in this batch
    int timestampOffset = 0;
    
    for (var sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;

      // Deduplicate within the same sentence batch
      if (sentencesProcessedInThisLoop.contains(trimmed)) {
         print("DEBUG: Duplicate sentence in same batch ignored: $trimmed");
         continue;
      }

      // START DEDUPLICATION: Check against ALL recent segments (not just the first one)
      bool isDuplicate = false;
      if (_segments.isNotEmpty) {
         for (var s in _segments) {
            if (s.type == SegmentType.audio && s.text == trimmed) {
               final timeDiff = stableTimestamp.difference(s.timestamp).abs();
               if (timeDiff.inSeconds < 5) {
                  isDuplicate = true;
                  break;
               }
            }
         }
      }
      if (isDuplicate) {
         print("DEBUG: Duplicate segment ignored: $trimmed");
         continue;
      }
      // END DEDUPLICATION
      
      sentencesProcessedInThisLoop.add(trimmed);
      
      final newSegment = TranscriptionSegment(
        id: (stableTimestamp.millisecondsSinceEpoch + (timestampOffset++)).toString() + sentence.hashCode.toString(), // Unique stable ID per chunk
        text: trimmed,
        timestamp: stableTimestamp,
        type: SegmentType.audio,
        confidence: _currentConfidence,
        locationName: _currentLocationName,
      );

      // Auto-Summary Tracking
      if (_enableAutoSummary) {
         _unsummarizedSegmentIds.add(newSegment.id);
      }

      print("DEBUG: Inserting Segment: ${newSegment.id}");
      await _db.insertSegment(newSegment);
    }
    
    print("DEBUG: Commit Complete. Reloading...");
    await _loadSegments(); // Refresh list
    
    // Trigger Auto-Summary Check
    if (_enableAutoSummary && _unsummarizedSegmentIds.length >= 10) {
       _generateAutoSummary();
    }
  }

  Future<void> _generateAutoSummary() async {
     // 1. Get segments to summarize
     // We need to fetch the actual text. In a real app we might query specific IDs.
     // Here we filter the in-memory list which should remain sync'd.
     final segmentsToSummarize = _segments.where((s) => _unsummarizedSegmentIds.contains(s.id)).toList();
     
     if (segmentsToSummarize.isEmpty) return;
     
     // 2. Prepare text
     final textBlock = segmentsToSummarize.map((s) => s.text).join(" ");
     final includedIds = segmentsToSummarize.map((s) => s.id).toList();
     
     // Clear tracking immediately to prevent double firing
     _unsummarizedSegmentIds.clear();

     // 3. Generate Summary JSON
     final prompt = """
Analyze the following conversation block.
Determine a 3-5 word Title that represents the primary topic discussed.
Also generate 2-3 short follow-up questions, conversation starters, or actions the user might take next based on the text.
Return ONLY valid JSON matching this schema:
{
  "title": "Short Descriptive Title",
  "suggestions": ["Suggestion 1", "Suggestion 2"]
}

Conversation Block:
$textBlock
""";
     
     try {
        final result = await _activeAiService.generate(prompt, model: "gemini-1.5-flash"); // Use fast model
        
        result.fold(
          (failure) { print("Auto-Summary Failed: ${failure.message}"); },
          (summaryText) async {
             String title = "Topic Auto-Summary";
             List<String> suggestions = [];
             
             try {
                // Strip possible markdown blocks from JSON
                String cleanJson = summaryText.trim();
                if (cleanJson.startsWith("```json")) cleanJson = cleanJson.substring(7);
                if (cleanJson.startsWith("```")) cleanJson = cleanJson.substring(3);
                if (cleanJson.endsWith("```")) cleanJson = cleanJson.substring(0, cleanJson.length - 3);
                
                final json = jsonDecode(cleanJson.trim());
                if (json['title'] != null) title = json['title'];
                if (json['suggestions'] != null) {
                   suggestions = List<String>.from(json['suggestions']);
                   _activeAiSuggestions = suggestions;
                }
             } catch (e) {
                print("Failed to parse summary JSON: $e");
                title = summaryText.trim(); // Fallback to raw text
             }

             // 4. Create and Save Summary Segment
             final summarySegment = TranscriptionSegment(
               id: DateTime.now().millisecondsSinceEpoch.toString() + "_summary",
               text: title,
               timestamp: DateTime.now(),
               type: SegmentType.summary,
               includedSegmentIds: includedIds,
               bubbleIcon: "📌", 
               bubbleName: "Topic Boundry"
             );
             
             await _db.insertSegment(summarySegment);
             await _loadSegments();
          }
        );
     } catch (e) {
       print("Auto-Summary Error: $e");
     }
  }

  



  // ... (Save AI Memory restored) ...
  Future<void> saveAiMemory(String title, String content) async {
    // If we are just viewing an existing one, don't save a duplicate
    if (isViewingExistingAi) return;

    final newSegment = TranscriptionSegment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: content,
      timestamp: DateTime.now(),
      type: SegmentType.aiResponse,
      isSelected: false,
      bubbleName: _currentSourceBubble?.name ?? "AI Insight",
      bubbleIcon: _currentSourceBubble?.icon ?? "✨",
      sourceUrl: _lastFoundNotionUrl,
      contextTopic: _lastFoundNotionTitle,
    );

    // Ensure we don't save duplicates if the user clicked "Save" explicitly
    // This is a simple check; could be more robust
    bool exists = _segments.any((s) => s.text == content && s.type == SegmentType.aiResponse);
    if (!exists) {
        await _db.insertSegment(newSegment);
        await _loadSegments();
        // Mark as "Existing" now so we don't save again on dismiss
        _viewingAiSegmentId = newSegment.id; 
    }
  }

  void viewAiSegment(TranscriptionSegment segment) {
    _viewingAiSegmentId = segment.id;
    _aiResponse = segment.text;
    
    // Check if JSON
    try {
      if (_aiResponse.trim().startsWith('{')) {
         final json = jsonDecode(_aiResponse);
         if (json['responses'] != null) {
            _aiResponseList = List<String>.from(json['responses']);
         } else {
            _aiResponseList = [_aiResponse];
         }
      } else {
         _aiResponseList = [_aiResponse];
      }
    } catch (_) {
      _aiResponseList = [_aiResponse];
    }
    
    notifyListeners();
  }

  void clearAiResponse() {
    _aiResponse = "";
    _aiResponseList = [];
    _viewingAiSegmentId = null;
    _currentSourceBubble = null;
    notifyListeners();
  }

  Future<void> toggleListening() async {
    if (_isListening) {
      _isManualStop = true; // User explicitly stopping
      _isListening = false; // Force UI update immediately to prevent "stuck" state
      _silenceTimer?.cancel();
      notifyListeners();
      
      await _muteBriefly(); // Mute beep on stop
      await _activeRepository.stopListening();
    } else {
      // Clear placeholder text when starting
      if (_text.contains("Press the mic")) _text = "";
      _isManualStop = false; // Reset flag
      
      if (_engineMode == TranscriptionEngineMode.gemini) {
        _updateGeminiCustomVocabulary();
      }

      await _muteBriefly(); // Mute beep on start
      final result = await _activeRepository.startListening();
      result.fold(
        (failure) {
          _text = failure.message;
          _isListening = false;
          notifyListeners();
        },
        (_) {
          _isListening = true;
          notifyListeners();
        }
      );
    }
  }

  Future<void> summarizeText() async {
    final textToSummarize = _segments
        .where((s) => _selectedIds.contains(s.id))
        .map((s) => s.text)
        .join("\n\n");

    if (textToSummarize.isEmpty) return;

    _isAiProcessing = true;
    _aiResponse = "";
    _viewingAiSegmentId = null; // New generation
    notifyListeners();

    final prompt = "Please summarize the following text concisely:\n\n$textToSummarize";

    // Stage 1: Snap Summary
    final stream = _activeAiService.generateStream(prompt, model: _selectedModel);
    
    await for (final chunk in stream) {
      chunk.fold(
        (failure) {
           _aiResponse = "Error: ${failure.message}";
        },
        (textChunk) {
           _aiResponse += textChunk;
        }
      );
      notifyListeners();
    }

    _isAiProcessing = false;
    notifyListeners();
  }

  Future<void> deepDiveText() async {
    String textToAnalyze = _segments
        .where((s) => _selectedIds.contains(s.id))
        .map((s) => s.text)
        .join("\n\n");

    if (textToAnalyze.isEmpty) {
       // Fallback: If viewing an existing AI response, analyze THAT.
       if (isViewingExistingAi || _aiResponse.isNotEmpty) {
         textToAnalyze = _aiResponse;
       } else {
         return;
       }
    }

    // Flatten existing JSON response if needed before appending
    if (_aiResponse.trim().startsWith('{')) {
      try {
         final json = jsonDecode(_aiResponse);
         if (json['responses'] != null) {
            final List<String> list = List<String>.from(json['responses']);
            _aiResponse = list.join("\n\n");
         }
      } catch (_) {
        // ignore
      }
    }
    
    // Clear the list so UI uses the main string (which we are about to append to)
    _aiResponseList = []; 

    _isAiProcessing = true;
    _aiResponse += "\n\n### Deep Dive Analysis\n\n"; // Using Markdown Header
    _viewingAiSegmentId = null; 
    notifyListeners();

    final prompt = "Provide a deep dive analysis of the following text. Use Markdown for formatting (bold, lists). Do not output JSON:\n\n$textToAnalyze";

    // Stage 2: Deep Dive
    final stream = _activeAiService.generateStream(prompt, model: _selectedModel);
    
    await for (final chunk in stream) {
      chunk.fold(
        (failure) {
           _aiResponse += "\nError: ${failure.message}";
        },
        (textChunk) {
           _aiResponse += textChunk;
        }
      );
      notifyListeners();
    }
    
    _isAiProcessing = false;
    notifyListeners();
  }

  Future<void> factCheckText() async {
    final textToVerify = _segments
        .where((s) => _selectedIds.contains(s.id))
        .map((s) => s.text)
        .join("\n\n");

    if (textToVerify.isEmpty) return;
    
    _isAiProcessing = true;
    _aiResponse = "Searching knowledge base...";
    _viewingAiSegmentId = null; // New generation
    notifyListeners();

    // 1. Retrieve Context (Mock RAG)
    final contextResult = await _knowledgeRepository.retrieveContext(textToVerify);
    
    // 2. Construct Prompt with Context
    String contextString = "";
    contextResult.fold(
      (failure) => contextString = "Could not retrieve context.",
      (contextList) => contextString = contextList.join("\n- "),
    );



    // 3. Generate AI Response
    String ragContext = "";
    
    // Check for Google Integration (RAG)
    if (_currentSourceBubble?.id == 'default_smart_assistant' && isGoogleAuthenticated) {
       _aiResponse = "Checking Email & Calendar...";
       notifyListeners();

       final emails = await _googleService.getRecentEmails(count: 3);
       final events = await _googleService.getUpcomingEvents(count: 3);
       
       ragContext += "\n\nUser's Recent Emails:\n${emails.join('\n')}";
       ragContext += "\n\nUser's Upcoming Calendar:\n${events.join('\n')}";
    }

    final prompt = """
You are a Fact Checker and Personal Assistant. Verify the following claim based ONLY on the provided Context.
If the claim is supported, say "Verified". If contradicted, say "False". If not found, say "Unknown".
If the user is asking about their schedule or emails, answer directly using the provided Personal Context.

Context:
- $contextString
$ragContext

Claim/Question:
"$textToVerify"

Analysis:
""";
    final stream = _activeAiService.generateStream(prompt, model: _selectedModel);
    
    _aiResponse = ""; // Clear "Searching..." message
    notifyListeners();

    await for (final chunk in stream) {
      chunk.fold(
        (failure) {
           _aiResponse = "Error: ${failure.message}";
        },
        (textChunk) {
           _aiResponse += textChunk;
        }
      );
      notifyListeners();
    }
    
    _isAiProcessing = false;
    notifyListeners();
  }

  Future<void> processWithBubble(AiBubble bubble) async {
    final textToProcess = _segments
        .where((s) => _selectedIds.contains(s.id))
        .map((s) => s.text)
        .join("\n\n");

    if (textToProcess.isEmpty) return;
    
    _isAiProcessing = true;
    _isAiProcessing = true;
    _aiResponse = "";
    _aiResponseList = [];
    
    // Init with first name or generic "Processing..."
    _aiResponseList.add("${bubble.name} running..."); 
    
    _viewingAiSegmentId = null; // New generation
    _currentSourceBubble = bubble; // Capture source
    notifyListeners();

    // Prepare Prompts
    List<String> promptsToRun = [bubble.systemPrompt];
    if (bubble.isMultiOutput) {
      promptsToRun.addAll(bubble.additionalPrompts);
    }
    
    // PRE-FETCH CONTEXT (Optimization: Fetch once for all prompts in this bubble)
    String commonContext = "";
    
    if (_conversationStarter != null && _conversationStarter!.isNotEmpty) {
      commonContext += "\n\n--- Global Context ---\nUser's Current Context/Goal: $_conversationStarter\n------------------------\n";
      
      // Inject Historical Context from Database
      final history = await _db.getHistoryForContext(_conversationStarter!, limit: 30);
      if (history.isNotEmpty) {
         commonContext += "\n--- Past Timeline for $_conversationStarter ---\n";
         for (var segment in history.reversed) { // reversed so oldest first
            String prefix = segment.isUser ? "You" : (segment.bubbleName ?? "Entity");
            commonContext += "[${segment.timestamp.month}/${segment.timestamp.day} ${segment.timestamp.hour}:${segment.timestamp.minute}] $prefix: ${segment.text}\n";
         }
         commonContext += "------------------------\n";
      }
    }
    if (_externalContext.isNotEmpty) {
      commonContext += _externalContext;
    }

    // Always attempt to fetch calendar if authenticated, to provide temporal context
    await _fetchCalendarEventsIfNeeded();
    if (_cachedCalendarEvents != null && _cachedCalendarEvents!.isNotEmpty) {
      commonContext += "\n\n--- Upcoming Calendar ---\n${_cachedCalendarEvents!.join('\n')}\n------------------------\n";
    }
    
    if (bubble.useGoogleContext && isGoogleAuthenticated) {
        _aiResponse = "Fetching Google Context...";
        notifyListeners();
        
        try {
          final emails = await _googleService.getRecentEmails(count: 3);
          final events = await _googleService.getUpcomingEvents(count: 3);
          
          commonContext += "\n\n--- Google Context ---\n";
          commonContext += "Recent Emails:\n${emails.join('\n')}\n";
          commonContext += "Upcoming Calendar Events:\n${events.join('\n')}\n";
          commonContext += "------------------------\n";
          
        } catch (e) {
          commonContext += "\n(Error fetching Google Context: $e)\n";
        }
    }
    
    // Clear list for actual results
    _aiResponseList = List.filled(promptsToRun.length, "");
    _lastFoundNotionUrl = null;
    _lastFoundNotionTitle = null;
    
    // Run Prompts Loop
    for (int i = 0; i < promptsToRun.length; i++) {
        String finalPrompt = promptsToRun[i];
        
        // --- Context Logic (Reused) ---
        String injectedContext = "";
        String? foundNotionUrl; // Capture URL
        bool skipLlm = false;

        if (bubble.useNotionContext) {
           _aiResponse = "Semantic Search (Notion)...";
           notifyListeners();

           // 1. Fetch Candidates (Headers)
           final headersResult = await _knowledgeRepository.getNotionHeaders();
           
           await headersResult.fold(
              (failure) async { injectedContext = "\n(Knowledge Access Failed: ${failure.message})\n"; },
              (headers) async {
                  if (headers.isEmpty) {
                     injectedContext = "\n(No Notion pages found. Import pages in Settings.)\n";
                     return;
                  }
                  
                  // 2. Select Best Match (AI)
                  final candidateList = headers.map((h) => "[ID: ${h['id']}] ${h['text']} (URL: ${h['url']})").join("\n");
                  
                  injectedContext += "\n\n--- Available Notion Pages (Index) ---\n$candidateList\n----------------------------------\n";
                  
                  final selectorPrompt = """
You are a precision retrieval system.
User Query: "$textToProcess"

Available Knowledge Base Entries:
$candidateList

Task:
Identify the SINGLE entry that best answers or relates to the User Query.
Return ONLY the ID of that entry.
If no entry is relevant, return "NONE".
""";
                  
                  String bestId = "NONE";
                  try {
                      print("DEBUG: Sending Selection Prompt via Flash model");
                      final selectionStream = await _geminiService.generateStream(selectorPrompt, model: "gemini-1.5-flash");
                      String fullResponse = "";
                      await for (final chunk in selectionStream) {
                         chunk.fold((l) => null, (r) => fullResponse += r);
                      }
                      
                      bestId = fullResponse.trim().replaceAll('"', '').replaceAll("'", "");
                      
                      if (bestId.contains("ID:")) {
                         bestId = bestId.split("ID:").last.trim();
                      }
                      print("DEBUG: AI Selected ID: $bestId");
                      
                  } catch (e) {
                      print("DEBUG: Selection Error: $e");
                  }
                  
                  // 3. Fetch Content
                  if (bestId != "NONE" && bestId.isNotEmpty) {
                      final contentResult = await _knowledgeRepository.getSegmentById(bestId);
                      contentResult.fold(
                        (f) => injectedContext += "\n(Failed to load selected page)\n",
                        (segment) {
                           injectedContext += "\n\n--- Notion Context (AI Selected) ---\n${segment.text}\n----------------------------------\n";
                           foundNotionUrl = segment.sourceUrl;

                           // Extract short answer and present directly (User Request)
                           final textContent = segment.text;
                           String shortAnswer = "";
                           final match = RegExp(r'Short Answer:\s*(.*)', caseSensitive: false).firstMatch(textContent);
                           if (match != null) {
                              shortAnswer = match.group(1)!.trim();
                           } else {
                              final lines = textContent.split('\n');
                              for (var line in lines) {
                                 final tl = line.trim();
                                 if (tl.isNotEmpty && !tl.startsWith('Notion Page:') && !tl.startsWith('----')) {
                                    shortAnswer = tl;
                                    break;
                                 }
                              }
                           }
                           if (shortAnswer.isEmpty) shortAnswer = segment.text;

                           final cleanUrl = (segment.sourceUrl != null && segment.sourceUrl!.isNotEmpty)
                               ? segment.sourceUrl!
                               : "https://notion.so/${segment.id.replaceAll('-', '')}";
                           
                           _lastFoundNotionUrl = cleanUrl;

                           final titleMatch = RegExp(r'Notion Page:\s*(.*)', caseSensitive: false).firstMatch(textContent);
                           _lastFoundNotionTitle = titleMatch != null ? titleMatch.group(1)!.trim() : "Notion Context";

                           _aiResponseList[i] = "$shortAnswer [more]($cleanUrl)";
                           if (i == 0) _aiResponse = _aiResponseList[i];
                           skipLlm = true;
                        } 
                      );
                  } else {
                      injectedContext += "\n(No relevant Notion page found)\n";
                  }
              }
           );
        }
        
        if (bubble.useGoogleContext && isGoogleAuthenticated) {
             // Fetch Google Context
        }

        if (!skipLlm) {
            final promptWithInput = "$finalPrompt\n$commonContext\n$injectedContext\n\n$textToProcess";
            
            if (i == 0) _aiResponse = "Analyzing..."; 
            notifyListeners();

            try {
                final stream = _activeAiService.generateStream(
                  promptWithInput, 
                  model: _selectedModel,
                  useSearch: bubble.useWebSearch
                );
               await for (final chunk in stream) {
                  chunk.fold(
                    (failure) => _aiResponseList[i] = "Error: ${failure.message}",
                    (text) {
                      _aiResponseList[i] += text;
                       if (i == 0) _aiResponse = _aiResponseList[i];
                    } 
                  );
                  notifyListeners();
               }
            } catch (e) {
               _aiResponseList[i] = "Error: $e";
            }
        }
        
        // Append Notion Link if applicable (and if we have one)
        // We need to fetch the URL again or store it.
        // Let's assume we re-fetch the segment since we have bestId (if we knew it).
        // Actually, let's just do a quick re-fetch of the Best ID if we are using Notion Context.
        // This is inefficient but safe without refactoring the whole closure structure above.
        // OR better: Just do the link logic right after the stream?
        // But we don't know the 'bestId' here, it was local to the closure.
        // Refactoring: Lift 'bestId' to outer scope of the loop?
        // Yes, let's rely on the AI Answer to already include it? No, user wants us to append.
        
        // Let's use a dirty trick: The `injectedContext` contains the text. 
        // We can't restart the stream.
        
        // CORRECT APPROACH: Move the Context Fetching logic OUT of the strings-only construction 
        // to a comprehensive `ContextResult` object before generating the prompt.
        // But for minimal disturbance:
        // Let's accept that we need to find the ID again or just store it in a class member temp?
        // No, race conditions.
        
        // Let's modifying the closure above to write to a local variable `String? foundUrl`.
    }
    
    // ... WAIT. The `injectedContext` logic above is INSIDE the loop (line 834).
    // And `bestId` is local.
    // AND I cannot easily edit the code "around" the loop efficiently with replace block 
    // without replacing the whole function.
    
    // I will replace the WHOLE LOOP body to introduce `notionUrl` variable.
    // See next chunk.
    
    // Finalize
    _isAiProcessing = false;
    // Pack into JSON if multiple
    if (_aiResponseList.length > 1) {
       _aiResponse = jsonEncode({"responses": _aiResponseList});
    } else {
       _aiResponse = _aiResponseList.first;
    }
    notifyListeners();
    
    _isAiProcessing = false;
    notifyListeners();
  }

  Future<void> pauseListeningForPrompt() async {
    if (_isListening && _transcriptionRepository is NativeTranscriptionRepository) {
      // Need a way to ensure it doesn't auto-restart while we are using the modal
      _isManualStop = true; 
      await _transcriptionRepository.stopListening();
    }
  }

  Future<void> resumeListeningAfterPrompt() async {
    if (_isAvailable && _transcriptionRepository is NativeTranscriptionRepository) {
      _isManualStop = false;
      await Future.delayed(const Duration(milliseconds: 500)); // allow speech_to_text to release mic
      await _transcriptionRepository.startListening();
    }
  }

  Future<void> processWithCustomPrompt(String customPromptText) async {
    final customBubble = AiBubble(
      id: 'custom_voice_prompt',
      name: 'Custom Voice Prompt',
      icon: '🎤',
      color: const Color(0xFFF44336), // Colors.red
      systemPrompt: customPromptText,
      useNotionContext: true,           // Give it full context capabilities
      useGoogleContext: true,
      useWebSearch: true,
      isGenerated: true,
    );
    // Use the existing process flow
    await processWithBubble(customBubble);
  }

  Future<void> toggleBackgroundMode(bool enable) async {
    if (_transcriptionRepository is NativeTranscriptionRepository) {
      final repo = _transcriptionRepository as NativeTranscriptionRepository;
      if (enable) {
        await repo.startBackgroundService();
      } else {
        await repo.stopBackgroundService();
      }
    }
  }

  // Snapshot State (Live-Freeze)
  int? _snapshotIndex;
  int? get snapshotIndex => _snapshotIndex;
  bool get isFrozen => _snapshotIndex != null;

  // The list of "New" items since the freeze.
  List<TranscriptionSegment> get liveSegments {
    if (_snapshotIndex != null && _snapshotIndex! < _segments.length) {
      return _segments.sublist(_snapshotIndex!);
    }
    return [];
  }

  void enterSelectionMode(String initialSelectionId) {
    if (_snapshotIndex == null) {
      _snapshotIndex = _segments.length; // Freeze at current end
    }
    toggleSelection(initialSelectionId);
  }

  void exitSelectionMode() {
    _snapshotIndex = null;
    clearSelection();
    notifyListeners();
  }

  // Notion State
  List<NotionPage> _availablePages = [];
  List<NotionPage> get availablePages => _availablePages;

  Future<void> fetchNotionPages() async {
    _isAiProcessing = true;
    _aiResponse = "Fetching pages from Notion...";
    _availablePages = []; // Clear previous
    notifyListeners();

    final keyResult = await _settingsRepository.getApiKey('notion');
    
    await keyResult.fold(
      (failure) async {
         _aiResponse = "Error: Notion API Key not set.";
      },
      (apiKey) async {
         final rootPageResult = await _settingsRepository.getPreference('notion_root_page');
         final rootPageId = rootPageResult.fold((_) => null, (val) => val as String?);
      
         // Pass '' as query, and rootPageId as named arg
         final result = await _notionRepository.searchPages("", rootPageId: rootPageId);
      
         // Load currently synced pages from DB to mark checkboxes
         final existingSegments = await _db.getAllSegments();
         final syncedIds = existingSegments
             .where((s) => s.type == SegmentType.notion)
             .map((s) => s.id)
             .toSet();

         final knownRootsResult = await _settingsRepository.getPreference('notion_known_roots');
         final Set<String> knownRootIds = knownRootsResult.fold(
           (_) => <String>{},
           (val) {
              try {
                 if (val is String && val.isNotEmpty) {
                    final list = jsonDecode(val) as List;
                    return list.map((e) => e.toString()).toSet();
                 }
              } catch (_) {}
              return <String>{};
           }
         );
         _syncedRootIds = knownRootIds;

         result.fold(
          (failure) {
            _aiResponse = "Notion Search Failed: ${failure.message}";
            notifyListeners();
          },
          (pages) {
            // Merge Import Selection State: if in known roots or has synced segments, keep checked
            for (var p in pages) {
               p.isSelected = knownRootIds.contains(p.id) || syncedIds.contains(p.id);
            }
            _availablePages = pages;
            _aiResponse = "Found ${pages.length} pages.";
            notifyListeners();
          }
         );
      }
    );
    
    _isAiProcessing = false;
    notifyListeners();
  }

  void togglePageSelection(String pageId) {
    final index = _availablePages.indexWhere((p) => p.id == pageId);
    if (index != -1) {
      _availablePages[index].isSelected = !_availablePages[index].isSelected;
      notifyListeners();
    }
  }

  Future<void> syncSelectedPages() async {
     _isAiProcessing = true;
     _aiResponse = "Syncing Notion pages...";
     notifyListeners();
     
     final selectedPages = _availablePages.where((p) => p.isSelected).toList();
     
     // 1. Get API Key
     final keyResult = await _settingsRepository.getApiKey('notion');
     
     await keyResult.fold(
       (failure) { _aiResponse = "Sync Failed: Auth Error"; },
       (apiKey) async {
          // 2. Call Import (True Sync)
          final importResult = await _notionRepository.importPages(selectedPages, apiKey);
          
          importResult.fold(
            (failure) => _aiResponse = "Sync Failed: ${failure.message}",
            (stats) async {
               _aiResponse = "Sync Complete:\n+ Added: ${stats.added}\n~ Updated: ${stats.updated}\n- Deleted: ${stats.deleted}\nTotal in DB: ${stats.total}";
               _syncedRootIds = selectedPages.map((p) => p.id).toSet();
               _availablePages = []; // Clear list after successful import
               await _loadSegments(); // Refresh timeline
            }
          );
      }
    );

    _isAiProcessing = false;
    notifyListeners();
  }

  Future<void> loadSyncedPages() async {
    _availablePages = [];
    final notionSegments = _segments.where((s) => s.type == SegmentType.notion).toList();
    
    // Load Known Roots filter
    Set<String> knownRoots = {};
    final rootsResult = await _settingsRepository.getPreference('notion_known_roots');
    rootsResult.fold(
      (_) {},
      (val) {
         if (val is String) {
            try {
               final List<dynamic> json = jsonDecode(val);
               knownRoots = json.cast<String>().toSet();
            } catch (e) { print("Error parsing roots: $e"); }
         }
      }
    );

    // Deduplicate by ID just in case
    final uniqueIds = <String>{};
    for (var s in notionSegments) {
       if (uniqueIds.contains(s.id)) continue;
       uniqueIds.add(s.id);

       // FILTER: Only show known roots (hides sub-items/rows)
       // If knownRoots is empty (legacy or first run), show all to be safe?
       // Or stricter: if not in knownRoots, hide.
       // Let's go with: if knownRoots has items, use it.
       if (knownRoots.isNotEmpty && !knownRoots.contains(s.id)) {
          continue; 
       }
       
       String title = "Untitled Page";
       final firstLine = s.text.split('\n').first;
       if (firstLine.startsWith("Notion Page: ")) {
          title = firstLine.replaceAll("Notion Page: ", "").trim();
       }
       
       _availablePages.add(NotionPage(
         id: s.id,
         title: title,
         url: s.sourceUrl ?? "",
         lastEdited: s.timestamp,
         isSelected: false 
       ));
    }
    notifyListeners();
  }

  Future<void> _loadLastSyncTime() async {
    final result = await _settingsRepository.getPreference('notion_last_sync');
    result.fold(
      (_) => null,
      (val) {
        if (val is String) {
          _lastSyncTime = DateTime.tryParse(val);
          notifyListeners();
        }
      }
    );
  }

  Future<void> backgroundSync({bool silent = true}) async {
    if (!silent) {
      _isAiProcessing = true;
      _aiResponse = "Syncing Notion...";
      notifyListeners();
    }

    try {
       // 1. Get API Key & Synced IDs
       final keyResult = await _settingsRepository.getApiKey('notion');
       final existingSegments = await _db.getAllSegments();
       final syncedIds = existingSegments
           .where((s) => s.type == SegmentType.notion)
           .map((s) => s.id)
           .toSet();

       if (syncedIds.isEmpty) {
          if (!silent) {
            _aiResponse = "Nothing to sync. Select pages first.";
            _isAiProcessing = false;
            notifyListeners();
          }
          return;
       }

       await keyResult.fold(
         (f) async { if (!silent) _aiResponse = "Sync Failed: Auth Error"; },
         (apiKey) async {
            // 2. Fetch Fresh Metadata (Recent changes)
            final rootPageResult = await _settingsRepository.getPreference('notion_root_page');
            final rootPageId = rootPageResult.fold((_) => null, (val) => val as String?);
            
            final searchResult = await _notionRepository.searchPages("", rootPageId: rootPageId);
            
            await searchResult.fold(
               (f) async { if (!silent) _aiResponse = "Sync Failed: ${f.message}"; },
               (freshPages) async {
                  // 3. Filter: Only sync pages we already have in DB (Updates)
                  // Note: This won't add NEW pages automatically (safety), only updates existing.
                  final pagesToSync = freshPages.where((p) => syncedIds.contains(p.id)).toList();
                  
                  if (pagesToSync.isNotEmpty) {
                     print("DEBUG: Background Syncing ${pagesToSync.length} pages...");
                     final importRes = await _notionRepository.importPages(pagesToSync, apiKey);
                     
                     // Handle Result
                     await importRes.fold(
                       (f) => null,
                       (stats) async {
                          print("DEBUG: Background Sync Stats: $stats");
                          if (stats.updated > 0 || stats.added > 0) {
                             await _loadSegments(); // Refresh if changes
                          }
                       }
                     );
                  } else {
                     print("DEBUG: No synced pages found in recent Notion changes.");
                  }
                  
                  // Update Time
                  _lastSyncTime = DateTime.now();
                  await _settingsRepository.setPreference('notion_last_sync', _lastSyncTime!.toIso8601String());
                  
                  if (!silent) {
                     _aiResponse = "Sync Complete.";
                  }
               }
            );
         }
       );
    } catch (e) {
       print("Background Sync Error: $e");
       if (!silent) _aiResponse = "Error: $e";
    }

    if (!silent) {
      _isAiProcessing = false;
      notifyListeners();
    } else {
      notifyListeners(); // Update timestamp UI
    }
  }
  // Volume Control (Brief Mute for Start/Stop Beeps)
  
  Future<void> refreshApiKeys() async {
    // Load Gemini
    final geminiResult = await _settingsRepository.getApiKey('gemini');
    geminiResult.fold(
      (_) {
        final envKey = (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
        if (envKey.isNotEmpty) _geminiService.setApiKey(envKey);
      },
      (key) {
        final cleanKey = key.trim();
        if (cleanKey.isNotEmpty) {
          _geminiService.setApiKey(cleanKey);
        } else {
          final envKey = (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
          if (envKey.isNotEmpty) _geminiService.setApiKey(envKey);
        }
      },
    );

    // Load Claude
    final claudeResult = await _settingsRepository.getApiKey('claude');
    claudeResult.fold(
      (_) {},
      (key) => _claudeService.setApiKey(key.trim()),
    );
    
    // Load Provider/Model Preferences
    final provider = await _settingsRepository.getPreference('selected_provider');
    provider.fold((_) {}, (val) => setProvider(val as String, save: false));
    
    final model = await _settingsRepository.getPreference('selected_model');
    model.fold((_) {}, (val) {
        String loadedModel = val as String;
        // VALIDATION: Removed stale check preventing new models
        setModel(loadedModel, save: false);
    });
  }
  
  Future<void> setProvider(String provider, {bool save = true}) async {
    _selectedProvider = provider;
    if (provider == 'claude') {
      _activeAiService = _claudeService;
      if (_selectedModel.contains('gemini')) _selectedModel = 'claude-3-5-sonnet-20241022';
    } else {
      _activeAiService = _geminiService;
      if (_selectedModel.contains('claude')) _selectedModel = 'gemini-2.5-flash';
    }
    notifyListeners();
    if (save) await _settingsRepository.setPreference('selected_provider', provider);
  }

  Future<void> setModel(String model, {bool save = true}) async {
    _selectedModel = model;
    notifyListeners();
    if (save) await _settingsRepository.setPreference('selected_model', model);
  }

  Future<String?> testClaudeConnection(String apiKey) async {
    try {
      final cleanKey = apiKey.trim();
      if (cleanKey.isEmpty) return "API Key cannot be empty.";
      final service = ClaudeAiService();
      service.setApiKey(cleanKey);
      String modelToTest = "claude-3-5-sonnet-20241022";
      if (_selectedModel.contains("claude")) {
         modelToTest = _selectedModel;
      }
      print("DEBUG: Testing Claude with model: $modelToTest");
      final result = await service.generate("Hello", model: modelToTest);
      return result.fold(
        (failure) => failure.message,
        (success) async {
          _claudeService.setApiKey(cleanKey);
          await _settingsRepository.setApiKey('claude', cleanKey);
          return null; // Success
        },
      );
    } catch (e) {
      return e.toString();
    }
  }
  
  // Native Audio Channel
  static const _audioChannel = MethodChannel('com.recall_me.native/audio');
  // Store previous volumes for streams: 1(System), 3(Music), 5(Notification)
  Map<int, int> _preMuteVolumes = {};

  Future<void> _muteBriefly() async {
    try {
      print("DEBUG: Muting briefly (System/Music/Notif)...");
      const streamsToMute = [1, 3, 5]; // System, Music, Notification

      for (final stream in streamsToMute) {
          // 1. Get current
          final currentVol = await _audioChannel.invokeMethod<int>('getVolume', {'stream': stream});
          if (currentVol != null) {
            _preMuteVolumes[stream] = currentVol;
          }
          // 2. Set to 0
          await _audioChannel.invokeMethod('setVolume', {
            'stream': stream,
            'volume': 0,
            'showUI': false,
          });
      }
      
      // 3. Schedule restore
      Future.delayed(const Duration(milliseconds: 1000), () async {
         print("DEBUG: Unmuting all...");
         _preMuteVolumes.forEach((stream, pVol) async {
             try {
               await _audioChannel.invokeMethod('setVolume', {
                 'stream': stream,
                 'volume': pVol,
                 'showUI': false,
               });
             } catch (e) {
               print("Error restoring stream $stream: $e");
             }
         });
         _preMuteVolumes.clear();
      });
    } catch (e) {
      print("Error muting: $e");
    }
  }

  // Override dispose to ensure volume is restored if we crash mid-mute
  @override
  void dispose() {
    // Attempt restore all
     _preMuteVolumes.forEach((stream, pVol) {
         _audioChannel.invokeMethod('setVolume', {
           'stream': stream,
           'volume': pVol,
           'showUI': false,
        });
     });
    _silenceTimer?.cancel();
    super.dispose();
  }



  Future<void> importSelectedPages() async {
    final selected = _availablePages.where((p) => p.isSelected).toList();
    
    if (selected.isEmpty) {
      _aiResponse = "No pages selected.";
      notifyListeners();
      return;
    }

    _isAiProcessing = true;
    _aiResponse = "Importing ${selected.length} pages...";
    notifyListeners();

    // Need API Key again for content fetch
    final keyResult = await _settingsRepository.getApiKey('notion');
    
    await keyResult.fold(
      (failure) async {
         _aiResponse = "Error: Notion API Key missing.";
      },
      (apiKey) async {
          final result = await _notionRepository.importPages(selected, apiKey);
          
          await result.fold(
            (failure) async {
              _aiResponse = "Import Failed: ${failure.message}";
            },
            (count) async {
              _aiResponse = "Success! Synced $count items (including database rows).";
              _availablePages = []; // Clear list after successful import
              await _loadSegments(); // Refresh timeline
            }
          );
      }
    );

    _isAiProcessing = false;
    notifyListeners();
  }



  // Background Service Control
  Future<void> startBackgroundService() async {
    await BackgroundServiceManager.start();
    _aiResponse = "Background Service Started";
    notifyListeners();
  }

  Future<void> stopBackgroundService() async {
    await BackgroundServiceManager.stop();
    _aiResponse = "Background Service Stopped";
    notifyListeners();
  }

  // Suggestions State
  List<AiBubble> _suggestedBubbles = [];
  List<AiBubble> get suggestedBubbles => _suggestedBubbles;
  int _suggestedBubbleCount = 2; // Default
  int get suggestedBubbleCount => _suggestedBubbleCount;

  Future<void> setSuggestedBubbleCount(int count) async {
    _suggestedBubbleCount = count;
    notifyListeners();
    await _settingsRepository.setPreference('suggested_bubble_count', count.toDouble());
  }

  Future<void> _generateSuggestions(String text) async {
    // Basic debounce or check to avoid spamming API on every tap?
    // For V2, let's just run it. 
    _suggestedBubbles = []; // Clear old
    notifyListeners();

    // Load setting if not loaded
    // (Assuming loaded in _init or we load here)
    final pref = await _settingsRepository.getPreference('suggested_bubble_count');
    pref.fold((_) {}, (val) => _suggestedBubbleCount = (val as double).toInt()); // Slider saves as double often

    if (_suggestedBubbleCount <= 0) return;

    await _fetchCalendarEventsIfNeeded();
    String contextString = "";
    if (_conversationStarter != null && _conversationStarter!.isNotEmpty) {
      contextString += "User's current context/goal: $_conversationStarter\n";
    }
    if (_cachedCalendarEvents != null && _cachedCalendarEvents!.isNotEmpty) {
      contextString += "User's upcoming calendar events:\n${_cachedCalendarEvents!.join('\n')}\n";
    }

    final prompt = """
Analyze the following text and suggest $_suggestedBubbleCount short, actionable AI tasks that the user might want to perform on it.
Return ONLY a JSON array of objects with keys: "name", "icon" (emoji), "prompt" (system prompt for the task).
Example: [{"name": "Reply", "icon": "✉️", "prompt": "Draft a polite reply to this message."}]

${contextString.isNotEmpty ? "---\nAdditional Context to heavily influence suggestions:\n$contextString\n---\n" : ""}
Text:
$text
""";

    try {
      // Using selected model
      final stream = _activeAiService.generateStream(prompt, model: _selectedModel);
      String fullResponse = "";
      await for (final chunk in stream) {
         chunk.fold((failure) => print("Stream Failure: ${failure.message}"), (t) => fullResponse += t);
      }
      
      // Clean and Parse JSON
      fullResponse = fullResponse.replaceAll('```json', '').replaceAll('```', '').trim();
      
      if (fullResponse.isEmpty) {
        print("Suggestion Warning: Empty response from AI");
        return;
      }

      final List<dynamic> json = jsonDecode(fullResponse);
      
      _suggestedBubbles = json.map((item) => AiBubble(
        id: 'suggested_${DateTime.now().millisecondsSinceEpoch}_${item['name']}',
        name: item['name'],
        icon: item['icon'],
        color: Colors.deepPurpleAccent, // Distinct color
        systemPrompt: item['prompt'],
        isGenerated: true,
        useWebSearch: true, // Auto-enable search for suggestions
      )).toList();
      
      notifyListeners();
    } catch (e) {
      print("Suggestion Error: $e");
    }
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
    
    // Trigger Suggestions if selected
    if (_selectedIds.isNotEmpty) {
       final textToProcess = _segments
        .where((s) => _selectedIds.contains(s.id))
        .map((s) => s.text)
        .join("\n\n");
       if (textToProcess.isNotEmpty) {
          // Debounce could be good here, but for now direct call
          _generateSuggestions(textToProcess);
       }
    } else {
      _suggestedBubbles = [];
    }
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  // Editing Logic
  void startEditing(String id) {
    _editingSegmentId = id;
    notifyListeners();
  }

  void cancelEditing() {
    _editingSegmentId = null;
    notifyListeners();
  }

  void saveEdit(String id, String newText) {
    final index = _segments.indexWhere((s) => s.id == id);
    if (index != -1) {
      _segments[index] = TranscriptionSegment(
        id: _segments[index].id,
        text: newText,
        timestamp: _segments[index].timestamp,
        isSelected: _segments[index].isSelected,
      );
    }
    _editingSegmentId = null;
    notifyListeners();
  }

  Future<String?> testGeminiConnection(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) return "API Key cannot be empty.";

    final modelsToTry = [
      'gemini-3.5-flash',
      'gemini-3.1-pro',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
    ];
    List<String> errors = [];

    // 1. Try known models
    for (final modelName in modelsToTry) {
       try {
        final model = GenerativeModel(model: modelName, apiKey: cleanKey);
        final response = await model.generateContent([Content.text("Hello")]);
        if (response.text != null) {
          _geminiService.setApiKey(cleanKey);
          await _settingsRepository.setApiKey('gemini', cleanKey);
          return null; // Success
        }
      } catch (e) {
        errors.add("$modelName: ${e.toString()}");
      }
    }
    
    // 2. If all failed, list available models via HTTP with detailed error parsing
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$cleanKey');
      final response = await http.get(
        url,
        headers: {
          'x-goog-api-key': cleanKey,
        },
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> models = json['models'] ?? [];
        final modelNames = models.map((m) => m['name'].toString().replaceFirst('models/', '')).join(', ');
        
        return "Connected to Google AI Studio, but standard models were not accessible.\n\nAVAILABLE MODELS ON YOUR KEY:\n$modelNames\n\nErrors:\n${errors.join('\n')}";
      } else {
        String detail = response.body;
        try {
          final errJson = jsonDecode(response.body);
          if (errJson['error'] != null && errJson['error']['message'] != null) {
            detail = errJson['error']['message'];
          }
        } catch (_) {}
        return "Google API error (${response.statusCode}): $detail\n\n(Tip: Generate a fresh free Gemini API key at https://aistudio.google.com/app/apikey and ensure no spaces are copied.)";
      }
    } catch (e) {
       return "Connection failed: $e\n\nErrors:\n${errors.join('\n')}";
    }
  }
  Future<void> runFollowUp(String label, String promptInstruction) async {
    String textToAnalyze = _segments
        .where((s) => _selectedIds.contains(s.id))
        .map((s) => s.text)
        .join("\n\n");

    if (textToAnalyze.isEmpty) {
       // Fallback: If viewing an existing AI response, analyze THAT.
       if (isViewingExistingAi || _aiResponse.isNotEmpty) {
         textToAnalyze = _aiResponse;
       } else {
         return;
       }
    }

    _isAiProcessing = true;
    _aiResponseList = [];
    _aiResponse = "Running $label..."; 
    _viewingAiSegmentId = null; 
    notifyListeners();

    final prompt = "$promptInstruction\n\nText:\n$textToAnalyze";

    // Stage: Follow Up (Flash)
    final stream = _activeAiService.generateStream(prompt, model: _selectedModel);
    
    _aiResponse = ""; // Clear "Running..."
    notifyListeners();

    await for (final chunk in stream) {
      chunk.fold(
        (failure) {
           _aiResponse = "Error: ${failure.message}";
        },
        (textChunk) {
           _aiResponse += textChunk;
        }
      );
      notifyListeners();
    }
    
    _isAiProcessing = false;
    notifyListeners();
  }
}

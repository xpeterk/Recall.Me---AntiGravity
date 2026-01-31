import 'package:flutter/foundation.dart';
import 'dart:async'; // For Timer
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
import '../data/native_transcription_repository.dart';
import '../../../../core/services/background_service_manager.dart';
import '../../settings/domain/ai_bubble.dart';
import '../../knowledge/domain/notion_page.dart';

class TranscriptionViewModel extends ChangeNotifier {
  final TranscriptionRepository _transcriptionRepository;
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
  
  bool _isListening = false;
  bool _isAvailable = false;

  String get text => _text;
  // Search State
  String _searchQuery = "";
  String get searchQuery => _searchQuery;

  // System Message State
  bool _showSystemMessages = true;
  bool get showSystemMessages => _showSystemMessages;

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
    var list = _segments;

    // Filter System Messages
    if (!_showSystemMessages) {
      list = list.where((s) => s.type != SegmentType.notion).toList();
    }

    // Filter Search
    if (_searchQuery.isNotEmpty) {
      list = list.where((s) => s.text.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    if (_snapshotIndex != null && _snapshotIndex! <= _segments.length) {
      // Logic for snapshot with search/filter
      if (_searchQuery.isEmpty) {
         // Re-apply filter to sublist if needed, or just slice filtered list?
         // Simplest: Slice the ORIGINAL list then filter, or Filter the SLICED list?
         // We want to show "what was there at freeze time".
         // So: Slice -> Filter.
         // But `list` is already filtered above based on _segments. 
         // Let's refine:
         var frozenList = _segments.sublist(0, _snapshotIndex);
         if (!_showSystemMessages) {
            frozenList = frozenList.where((s) => s.type != SegmentType.notion).toList();
         }
         return frozenList;
      }
    }
    return list;
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
  String get aiResponse => _aiResponse;
  List<String> get aiResponseList => _aiResponseList;
  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  bool get isAiProcessing => _isAiProcessing;
  Stream<double> get soundLevelStream => _transcriptionRepository.soundLevelStream;
  
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
    AiService? aiService,
    KnowledgeRepository? knowledgeRepository,
    LocalDatabase? database,
    NotionRepository? notionRepository,
    SettingsRepository? settingsRepository,
    GoogleIntegrationService? googleService,
  })  : _transcriptionRepository = repository ?? NativeTranscriptionRepository(),
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

  void _init() async {
    await refreshApiKeys();
    await _loadSegments(); // Load from DB
    await _loadBubbles();
    _loadLastSyncTime();

    // Trigger Background Sync (Silent)
    backgroundSync(silent: true);

    final result = await _transcriptionRepository.initialize();

    result.fold(
      (failure) {
        _text = "Speech initialization failed: ${failure.message}";
        notifyListeners();
      },
      (available) {
        _isAvailable = available;
        notifyListeners();
        
        // Listen to streams
        _transcriptionRepository.transcriptionStream.listen((result) {
          // Reset silence timer on every new packet
          _silenceTimer?.cancel();
          _silenceTimer = Timer(const Duration(seconds: 3), _onSilence);
          
          // Calculate "Pending" text by subtracting what we've already committed
          final fullText = result.text;
          print("DEBUG: STT Stream: $fullText (len: ${fullText.length}) | Offset: $_processedOffset");
          
          if (fullText.length >= _processedOffset) {
             _text = fullText.substring(_processedOffset);
          } else {
             // Edge case: Engine reset internal buffer?
             print("DEBUG: STT Buffer Reset Detected!");
             _processedOffset = 0;
             _text = fullText;
          }
          
          notifyListeners();

          // We ignore isFinal here because we are handling silence manually (Option 2)
        });
        
        _transcriptionRepository.isListeningStream.listen((listening) async {
             // ... existing loop logic ...
             if (!listening) {
                _silenceTimer?.cancel(); // Cancel timer if stopped
                _onSilence(); // Force commit pending text
                
                if (!_isManualStop && _isAvailable) {
                    // Auto-restart logic (existing)
                    if (_isRestarting) return;
                    _isRestarting = true;
                    _processedOffset = 0; // Reset offset on new session
                    await Future.delayed(const Duration(milliseconds: 300));
                    await _muteBriefly(); // Suppress beep on auto-restart
                    await _transcriptionRepository.startListening();
                    _isRestarting = false;
                }
             } else {
                 // Started
                 if (!_isRestarting) {
                   _isListening = listening;
                   notifyListeners();
                 }
             }
        });
      },
    );
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
  List<AiBubble> get allBubbles => [..._bubbles, ..._suggestedBubbles];

  Future<void> _loadSegments() async {
    _segments = await _db.getAllSegments();
    print("DEBUG: Loaded ${_segments.length} segments from DB.");
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
    result.fold(
      (failure) {
         // Error or empty, load defaults if empty
      },
      (data) {
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
          
          // Ensure "Relation Info" exists (New addition)
          if (!_bubbles.any((b) => b.id == 'default_relation')) {
            _bubbles.add(AiBubble(
              id: 'default_relation',
              name: 'Relation Info',
              icon: '🔗',
              color: const Color(0xFF009688), // Colors.teal
              systemPrompt: "Identify the relationships between people, organizations, and concepts in the text.",
            ));
            needsSave = true;
          }
          
          // Ensure "Reference" exists (New addition 🐘)
          if (!_bubbles.any((b) => b.id == 'default_reference')) {
            _bubbles.add(AiBubble(
              id: 'default_reference',
              name: 'Reference',
              icon: '🐘',
              color: const Color(0xFF795548), // Colors.brown
              systemPrompt: "Identify and list all references, citations, external links, and key entities mentioned in the text.",
            ));
            needsSave = true;
          }

          // Ensure "Ask AI" exists (New addition 🤖)
          if (!_bubbles.any((b) => b.id == 'default_general_ai')) {
             _bubbles.add(AiBubble(
              id: 'default_general_ai',
              name: 'Ask AI',
              icon: '🤖',
              color: const Color(0xFF607D8B), // Colors.blueGrey
              systemPrompt: "You are a helpful AI assistant. Answer the user's prompt freely.",
            ));
            needsSave = true;
          }

          // Ensure "Notion Search" exists (User Request)
          if (!_bubbles.any((b) => b.id == 'default_notion_search')) {
             _bubbles.add(AiBubble(
              id: 'default_notion_search',
              name: 'Notion Search',
              icon: '🔎',
              color: const Color(0xFFE91E63), 
              systemPrompt: "Review the provided Notion Index. Find the best possible answer for the selected text by displaying a Page title and Link to the top 5 best possible Notion answers. For speed, do not include summaries, ONLY the Title and Link.",
              useNotionContext: true,
              isMultiOutput: true,
              additionalPrompts: ["Review the provided Notion Index. Display the Page title and Link to the next 5 best possible Notion answers. For speed, do not include summaries, ONLY the Title and Link."],
            ));
            needsSave = true;
          }

          if (needsSave) {
            _saveBubbles();
          }
        }
        notifyListeners();
      }
    );
  }

  void _createDefaultBubbles() {
    _bubbles = [
      // 1. Answer (User Spec)
      AiBubble(
        id: 'default_answer_v2',
        name: 'Answer',
        icon: '💡',
        color: const Color(0xFFFFC107), // Amber
        systemPrompt: "Provide the most likely answer based on the selected text and answer in a short sentance.",
        isMultiOutput: true,
        useWebSearch: true,
        additionalPrompts: ["Provide the next most likely answer based on the selected text and answer in a short sentance."],
      ),
      // 2. Ask Notion (User Spec)
      AiBubble(
        id: 'default_notion_v2',
        name: 'Ask Notion',
        icon: 'assets/images/notion_logo.png',
        color: const Color(0xFFE91E63), // Pink
        systemPrompt: "Provide the most likely answer using provided Notion context and answer in a short sentance.",
        useNotionContext: true,
        isMultiOutput: true,
        useWebSearch: false,
        additionalPrompts: ["Provide the next most likely answer using provided Notion context and answer in a short sentance"],
      ),
      // 3. Related (User Spec)
      AiBubble(
        id: 'default_related',
        name: 'Related',
        icon: '🧠',
        color: const Color(0xFF9C27B0), // Purple
        systemPrompt: "Find an interesting fact or observation to make me appear smart based related the selected text and answer in a short sentance.",
        isMultiOutput: true,
        useWebSearch: true,
        additionalPrompts: ["Find a the next most likely interesting fact or observation to make me appear smart based related the selected text and answer in a short sentance."],
      ),
      // 4. Notion Search (Top 5)
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
      // Keep useful extras
      AiBubble(
        id: 'default_general_ai',
        name: 'Ask AI',
        icon: '🤖',
        color: const Color(0xFF607D8B), // BlueGrey
        systemPrompt: "You are a helpful AI assistant. Answer the user's prompt freely.",
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
    
    for (var sentence in sentences) {
      if (sentence.trim().isEmpty) continue;
      
      final newSegment = TranscriptionSegment(
        id: DateTime.now().millisecondsSinceEpoch.toString() + sentence.hashCode.toString(), // Unique ID per chunk
        text: sentence.trim(),
        timestamp: DateTime.now(),
        type: SegmentType.audio,
      );

      print("DEBUG: Inserting Segment: ${newSegment.id}");
      await _db.insertSegment(newSegment);
    }
    
    print("DEBUG: Commit Complete. Reloading...");
    await _loadSegments(); // Refresh list
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
      await _transcriptionRepository.stopListening();
    } else {
       // Clear placeholder text when starting
      if (_text.contains("Press the mic")) _text = "";
      _isManualStop = false; // Reset flag
      
      await _muteBriefly(); // Mute beep on start
      await _transcriptionRepository.startListening();
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
    
    // Run Prompts Loop
    for (int i = 0; i < promptsToRun.length; i++) {
        String finalPrompt = promptsToRun[i];
        
        // --- Context Logic (Reused) ---
        String injectedContext = "";
        String? foundNotionUrl; // Capture URL

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
                  // Enhanced: Include URL in the candidate list so AI knows it
                  final candidateList = headers.map((h) => "[ID: ${h['id']}] ${h['text']} (URL: ${h['url']})").join("\n");
                  
                  // Inject the FULL INDEX into the context so the AI can "list top X answers" if asked
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
                      // Use non-streaming for short response
                      print("DEBUG: Sending Selection Prompt");
                      final selectionStream = _activeAiService.generateStream(selectorPrompt, model: _selectedModel);
                      String fullResponse = "";
                      await for (final chunk in selectionStream) {
                         chunk.fold((l) => null, (r) => fullResponse += r);
                      }
                      
                      // Extract ID (Tricky: AI might be chatty. grep for ID?)
                      // Assume AI follows instruction "Return ONLY the ID".
                      // Cleanup: Remove whitespace/quotes
                      bestId = fullResponse.trim().replaceAll('"', '').replaceAll("'", "");
                      
                      // Fallback: If AI says "ID: 123", extract 123.
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
             // Note: Doing this INSIDE the loop means we might fetch it multiple times if multi-output.
             // Optimization: Fetch once outside loop.
        }

        // Simpler Prompt Construction for loop
        final promptWithInput = "$finalPrompt\n$commonContext\n$injectedContext\n\n$textToProcess";
        
        // Show status
        if (i == 0) _aiResponse = "Analyzing..."; 
        notifyListeners();

        // Stream (Blocking for sequential simplicity)
        // Note: For parallel, we'd need multiple streams. Sequential is safer for rate limits.
        try {
            final stream = _activeAiService.generateStream(
              promptWithInput, 
              model: _selectedModel,
              useSearch: bubble.useWebSearch
            ); // Pass search flag
           await for (final chunk in stream) {
              chunk.fold(
                (failure) => _aiResponseList[i] = "Error: ${failure.message}",
                (text) {
                  _aiResponseList[i] += text;
                   // Update main _aiResponse for simple views if it's the first one
                   if (i == 0) _aiResponse = _aiResponseList[i];
                } 
              );
              notifyListeners();
           }
        } catch (e) {
           _aiResponseList[i] = "Error: $e";
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

         result.fold(
          (failure) {
            _aiResponse = "Notion Search Failed: ${failure.message}";
            notifyListeners();
          },
          (pages) {
            // Merge Import Selection State
            // If it's in DB, it's "Selected" (Synced)
            for (var p in pages) {
               p.isSelected = syncedIds.contains(p.id);
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
      (_) {},
      (key) => _geminiService.setApiKey(key),
    );

    // Load Claude
    final claudeResult = await _settingsRepository.getApiKey('claude');
    claudeResult.fold(
      (_) {},
      (key) => _claudeService.setApiKey(key),
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
      final service = ClaudeAiService();
      service.setApiKey(apiKey);
      // Use selected model if valid Claude model, else default to latest
      String modelToTest = "claude-3-5-sonnet-20241022";
      if (_selectedModel.contains("claude")) {
         modelToTest = _selectedModel;
      }
      print("DEBUG: Testing Claude with model: $modelToTest");
      final result = await service.generate("Hello", model: modelToTest);
      return result.fold(
        (failure) => failure.message,
        (success) => null, // Success
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

    final prompt = """
Analyze the following text and suggest $_suggestedBubbleCount short, actionable AI tasks that the user might want to perform on it.
Return ONLY a JSON array of objects with keys: "name", "icon" (emoji), "prompt" (system prompt for the task).
Example: [{"name": "Reply", "icon": "✉️", "prompt": "Draft a polite reply to this message."}]

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
    final modelsToTry = ['gemini-2.5-flash', 'gemini-2.5-pro'];
    List<String> errors = [];

    // 1. Try known models
    for (final modelName in modelsToTry) {
       try {
        final model = GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([Content.text("Hello")]);
        if (response.text != null) {
          return null; // Success
        }
      } catch (e) {
        errors.add("$modelName: ${e.toString()}");
      }
    }
    
    // 2. If all failed, list available models via HTTP
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> models = json['models'];
        final modelNames = models.map((m) => m['name'].toString().replaceFirst('models/', '')).join(', ');
        
        return "Failed to connect to standard models.\n\nAVAILABLE MODELS:\n$modelNames\n\nErrors:\n${errors.join('\n')}";
      } else {
        return "Failed to connect AND failed to list models (${response.statusCode}).\nErrors:\n${errors.join('\n')}";
      }
    } catch (e) {
       return "Failed to connect and failed to list models (Exception: $e).\nErrors:\n${errors.join('\n')}";
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

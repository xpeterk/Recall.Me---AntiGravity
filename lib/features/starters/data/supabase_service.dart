import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../settings/domain/settings_repository.dart';
import '../domain/models/starter_item.dart';
import '../domain/models/notion_library_note.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient? _client;
  bool _isInitializing = false;
  bool _isConfigured = false;
  String? _configuredUrl;
  RealtimeChannel? _realtimeChannel;

  bool get isConfigured => _isConfigured && _client != null;
  SupabaseClient? get client => _client;
  String? get configuredUrl => _configuredUrl;

  /// Reads credentials from .env or SettingsRepository and initializes Supabase client
  Future<bool> initialize({SettingsRepository? settingsRepository, bool force = false}) async {
    if (_client != null && !force) return true;
    if (_isInitializing) return false;
    _isInitializing = true;

    try {
      String? url = (dotenv.env['SUPABASE_URL'] ??
              dotenv.env['VITE_SUPABASE_URL'] ??
              const String.fromEnvironment('SUPABASE_URL'))
          .trim();
      if (url.isEmpty) url = null;

      String? anonKey = (dotenv.env['SUPABASE_ANON_KEY'] ??
              dotenv.env['SUPABASE_KEY'] ??
              dotenv.env['VITE_SUPABASE_PUBLISHABLE_KEY'] ??
              const String.fromEnvironment('SUPABASE_ANON_KEY'))
          .trim();
      if (anonKey.isEmpty) anonKey = null;

      if (settingsRepository != null && (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty)) {
        final prefUrl = await settingsRepository.getPreference('supabase_url');
        prefUrl.fold((_) {}, (val) {
          if (val is String && val.trim().isNotEmpty) url = val.trim();
        });

        final apiKeyRes = await settingsRepository.getApiKey('supabase');
        apiKeyRes.fold((_) {}, (val) {
          if (val.trim().isNotEmpty) anonKey = val.trim();
        });
      }

      if (url != null && url!.isNotEmpty && anonKey != null && anonKey!.isNotEmpty) {
        if (Supabase.instance.isInitialized) {
          _client = Supabase.instance.client;
          _isConfigured = true;
          _configuredUrl = url;
          return true;
        }

        await Supabase.initialize(
          url: url!,
          anonKey: anonKey!,
          debug: false,
        );
        _client = Supabase.instance.client;
        _isConfigured = true;
        _configuredUrl = url;
        return true;
      }
    } catch (e) {
      _isConfigured = false;
    } finally {
      _isInitializing = false;
    }

    return false;
  }

  /// Subscribes to real-time changes on notion_notes, notion_pages, and starters tables
  void subscribeToRealtimeChanges(VoidCallback onDataChanged) {
    if (!isConfigured || _client == null) return;
    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = _client!.channel('public:notion_library_sync')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notion_notes',
          callback: (_) => onDataChanged(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notion_pages',
          callback: (_) => onDataChanged(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'starters',
          callback: (_) => onDataChanged(),
        )
        ..subscribe();
    } catch (_) {}
  }

  /// Fetches starters from Supabase 'starters' table
  Future<List<StarterItem>> fetchStarters() async {
    if (!isConfigured) return [];
    try {
      final response = await _client!
          .from('starters')
          .select()
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((row) => StarterItem.fromMap(Map<String, dynamic>.from(row)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Inserts a starter into the Supabase 'starters' table
  Future<StarterItem?> saveStarter(StarterItem starter) async {
    if (!isConfigured) return null;
    try {
      final payload = {
        if (starter.id.isNotEmpty && !starter.id.startsWith('local_')) 'id': starter.id,
        'title': starter.title,
        'summary': starter.summary,
        'category': starter.category,
        'angles': starter.angles,
        'notion_page_ids': starter.notionPageIds,
        'created_at': starter.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client!
          .from('starters')
          .upsert(payload)
          .select()
          .single();

      return StarterItem.fromMap(Map<String, dynamic>.from(response), isNew: true);
    } catch (_) {
      return null;
    }
  }

  /// Fetches synced Notion notes from Supabase
  Future<List<NotionLibraryNote>> fetchNotionNotes() async {
    if (!isConfigured) return [];
    try {
      // Try 'notion_notes' table first, then 'notion_pages'
      dynamic response;
      try {
        response = await _client!
            .from('notion_notes')
            .select()
            .order('edited_at', ascending: false);
      } catch (_) {
        response = await _client!
            .from('notion_pages')
            .select()
            .order('created_at', ascending: false);
      }

      if (response is List) {
        return response
            .map((row) => NotionLibraryNote.fromMap(Map<String, dynamic>.from(row)))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}

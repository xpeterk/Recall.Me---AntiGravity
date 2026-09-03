import 'package:dartz/dartz.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/failures.dart';
import 'package:sqflite/sqflite.dart';
import '../../recall/data/local_database.dart';
import '../domain/settings_repository.dart';
import '../domain/dynamic_starter.dart';

class NativeSettingsRepository implements SettingsRepository {
  final LocalDatabase _db;

  NativeSettingsRepository({LocalDatabase? db}) : _db = db ?? LocalDatabase();

  @override
  Future<Either<Failure, String>> getApiKey(String service) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString('api_key_$service');
      if (key != null) {
        return Right(key);
      } else {
        return Left(CacheFailure("API Key for $service not found"));
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // ... (Keep existing methods for preferences/keys unchanged) ...

  @override
  Future<Either<Failure, dynamic>> getPreference(String key) async {
     try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.get(key);
      if (value != null) {
        return Right(value);
      } else {
        return Left(CacheFailure("Preference $key not found"));
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setApiKey(String service, String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_key_$service', key);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setPreference(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
       return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<dynamic>>> getBubbles() async {
    try {
      final bubbles = await _db.getAllBubbles();
      return Right(bubbles);
    } catch (e) {
      return Left(CacheFailure("DB Error: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> saveBubbles(List<dynamic> bubblesData) async {
    try {
      // Robust Persistence Strategy: Wipe and Replace
      // This ensures the DB exactly matches the provided list, handling deletions,
      // updates, and insertions reliably without complex diff logic.
      final db = await _db.database;
      
      await db.transaction((txn) async {
        // 1. Clear existing bubbles
        await txn.delete('bubbles');
        
        // 2. Insert all current bubbles
        for (var bubble in bubblesData) {
          if (bubble is Map<String, dynamic>) {
            // Re-map to snake_case for DB is handled by LocalDatabase.insertInsert
            // BUT here we are inside a txn using raw insert? 
            // LocalDatabase.insertBubble handles mapping.
            // We should use the helper logic if possible, but LocalDatabase.insertBubble
            // gets a new DB instance.
            // Best way: duplicate the mapping logic here for the transaction 
            // OR iterate and await specific inserts (slower but safer reusing code).
            // Since we are in a transaction block on the 'db', calling _db.insertBubble might await the lock?
            // Actually, SQFlite supports concurrent calls but transaction gives us an exclusive executor 'txn'.
            // if we call _db.insertBubble, it calls await database (which gets the db) then db.insert.
            // It won't be part of THIS transaction 'txn'.
            
            // So we must manually insert using 'txn' to be atomic.
            
           final dbMap = {
              'id': bubble['id'],
              'name': bubble['name'],
              'icon': bubble['icon'],
              'color': bubble['color'],
              'system_prompt': bubble['systemPrompt'],
              'is_enabled': bubble['isEnabled'],
              'use_notion_context': bubble['useNotionContext'],
              'use_google_context': bubble['useGoogleContext'],
              'use_web_search': bubble['useWebSearch'],
              'linked_page_ids': bubble['linkedPageIds'],
              'is_multi_output': bubble['isMultiOutput'],
              'additional_prompts': bubble['additionalPrompts'],
              'is_generated': bubble['isGenerated'],
            };
            await txn.insert(
              'bubbles', 
              dbMap, 
              conflictAlgorithm: ConflictAlgorithm.replace
            );
          }
        }
      });
      
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure("DB Error: $e"));
    }
  }

  @override
  Future<Either<Failure, void>> saveDynamicStarters(List<dynamic> startersData) async {
    try {
      final jsonList = startersData.cast<DynamicStarter>().map((s) => s.toJson()).toList();
      await setPreference('custom_starters', jsonEncode(jsonList));
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure("Failed to save dynamic starters: $e"));
    }
  }

  @override
  Future<Either<Failure, List<dynamic>>> getDynamicStarters() async {
    try {
      final result = await getPreference('custom_starters');
      return result.fold(
        (f) => const Right([]), // Return empty list on failure/not found
        (jsonString) {
           if (jsonString == null || jsonString.toString().isEmpty) return const Right([]);
           final List<dynamic> jsonList = jsonDecode(jsonString.toString());
           final starters = jsonList.map((json) => DynamicStarter.fromJson(json)).toList();
           return Right(starters);
        }
      );
    } catch (e) {
      return Left(CacheFailure("Failed to load dynamic starters: $e"));
    }
  }
}

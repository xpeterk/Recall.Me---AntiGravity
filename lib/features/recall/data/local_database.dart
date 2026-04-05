import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/transcription_segment.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  static Database? _database;

  factory LocalDatabase() => _instance;

  LocalDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('recall_me.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add columns for dynamic bubbles (Legacy v2)
      await db.execute("ALTER TABLE segments ADD COLUMN bubble_name TEXT");
      await db.execute("ALTER TABLE segments ADD COLUMN bubble_icon TEXT");
    }
    if (oldVersion < 3) {
      // Create Bubbles Table (v3)
      // ... (Defined below in createDB)
      await db.execute('''
        CREATE TABLE bubbles (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          color INTEGER NOT NULL,
          system_prompt TEXT NOT NULL,
          is_enabled INTEGER NOT NULL,
          use_notion_context INTEGER NOT NULL,
          use_google_context INTEGER NOT NULL,
          linked_page_ids TEXT,
          is_multi_output INTEGER NOT NULL,
          additional_prompts TEXT,
          is_generated INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      // Add Web Search column (v4)
      await db.execute("ALTER TABLE bubbles ADD COLUMN use_web_search INTEGER DEFAULT 0");
    }
    if (oldVersion < 5) {
       // Add included_segment_ids for summaries (v5)
       await db.execute("ALTER TABLE segments ADD COLUMN included_segment_ids TEXT");
    }
    if (oldVersion < 6) {
       // Add confidence score (v6) - Default to 1.0 (High confidence for legacy)
       await db.execute("ALTER TABLE segments ADD COLUMN confidence REAL DEFAULT 1.0");
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE segments (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        type INTEGER NOT NULL,
        source_url TEXT,
        is_synced INTEGER NOT NULL,
        bubble_name TEXT,
        bubble_icon TEXT,
        included_segment_ids TEXT,
        confidence REAL DEFAULT 1.0
      )
    ''');

    await db.execute('''
      CREATE TABLE bubbles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        system_prompt TEXT NOT NULL,
        is_enabled INTEGER NOT NULL,
        use_notion_context INTEGER NOT NULL,
        use_google_context INTEGER NOT NULL,
        use_web_search INTEGER NOT NULL,
        linked_page_ids TEXT,
        is_multi_output INTEGER NOT NULL,
        additional_prompts TEXT,
        is_generated INTEGER NOT NULL
      )
    ''');
  }

  Future<void> insertSegment(TranscriptionSegment segment) async {
    final db = await database;
    await db.insert(
      'segments', 
      segment.toMap(), 
      conflictAlgorithm: ConflictAlgorithm.replace
    );
  }

  Future<List<Map<String, dynamic>>> getSegmentMetadata(SegmentType type) async {
    final db = await database;
    // Optimize: Only fetch ID, source_url, and the first 200 chars of text (for title extraction)
    // Note: sqflite doesn't support SUBSTR well in all versions, so we fetch text but rely on specific projection if possible.
    // For now, selecting specific columns avoids fetching other potential large blobs if we had them.
    final result = await db.query(
      'segments',
      columns: ['id', 'text', 'source_url'], 
      where: 'type = ?',
      whereArgs: [type.index],
    );
    return result;
  }

  Future<List<TranscriptionSegment>> getAllSegments() async {
    final db = await database;
    final result = await db.query('segments', orderBy: 'timestamp DESC');
    return result.map((json) => TranscriptionSegment.fromMap(json)).toList();
  }

  Future<List<TranscriptionSegment>> searchSegments(String query) async {
    final db = await database;
    final result = await db.query(
      'segments',
      where: 'text LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'timestamp DESC',
    );
    return result.map((json) => TranscriptionSegment.fromMap(json)).toList();
  }

  Future<void> deleteSegment(String id) async {
    final db = await database;
    await db.delete('segments', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<void> clearAllSegments() async {
    final db = await database;
    await db.delete('segments');
  }

  Future<void> deleteSegmentsByType(int typeIndex) async {
    // 0 = audio, 1 = aiResponse, 2 = notion, 3 = system
    final db = await database;
    await db.delete('segments', where: 'type = ?', whereArgs: [typeIndex]);
  }
  
  Future<void> close() async {
    final db = await database;
    db.close();
  }

  // Bubble Methods
  Future<void> insertBubble(Map<String, dynamic> bubbleMap) async {
    final db = await database;
    // Map camcelCase to snake_case for DB
    final dbMap = {
      'id': bubbleMap['id'],
      'name': bubbleMap['name'],
      'icon': bubbleMap['icon'],
      'color': bubbleMap['color'],
      'system_prompt': bubbleMap['systemPrompt'],
      'is_enabled': bubbleMap['isEnabled'],
      'use_notion_context': bubbleMap['useNotionContext'],
      'use_google_context': bubbleMap['useGoogleContext'],
      'use_web_search': bubbleMap['useWebSearch'],
      'linked_page_ids': bubbleMap['linkedPageIds'],
      'is_multi_output': bubbleMap['isMultiOutput'],
      'additional_prompts': bubbleMap['additionalPrompts'],
      'is_generated': bubbleMap['isGenerated'],
    };
    await db.insert(
      'bubbles', 
      dbMap, 
      conflictAlgorithm: ConflictAlgorithm.replace
    );
  }

  Future<List<Map<String, dynamic>>> getAllBubbles() async {
    final db = await database;
    final result = await db.query('bubbles');
    
    return result.map((row) {
      // Map snake_case back to camelCase for the app
      return {
        'id': row['id'],
        'name': row['name'],
        'icon': row['icon'],
        'color': row['color'],
        'systemPrompt': row['system_prompt'],
        'isEnabled': row['is_enabled'],
        'useNotionContext': row['use_notion_context'],
        'useGoogleContext': row['use_google_context'],
        'useWebSearch': row['use_web_search'],
        'linkedPageIds': row['linked_page_ids'],
        'isMultiOutput': row['is_multi_output'],
        'additionalPrompts': row['additional_prompts'],
        'isGenerated': row['is_generated'],
      };
    }).toList();
  }

  Future<void> deleteBubble(String id) async {
    final db = await database;
    await db.delete('bubbles', where: 'id = ?', whereArgs: [id]);
  }
}

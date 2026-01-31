import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import '../../../../core/errors/failures.dart';
import '../../recall/data/local_database.dart';
import '../../recall/domain/transcription_segment.dart';
// Removed bad import
import '../domain/notion_repository.dart';
import '../domain/notion_page.dart';
import '../../settings/domain/settings_repository.dart';
import '../../settings/data/native_settings_repository.dart';

class NativeNotionRepository implements NotionRepository {
  final LocalDatabase _db;
  final http.Client _client;
  final SettingsRepository _settingsRepository;

  NativeNotionRepository({LocalDatabase? db, http.Client? client, SettingsRepository? settingsRepository}) 
      : _db = db ?? LocalDatabase(),
        _client = client ?? http.Client(),
        _settingsRepository = settingsRepository ?? NativeSettingsRepository();

  @override
  Future<Either<Failure, List<NotionPage>>> searchPages(String query, {String? rootPageId}) async {
    try {
      final apiKeyResult = await _settingsRepository.getApiKey('notion');
      String apiKey = "";
      Failure? authFailure;
      
      apiKeyResult.fold(
        (f) => authFailure = f,
        (key) => apiKey = key,
      );

      if (authFailure != null) return Left(authFailure!);
      if (apiKey.isEmpty) return const Left(PermissionFailure("Notion API Key not found"));

      // V4: Root Page Scoping
      if (rootPageId != null && rootPageId.isNotEmpty) {
           // Extract ID from URL if needed (Simple regex or exact match)
           // Allow user to paste full link or ID.
           String cleanId = rootPageId;
           // If it's a URL, grab the last 32 chars roughly or use regex
           final uri = Uri.tryParse(rootPageId);
           if (uri != null && uri.pathSegments.isNotEmpty) {
               final lastSegment = uri.pathSegments.last;
               // Standard Notion ID is at end of dash often: name-ID
               final parts = lastSegment.split('-');
               if (parts.last.length == 32) {
                   cleanId = parts.last;
               } 
               // Or if just ID (32 hex)
           }
           // Use the regex for safety: [a-f0-9]{32}
           final match = RegExp(r'[a-f0-9]{32}').firstMatch(rootPageId);
           if (match != null) cleanId = match.group(0)!;
           
           print("DEBUG: Scoping Notion Search to Root: $cleanId");
           
           // Fetch Children instead of Search
           // reusing our recursive helper logic from importPages but we need to duplicate or expose it.
           // Since fetchChildDatabaseRows is inside importPages, we'll write a similar one here (or refactor).
           // Let's write inline for safety.
           
           final url = Uri.parse('https://api.notion.com/v1/blocks/$cleanId/children');
           final response = await _client.get(url, headers: {
              'Authorization': 'Bearer $apiKey',
              'Notion-Version': '2022-06-28',
           });

           if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final results = data['results'] as List;
              
              final pages = <NotionPage>[];
              for (var block in results) {
                 // We want CHILD PAGES or CHILD DATABASES
                 // (These are the "Folders" or "Tables" the user sees)
                 if (block['type'] == 'child_page') {
                    final title = block['child_page']['title'] ?? "Untitled Page";
                    pages.add(NotionPage(
                        id: block['id'], 
                        title: title, 
                        url: "https://notion.so/${block['id'].replaceAll('-', '')}", 
                        lastEdited: DateTime.now() // formatting limitation, children endpoint doesn't give edited time. Use Now or fetch?
                        // Actually, for "Select Pages" list, timestamp isn't critical, but might be nice.
                        // We can stick with Now() or leave null if nullable.
                    ));
                 } else if (block['type'] == 'child_database') {
                     final title = block['child_database']['title'] ?? "Untitled Database";
                     pages.add(NotionPage(
                        id: block['id'], 
                        title: title, 
                        url: "https://notion.so/${block['id'].replaceAll('-', '')}", 
                        lastEdited: DateTime.now()
                    ));
                 }
              }
              return Right(pages);
           }
           // If fail (e.g., 404), fall back to global? Or return error?
           // better to return error so user knows ID is wrong
           // However, for robustness, if empty, maybe fallback.
           // Let's stick to returning Scoped results.
      }

      // Default Global Search (V3 Filtered)
      final response = await _client.post(
        Uri.parse('https://api.notion.com/v1/search'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'filter': {
            'value': 'page',
            'property': 'object'
          },
          'sort': {
            'direction': 'descending',
            'timestamp': 'last_edited_time'
          },
          'page_size': 100 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        final pagesMap = <String, NotionPage>{}; // Use Map for deduplication

        for (var page in results) {
          // 1. Skip Archived (Trash) pages
          if (page['archived'] == true) continue;

          // Extract Title
          String title = "Untitled Page";
          try {
             final props = page['properties'];
             // Find 'title' type property
             for (var key in props.keys) {
               if (props[key]['type'] == 'title') {
                 final titleList = props[key]['title'] as List;
                 if (titleList.isNotEmpty) {
                   title = titleList[0]['plain_text'];
                 }
               }
             }
          } catch (e) {
            // Fallback for title
          }

          // 2. Add to Map (Last Edited Sort ensures we arguably get best version, 
          //    but duplicates usually have same ID). 
          //    We use putIfAbsent to keep the first one found (filtering logic could be customized)
          //    OR just overwrite. Since API sort is Descending Date, first one is latest.
          //    Actually, if ID is same, content is same.
          // 2. Add to Map (Deduplicate by TITLE to hide versions/duplicates with different IDs)
          //    We want the Latest timestamp for each unique Title.
          final pageId = page['id'];
          final lastEdited = DateTime.parse(page['last_edited_time']);
          
          if (!pagesMap.containsKey(title)) {
             pagesMap[title] = NotionPage(
              id: pageId,
              title: title,
              lastEdited: lastEdited,
              url: page['url'],
            );
          } else {
             // If we already have this title, check if this one is newer
             if (lastEdited.isAfter(pagesMap[title]!.lastEdited)) {
                pagesMap[title] = NotionPage(
                  id: pageId,
                  title: title,
                  lastEdited: lastEdited,
                  url: page['url'],
                );
             }
          }
        }
        
        // Sort final list by date descending (optional, but good for UI)
        final uniquePages = pagesMap.values.toList();
        uniquePages.sort((a, b) => b.lastEdited.compareTo(a.lastEdited));
        
        return Right(uniquePages);
      } else {
        return Left(ServerFailure("Notion API Error: ${response.statusCode}"));
      }
    } catch (e) {
      return Left(ServerFailure("Search Failed: ${e.toString()}"));
    }
  }

  @override
  Future<Either<Failure, NotionSyncStats>> importPages(List<NotionPage> pages, String apiKey) async {
    try {
      // 0. Update Known Roots (Persistence for UI Filtering)
      await _saveKnownRoots(pages);

      // 1. Get Current DB State
      final existingSegments = await _db.getAllSegments();
      final notionSegments = existingSegments.where((s) => s.type == SegmentType.notion).toList();
      final existingMap = {for (var s in notionSegments) s.id: s};

      // 2. Identify Deletions
      final inputIds = pages.map((p) => p.id).toSet();
      // Only delete if we are confidently syncing a scope? 
      // Current design: Input `pages` IS the sync scope (from checkboxes).
      // So anything in DB that is NOT in `pages` should be removed, IF we assume the user unchecked it.
      // But `pages` from `searchPages` includes ALL available pages (checked and unchecked) usually?
      // WAIT. `syncSelectedPages` passes ONLY `selectedPages`.
      // So if I have 10 synced pages, and I uncheck 1 and click Sync, `pages` has 9 items.
      // So `toDelete` will find that 1 item and delete it. CORRECT.
      
      final toDelete = notionSegments.where((s) => !inputIds.contains(s.id)).toList();
      int deletedCount = toDelete.length;
      for (var s in toDelete) {
        await _db.deleteSegment(s.id);
      }

      // 3. Identify Additions & Updates (Recursive Expansion)
      final pagesToProcess = <NotionPage>[];
      int addedCount = 0;
      int updatedCount = 0;
      
      // Helper to classify and add
      void classifyAndAdd(NotionPage p) {
         if (!existingMap.containsKey(p.id)) {
            pagesToProcess.add(p);
            addedCount++;
         } else if (p.lastEdited.isAfter(existingMap[p.id]!.timestamp)) {
            pagesToProcess.add(p);
            updatedCount++;
         }
      }

      // ... (Child DB Helper remains same, define it here or reuse) ...
      // Copying helper from previous version for context validity
       Future<List<NotionPage>> fetchChildDatabaseRows(String pageId) async {
          try {
            final url = Uri.parse('https://api.notion.com/v1/blocks/$pageId/children');
            final response = await _client.get(url, headers: {
               'Authorization': 'Bearer $apiKey', 'Notion-Version': '2022-06-28',
            });
            if (response.statusCode != 200) return [];
            final data = jsonDecode(response.body);
            final results = data['results'] as List;
            final childRows = <NotionPage>[];

            for (var block in results) {
               if (block['type'] == 'child_database') {
                  final dbId = block['id'];
                  final dbUrl = Uri.parse('https://api.notion.com/v1/databases/$dbId/query');
                  final dbRes = await _client.post(dbUrl, headers: {
                      'Authorization': 'Bearer $apiKey', 'Notion-Version': '2022-06-28', 'Content-Type': 'application/json',
                  });
                  if (dbRes.statusCode == 200) {
                     final dbData = jsonDecode(dbRes.body);
                     final rows = (dbData['results'] as List).map((json) {
                        final props = json['properties'];
                        String title = "Untitled Row";
                        // ... Title extraction reuse ...
                         if (props['Question'] != null && props['Question']['title'].isNotEmpty) {
                            title = props['Question']['title'][0]['text']['content'];
                         } else if (props['Name'] != null && props['Name']['title'].isNotEmpty) {
                            title = props['Name']['title'][0]['text']['content'];
                         } else if (props['title'] != null && props['title']['title'].isNotEmpty) {
                            title = props['title']['title'][0]['text']['content'];
                         }
                        return NotionPage(
                          id: json['id'], title: title, url: json['url'],
                          lastEdited: DateTime.parse(json['last_edited_time']),
                        );
                     }).toList();
                     childRows.addAll(rows);
                  }
               }
            }
            return childRows;
          } catch (e) { return []; }
      }

      // EXPANSION LOOP
      for (var page in pages) {
        classifyAndAdd(page);

        // Check children (expensive but needed for depth)
        // Only check children if Parent is new or valid? 
        // Actually, previous logic was: check children for all input pages.
        final children = await fetchChildDatabaseRows(page.id);
        for (var child in children) {
            classifyAndAdd(child);
        }
      }

      // 4. Process Batch
      final futures = pagesToProcess.map((page) async {
        try {
          final contentFuture = _fetchPageContent(page.id, apiKey);
          final propsFuture = _fetchPageProperties(page.id, apiKey);
          final results = await Future.wait([contentFuture, propsFuture]);
          final bodyContent = (results[0] as Either<Failure, String>).getOrElse(() => "");
          final propsContent = (results[1] as Either<Failure, String>).getOrElse(() => "");
          
          final combinedText = "Notion Page: ${page.title}\n----------------\n$propsContent\n\n$bodyContent";

          return TranscriptionSegment(
            id: page.id,
            text: combinedText, 
            timestamp: page.lastEdited,
            type: SegmentType.notion,
            sourceUrl: page.url,
            isSynced: true,
            isUser: false,
          );
        } catch (e) { return null; }
      });
      
      final newSegments = (await Future.wait(futures)).whereType<TranscriptionSegment>().toList();
      
      for (var s in newSegments) {
         await _db.insertSegment(s);
      }
      
      final total = existingMap.length - deletedCount + addedCount;
      
      return Right(NotionSyncStats(
        added: addedCount,
        updated: updatedCount,
        deleted: deletedCount,
        total: total
      ));
      
    } catch (e) {
      return Left(CacheFailure("Sync Failed: ${e.toString()}"));
    }
  }

  // Persist the ROOT page selection so UI can filter out rows
  // These 'pages' are the ones explicitly selected by the user.
  Future<void> _saveKnownRoots(List<NotionPage> roots) async {
      try {
         final rootIds = roots.map((p) => p.id).toList();
         final jsonStr = jsonEncode(rootIds);
         // We use the injected settings repo
         await _settingsRepository.setPreference('notion_known_roots', jsonStr);
      } catch (e) {
         print("Failed to save roots: $e");
      }
  }
  
  // Fetch specific columns: Question, Short Answer, Long Answer, Keywords, Alternative Questions
  Future<Either<Failure, String>> _fetchPageProperties(String pageId, String apiKey) async {
    try {
      final url = Uri.parse('https://api.notion.com/v1/pages/$pageId');
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Notion-Version': '2022-06-28',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final props = data['properties'] as Map<String, dynamic>;
        final buffer = StringBuffer();
        
        // Helper to extract plain text
        String extractText(Map<String, dynamic> prop) {
           final type = prop['type'];
           if (type == 'rich_text' || type == 'title') {
              final list = prop[type] as List;
              if (list.isEmpty) return "";
              return list.map((t) => t['plain_text']).join();
           } else if (type == 'multi_select') {
              final list = prop['multi_select'] as List;
              return list.map((Item) => Item['name']).join(', ');
           } else if (type == 'select') {
              return prop['select']?['name'] ?? "";
           }
           return "";
        }

        // Define Priority Keys (The exact column names the user requested)
        // We iterate specifically to maintain order in the Output Text
        final targetKeys = [
          'Question', 
          'Short Answer', 
          'Long Answer', 
          'Keywords', 
          'Alternative Question',
          'Alternative Questions'
        ];
        
        // Also keep legacy fallback if they haven't migrated
        final legacyKeys = ['Answer', 'Question', 'Keywords'];

        // 1. Try Strict Schema First
        bool foundSchema = false;
        
        for (var key in targetKeys) {
             // Case-insensitive match against Notion Props
             String? matchKey;
             for (var k in props.keys) {
               if (k.toLowerCase() == key.toLowerCase()) {
                 matchKey = k;
                 break;
               }
             }
             
             if (matchKey != null) {
               final text = extractText(props[matchKey]);
               if (text.isNotEmpty) {
                 buffer.writeln("$key: $text");
                 foundSchema = true;
               }
             }
        }
        
        // 2. Fallback to dump everything IF we didn't find our specific schema
        // (Prevents breaking non-conforming pages)
        if (!foundSchema) {
           for (var key in props.keys) {
               final lowerKey = key.toLowerCase();
               if (lowerKey == 'answer' || lowerKey == 'keywords' || lowerKey == 'alternative question' || lowerKey == 'question') {
                  final text = extractText(props[key]);
                  if (text.isNotEmpty) {
                     buffer.writeln("$key: $text");
                  }
               }
           }
        }
        
        return Right(buffer.toString());
      } else {
        return const Right(""); 
      }
    } catch (e) {
       return const Right(""); 
    }
  }

  Future<Either<Failure, String>> _fetchPageContent(String pageId, String apiKey) async {
    try {
      final url = Uri.parse('https://api.notion.com/v1/blocks/$pageId/children?page_size=100');
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Notion-Version': '2022-06-28',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        final buffer = StringBuffer();

        for (var block in results) {
          final type = block['type'];
          if (block[type] != null && block[type]['rich_text'] != null) {
            final textList = block[type]['rich_text'] as List;
            if (textList.isNotEmpty) {
              final text = textList.map((t) => t['plain_text']).join();
              if (type == 'heading_1') buffer.writeln("\n# $text");
              else if (type == 'heading_2') buffer.writeln("\n## $text");
              else if (type == 'bulleted_list_item') buffer.writeln("- $text");
              else buffer.writeln(text);
            }
          }
        }
        return Right(buffer.toString());
      } else {
        return Left(ServerFailure("Content Fetch Failed: ${response.statusCode}"));
      }
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

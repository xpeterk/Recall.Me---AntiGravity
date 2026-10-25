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
           String cleanId = rootPageId;
           final uri = Uri.tryParse(rootPageId);
           if (uri != null && uri.pathSegments.isNotEmpty) {
               final lastSegment = uri.pathSegments.last;
               final parts = lastSegment.split('-');
               if (parts.last.length == 32) {
                   cleanId = parts.last;
               } 
           }
           final match = RegExp(r'[a-f0-9]{32}').firstMatch(rootPageId);
           if (match != null) cleanId = match.group(0)!;
           
           print("DEBUG: Scoping Notion Search to Root: $cleanId");
           
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
                 if (block['type'] == 'child_page') {
                    final title = block['child_page']['title'] ?? "Untitled Page";
                    pages.add(NotionPage(
                        id: block['id'], 
                        title: title, 
                        url: "https://notion.so/${block['id'].replaceAll('-', '')}", 
                        lastEdited: DateTime.now(),
                        isDatabase: false,
                    ));
                 } else if (block['type'] == 'child_database') {
                      final title = block['child_database']['title'] ?? "Untitled Database";
                      pages.add(NotionPage(
                        id: block['id'], 
                        title: title, 
                        url: "https://notion.so/${block['id'].replaceAll('-', '')}", 
                        lastEdited: DateTime.now(),
                        isDatabase: true,
                    ));
                 }
              }
              return Right(pages);
           }
           return Left(ServerFailure("Notion block children API failed: ${response.statusCode}"));
      }

      // Default Global Search (V4: Fetch both pages and databases, filter out pages inside databases)
      final response = await _client.post(
        Uri.parse('https://api.notion.com/v1/search'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
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

        for (var item in results) {
          if (item['archived'] == true) continue;

          final isDb = item['object'] == 'database';
          
          // Skip pages inside databases (user request)
          if (!isDb) {
             if (item['parent'] != null && item['parent']['type'] == 'database_id') {
                continue;
             }
          }

          // Extract Title
          String title = isDb ? "Untitled Database" : "Untitled Page";
          try {
             if (isDb) {
                if (item['title'] != null && (item['title'] as List).isNotEmpty) {
                   title = item['title'][0]['plain_text'];
                }
             } else {
                final props = item['properties'];
                for (var key in props.keys) {
                  if (props[key]['type'] == 'title') {
                    final titleList = props[key]['title'] as List;
                    if (titleList.isNotEmpty) {
                      title = titleList[0]['plain_text'];
                    }
                  }
                }
             }
          } catch (e) {
             // Fallback
          }

          final pageId = item['id'];
          final lastEdited = DateTime.parse(item['last_edited_time']);
          
          if (!pagesMap.containsKey(title)) {
             pagesMap[title] = NotionPage(
              id: pageId,
              title: title,
              lastEdited: lastEdited,
              url: item['url'] ?? "",
              isDatabase: isDb,
            );
          } else {
             if (lastEdited.isAfter(pagesMap[title]!.lastEdited)) {
                pagesMap[title] = NotionPage(
                  id: pageId,
                  title: title,
                  lastEdited: lastEdited,
                  url: item['url'] ?? "",
                  isDatabase: isDb,
                );
             }
          }
        }
        
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
      await _saveKnownRoots(pages);

      final existingSegments = await _db.getAllSegments();
      final notionSegments = existingSegments.where((s) => s.type == SegmentType.notion).toList();
      final existingMap = {for (var s in notionSegments) s.id: s};

      // Deletion check
      final inputIds = pages.map((p) => p.id).toSet();
      final toDelete = notionSegments.where((s) => !inputIds.contains(s.id)).toList();
      int deletedCount = toDelete.length;
      for (var s in toDelete) {
        await _db.deleteSegment(s.id);
      }

      final pagesToProcess = <NotionPage>[];
      int addedCount = 0;
      int updatedCount = 0;
      
      void classifyAndAdd(NotionPage p) {
         if (!existingMap.containsKey(p.id)) {
            pagesToProcess.add(p);
            addedCount++;
         } else if (p.lastEdited.isAfter(existingMap[p.id]!.timestamp)) {
            pagesToProcess.add(p);
            updatedCount++;
         }
      }

      String getPropTitle(Map<String, dynamic> props) {
         try {
            for (var key in props.keys) {
               if (props[key]['type'] == 'title') {
                  final titleList = props[key]['title'] as List;
                  if (titleList.isNotEmpty) {
                     if (titleList[0]['plain_text'] != null) {
                        return titleList[0]['plain_text'];
                     }
                     if (titleList[0]['text'] != null && titleList[0]['text']['content'] != null) {
                        return titleList[0]['text']['content'];
                     }
                  }
               }
            }
         } catch (_) {}
         return "Untitled Row";
      }

      Future<List<NotionPage>> fetchDatabaseRows(String dbId) async {
          try {
             final dbUrl = Uri.parse('https://api.notion.com/v1/databases/$dbId/query');
             final dbRes = await _client.post(dbUrl, headers: {
                 'Authorization': 'Bearer $apiKey',
                 'Notion-Version': '2022-06-28',
                 'Content-Type': 'application/json',
             });
             if (dbRes.statusCode == 200) {
                final dbData = jsonDecode(dbRes.body);
                final rows = (dbData['results'] as List).map((json) {
                   final props = json['properties'];
                   final title = getPropTitle(props);
                   return NotionPage(
                     id: json['id'],
                     title: title,
                     url: json['url'] ?? "",
                     lastEdited: DateTime.parse(json['last_edited_time']),
                     isDatabase: false,
                   );
                }).toList();
                return rows;
             }
             return [];
          } catch (e) { return []; }
       }

       Future<List<NotionPage>> fetchChildDatabaseRows(String pageId) async {
          try {
            final url = Uri.parse('https://api.notion.com/v1/blocks/$pageId/children');
            final response = await _client.get(url, headers: {
               'Authorization': 'Bearer $apiKey',
               'Notion-Version': '2022-06-28',
            });
            if (response.statusCode != 200) return [];
            final data = jsonDecode(response.body);
            final results = data['results'] as List;
            final childRows = <NotionPage>[];

            for (var block in results) {
               if (block['type'] == 'child_database') {
                  final dbId = block['id'];
                  final rows = await fetchDatabaseRows(dbId);
                  childRows.addAll(rows);
               }
            }
            return childRows;
          } catch (e) { return []; }
      }

      // EXPANSION LOOP
      for (var page in pages) {
        if (page.isDatabase) {
           final rows = await fetchDatabaseRows(page.id);
           for (var row in rows) {
              classifyAndAdd(row);
           }
        } else {
           classifyAndAdd(page);
           final children = await fetchChildDatabaseRows(page.id);
           for (var child in children) {
               classifyAndAdd(child);
           }
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
            contextTopic: page.title,
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

        // Detect Convo Starter (column checkbox/select/status)
        // If the property has been removed from the database, all entries are used.
        bool hasConvoStarterProp = false;
        bool isConvoStarter = false;
        for (var k in props.keys) {
           final cleanKey = k.toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');
           if (cleanKey == 'convostarter') {
              hasConvoStarterProp = true;
              final prop = props[k];
              final type = prop['type'];
              if (type == 'checkbox') {
                 isConvoStarter = prop['checkbox'] == true;
              } else if (type == 'select') {
                 final name = prop['select']?['name']?.toLowerCase();
                 isConvoStarter = name == 'yes' || name == 'true' || name == 'active';
              } else if (type == 'status') {
                 final name = prop['status']?['name']?.toLowerCase();
                 isConvoStarter = name == 'yes' || name == 'true' || name == 'active';
              }
           }
        }
        if (!hasConvoStarterProp || isConvoStarter) {
           buffer.writeln("Convo Starter: true");
        }
        
        // Helper to extract plain text
        String extractText(Map<String, dynamic> prop) {
           final type = prop['type'];
           if (type == 'rich_text' || type == 'title') {
              final list = prop[type] as List;
              if (list.isEmpty) return "";
              return list.map((t) => t['plain_text']).join();
           } else if (type == 'multi_select') {
              final list = prop['multi_select'] as List;
              return list.map((item) => item['name']).join(', ');
           } else if (type == 'select') {
              return prop['select']?['name'] ?? "";
           }
           return "";
        }

        final processedKeys = <String>{};

        // 1. Primary Question
        for (var k in props.keys) {
           if (k.trim().toLowerCase() == 'question') {
              final text = extractText(props[k]);
              if (text.isNotEmpty) {
                 buffer.writeln("Question: $text");
                 processedKeys.add(k);
              }
           }
        }

        // 2. Alternative Questions (Alternative Question, Alternative Question 1, Alternative Question 2, etc.)
        final altKeys = props.keys.where((k) {
           final clean = k.trim().toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
           return clean.startsWith('alternative question');
        }).toList()..sort();

        for (var k in altKeys) {
           final text = extractText(props[k]);
           if (text.isNotEmpty) {
              buffer.writeln("$k: $text");
              processedKeys.add(k);
           }
        }

        // 3. Short Answer / Answer
        for (var k in props.keys) {
           final lower = k.trim().toLowerCase();
           if (lower == 'short answer' || lower == 'answer') {
              final text = extractText(props[k]);
              if (text.isNotEmpty) {
                 buffer.writeln("Short Answer: $text");
                 processedKeys.add(k);
              }
           }
        }

        // 4. Long Answer
        for (var k in props.keys) {
           if (k.trim().toLowerCase() == 'long answer') {
              final text = extractText(props[k]);
              if (text.isNotEmpty) {
                 buffer.writeln("Long Answer: $text");
                 processedKeys.add(k);
              }
           }
        }

        // 5. Keywords
        for (var k in props.keys) {
           if (k.trim().toLowerCase() == 'keywords') {
              final text = extractText(props[k]);
              if (text.isNotEmpty) {
                 buffer.writeln("Keywords: $text");
                 processedKeys.add(k);
              }
           }
        }

        // 6. Any other remaining properties (excluding title & convo starter)
        for (var k in props.keys) {
           if (!processedKeys.contains(k)) {
              final clean = k.toLowerCase().replaceAll(' ', '').replaceAll('_', '').replaceAll('-', '');
              if (clean != 'convostarter' && props[k]['type'] != 'title') {
                 final text = extractText(props[k]);
                 if (text.isNotEmpty) {
                    buffer.writeln("$k: $text");
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
          final hasChildren = block['has_children'] == true;
          if (block[type] != null && block[type]['rich_text'] != null) {
            final textList = block[type]['rich_text'] as List;
            if (textList.isNotEmpty) {
              final text = textList.map((t) => t['plain_text']).join();
              if (type == 'heading_1') buffer.writeln("\n# $text");
              else if (type == 'heading_2') buffer.writeln("\n## $text");
              else if (type == 'bulleted_list_item') {
                 buffer.writeln("- $text");
                 if (hasChildren) {
                    final childText = await _fetchBlockChildrenText(block['id'], apiKey, depth: 1);
                    buffer.write(childText);
                 }
              } else buffer.writeln(text);
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

  Future<String> _fetchBlockChildrenText(String blockId, String apiKey, {int depth = 1}) async {
    try {
      final url = Uri.parse('https://api.notion.com/v1/blocks/$blockId/children?page_size=100');
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
        final indent = "  " * depth;

        for (var block in results) {
          final type = block['type'];
          final hasChildren = block['has_children'] == true;
          if (block[type] != null && block[type]['rich_text'] != null) {
            final textList = block[type]['rich_text'] as List;
            if (textList.isNotEmpty) {
              final text = textList.map((t) => t['plain_text']).join();
              if (type == 'bulleted_list_item') {
                 buffer.writeln("$indent- $text");
                 if (hasChildren) {
                    final childText = await _fetchBlockChildrenText(block['id'], apiKey, depth: depth + 1);
                    buffer.write(childText);
                 }
              } else {
                 buffer.writeln("$indent$text");
              }
            }
          }
        }
        return buffer.toString();
      }
      return "";
    } catch (_) {
      return "";
    }
  }

  @override
  Future<Either<Failure, String>> getLatestPageFromDatabase(String databaseId) async {
    try {
      final apiKeyResult = await _settingsRepository.getApiKey('notion');
      String apiKey = "";
      apiKeyResult.fold((f) => null, (key) => apiKey = key);
      if (apiKey.isEmpty) return const Left(PermissionFailure("Notion API Key not found"));

      final extractId = RegExp(r'[a-f0-9]{32}').firstMatch(databaseId)?.group(0) ?? databaseId;

      final url = Uri.parse('https://api.notion.com/v1/databases/$extractId/query');
      final response = await _client.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sorts': [
            {
              'timestamp': 'created_time',
              'direction': 'descending'
            }
          ],
          'page_size': 1
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        if (results.isEmpty) {
           return const Left(ServerFailure("Database is empty or not found."));
        }
        
        final latestPageId = results.first['id'];
        
        // Fetch content from the blocks endpoint
        final contentResult = await _fetchPageContent(latestPageId, apiKey);
        return contentResult;

      } else {
        return Left(ServerFailure("Query Failed: ${response.statusCode}"));
      }
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

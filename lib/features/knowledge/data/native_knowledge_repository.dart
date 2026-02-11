import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../domain/knowledge_repository.dart';
import '../../recall/data/local_database.dart';
import '../../recall/domain/transcription_segment.dart';

class NativeKnowledgeRepository implements KnowledgeRepository {
  final LocalDatabase _db;

  NativeKnowledgeRepository({LocalDatabase? db}) : _db = db ?? LocalDatabase();

  @override
  Future<Either<Failure, List<String>>> retrieveContext(String query) async {
    try {
      // Simple Keyword Search (Full Text Search simulation)
      // 1. Split query into keywords (Relaxed filter: length > 2)
      final keywords = query.toLowerCase().split(' ').where((w) => w.length > 2).toList();
      print("DEBUG: RAG Keywords: $keywords");
      
      if (keywords.isEmpty) {
         print("DEBUG: RAG Query too short.");
         return const Right([]); 
      }

      // 2. Fetch all Notion segments
      final allSegments = await _db.getAllSegments();
      final candidates = allSegments.where((s) => s.type == SegmentType.notion).toList();
      print("DEBUG: RAG Candidates: ${candidates.length}");

      List<String> results = [];

      for (var segment in candidates) {
        int score = 0;
        final contentLower = segment.text.toLowerCase();
        
        for (var k in keywords) {
          if (contentLower.contains(k)) score++;
        }

        if (score > 0) {
           print("DEBUG: Match found (score $score): ${segment.text.substring(0, 20)}...");
           results.add(segment.text);
        }
      }

      // Limit to top 3
      if (results.length > 3) results = results.sublist(0, 3);
      
      print("DEBUG: RAG Returning ${results.length} results.");
      return Right(results);

    } catch (e) {
      return Left(CacheFailure("RAG Search Failed: $e"));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, String>>>> getNotionHeaders() async {
    try {
      final candidates = await _db.getSegmentMetadata(SegmentType.notion);
      
      final headers = candidates.map((s) {
          String title = "Untitled";
          final text = s['text'] as String? ?? "";
          final firstLine = text.split('\n').first;
          
          if (firstLine.startsWith("Notion Page: ")) {
             title = firstLine.replaceFirst("Notion Page: ", "");
          }
          return {
            'id': s['id'] as String,
            'text': title,
            'url': (s['source_url'] as String?) ?? ""
          };
      }).toList();
      
      return Right(headers);
    } catch (e) {
      return Left(CacheFailure("Failed to fetch headers: $e"));
    }
  }

  @override
  Future<Either<Failure, TranscriptionSegment>> getSegmentById(String id) async {
    try {
       // Ideally DB has getById. Using scan for now.
       final allSegments = await _db.getAllSegments();
       final match = allSegments.firstWhere((s) => s.id == id, orElse: () => TranscriptionSegment(id: "null", text: "", timestamp: DateTime.now(), type: SegmentType.audio));
       
       if (match.id == "null") {
          return Left(CacheFailure("Segment not found"));
       }
       return Right(match);
    } catch (e) {
       return Left(CacheFailure("Failed to fetch segment: $e"));
    }
  }
}

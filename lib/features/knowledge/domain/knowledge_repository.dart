import 'package:dartz/dartz.dart';
import 'package:recall_me_native/core/errors/failures.dart';
import 'package:recall_me_native/features/recall/domain/transcription_segment.dart';

abstract class KnowledgeRepository {
  /// Retrieves relevant context based on a query text.
  /// Returns a list of context strings (e.g. chunks from Notion pages).
  Future<Either<Failure, List<String>>> retrieveContext(String query);

  /// Retrieves a list of all Notion Page Headers (ID + Title) for AI Selection.
  Future<Either<Failure, List<Map<String, String>>>> getNotionHeaders();

  /// Retrieves the full text of a specific segment by ID.
  Future<Either<Failure, TranscriptionSegment>> getSegmentById(String id);
}

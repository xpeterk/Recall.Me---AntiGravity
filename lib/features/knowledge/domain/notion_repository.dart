import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import 'notion_page.dart';

class NotionSyncStats {
  final int added;
  final int updated;
  final int deleted;
  final int total;

  NotionSyncStats({
    required this.added,
    required this.updated,
    required this.deleted,
    required this.total,
  });
  
  @override
  String toString() => "Added: $added, Updated: $updated, Deleted: $deleted, Total: $total";
}

abstract class NotionRepository {
  /// Fetches a list of accessible pages from Notion.
  Future<Either<Failure, List<NotionPage>>> searchPages(String query, {String? rootPageId});

  /// Imports specific pages into the local database.
  Future<Either<Failure, NotionSyncStats>> importPages(List<NotionPage> pages, String apiKey);
}

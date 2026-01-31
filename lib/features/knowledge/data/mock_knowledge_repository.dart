import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../domain/knowledge_repository.dart';

class MockKnowledgeRepository implements KnowledgeRepository {
  @override
  Future<Either<Failure, List<String>>> retrieveContext(String query) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Simple mock: if query contains keywords, return fake knowledge.
    if (query.toLowerCase().contains("native") || query.toLowerCase().contains("flutter")) {
      return const Right([
        "Recall.Me Spec v2: The app should use Flutter for the UI framework.",
        "Recall.Me Audio: Primary engine is Google Gemini Live via native audio channels.",
      ]);
    }

    if (query.toLowerCase().contains("delay") || query.toLowerCase().contains("latency")) {
       return const Right([
         "Performance Optimization: We aim for <200ms latency for STT.",
         "Network: Use Supabase Edge Functions for handling RAG queries."
       ]);
    }

    // Default "General Knowledge" fallback
    return const Right([
      "General Context: This is a conversation happening in the Recall.Me application.",
      "User Context: The user is a developer testing the functionality."
    ]);
  }
}

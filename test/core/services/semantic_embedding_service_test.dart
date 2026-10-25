import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall_me_native/core/services/semantic_embedding_service.dart';
import 'package:recall_me_native/features/settings/domain/dynamic_starter.dart';

void main() {
  late SemanticEmbeddingService service;

  setUp(() {
    service = SemanticEmbeddingService();
  });

  group('SemanticEmbeddingService Tests', () {
    test('produces normalized 384-dimensional embeddings', () async {
      final embedding = await service.getEmbedding("Men's Bible Study and Scripture Discussion");
      expect(embedding.length, equals(384));

      // Check L2 normalization (sum of squares ~ 1.0)
      double sumSquares = 0.0;
      for (var val in embedding) {
        sumSquares += val * val;
      }
      expect(sumSquares, closeTo(1.0, 0.001));
    });

    test('semantically similar phrases yield higher cosine similarity than unrelated phrases', () async {
      final studyQuery = await service.getEmbedding("We are discussing Bible verses and Sunday fellowship");
      final studyStarter = await service.getEmbedding("Men's Bible Study and Scripture Discussion");
      final cryptoStarter = await service.getEmbedding("Bitcoin Mining and Ethereum Cryptocurrency Trading");

      final studySimilarity = SemanticEmbeddingService.cosineSimilarity(studyQuery, studyStarter);
      final cryptoSimilarity = SemanticEmbeddingService.cosineSimilarity(studyQuery, cryptoStarter);

      expect(studySimilarity, greaterThan(cryptoSimilarity));
      expect(studySimilarity, greaterThan(0.15));
    });

    test('serializes to bytes and deserializes from bytes accurately for SQLite BLOB storage', () async {
      final original = await service.getEmbedding("Meeting Notes and Action Items");
      final bytes = SemanticEmbeddingService.vectorToBytes(original);
      expect(bytes.length, equals(384 * 4)); // 384 32-bit floats = 1536 bytes

      final restored = SemanticEmbeddingService.bytesToVector(bytes);
      expect(restored.length, equals(original.length));
      for (int i = 0; i < original.length; i++) {
        expect(restored[i], closeTo(original[i], 0.0001));
      }
    });

    test('ranks candidate starters by relevance score', () async {
      final bibleStarterEmb = await service.getEmbedding("Men's Bible Study");
      final quarterlyPlanningEmb = await service.getEmbedding("Quarterly Engineering Roadmap Planning");
      final budgetEmb = await service.getEmbedding("Annual Corporate Budget Review");

      final starters = [
        DynamicStarter(id: '1', name: "Men's Bible Study", notionDatabaseId: 'db1', embedding: bibleStarterEmb),
        DynamicStarter(id: '2', name: "Engineering Roadmap", notionDatabaseId: 'db2', embedding: quarterlyPlanningEmb),
        DynamicStarter(id: '3', name: "Corporate Budget", notionDatabaseId: 'db3', embedding: budgetEmb),
      ];

      final queryEmb = await service.getEmbedding("Let's review the sprint tasks and technical roadmap architecture");
      final score1 = SemanticEmbeddingService.cosineSimilarity(queryEmb, bibleStarterEmb);
      final score2 = SemanticEmbeddingService.cosineSimilarity(queryEmb, quarterlyPlanningEmb);
      final score3 = SemanticEmbeddingService.cosineSimilarity(queryEmb, budgetEmb);
      print("Scores: bible=$score1, roadmap=$score2, budget=$score3");

      expect(score2, greaterThan(score1));
      expect(score2, greaterThan(score3));

      final ranked = service.rankCandidates<DynamicStarter>(
        queryVector: queryEmb,
        candidates: starters,
        embeddingExtractor: (s) => s.embedding ?? [],
        threshold: 0.10,
      );

      expect(ranked.isNotEmpty, isTrue);
      expect(ranked.first.item.id, equals('2'));
      expect(ranked.first.item.name, equals("Engineering Roadmap"));
    });
  });
}

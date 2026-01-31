import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

abstract class AiService {
  /// Generates a response from the AI based on the provided prompt.
  /// Returns a Stream of chunks for real-time display.
  Stream<Either<Failure, String>> generateStream(String prompt, {String? model, bool useSearch = false});
  
  /// non-streaming version
  Future<Either<Failure, String>> generate(String prompt, {String? model, bool useSearch = false});

  /// Lists available models from the provider
  Future<List<String>> listModels();
}

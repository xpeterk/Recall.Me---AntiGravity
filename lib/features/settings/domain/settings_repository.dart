import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

abstract class SettingsRepository {
  Future<Either<Failure, void>> setApiKey(String service, String key);
  Future<Either<Failure, String>> getApiKey(String service);
  
  Future<Either<Failure, void>> setPreference(String key, dynamic value);
  Future<Either<Failure, dynamic>> getPreference(String key);
  
  Future<Either<Failure, void>> saveBubbles(List<dynamic> bubblesData); // Pass Map List
  Future<Either<Failure, List<dynamic>>> getBubbles();

  Future<Either<Failure, void>> saveDynamicStarters(List<dynamic> startersData);
  Future<Either<Failure, List<dynamic>>> getDynamicStarters();
}

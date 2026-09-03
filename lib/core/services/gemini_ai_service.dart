import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../errors/failures.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ai_service.dart';

class GeminiAiService implements AiService {
  String _apiKey;

  GeminiAiService({String? apiKey}) : _apiKey = (apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '').trim();

  void setApiKey(String key) {
    _apiKey = key.trim();
  }

  String get apiKey => _apiKey;

  String _getModelName(String? modelAlias) {
    if (modelAlias == null || modelAlias.isEmpty) return 'gemini-3.5-flash';
    
    // Allow passing full model names directly if they contain 'gemini'
    if (modelAlias.toLowerCase().contains('gemini')) return modelAlias;

    switch (modelAlias) {
      case 'pro': return 'gemini-3.1-pro-preview';
      case 'flash': 
      default: return 'gemini-3.5-flash';
    }
  }

  @override
  Future<Either<Failure, String>> generate(String prompt, {String? model, bool useSearch = false}) async {
    if (_apiKey.isEmpty) {
      return const Left(ServerFailure("Gemini API Key is not set. Please add it in Settings > AI Services."));
    }

    try {
      final modelName = _getModelName(model);
      
      if (useSearch) {
         final result = await _generateRaw(prompt, modelName);
         return Right(result);
      }
      
      final genModel = GenerativeModel(
        model: modelName, 
        apiKey: _apiKey,
      );
      final content = [Content.text(prompt)];
      
      final response = await genModel.generateContent(content);
      
      if (response.text != null) {
        return Right(response.text!);
      } else {
        return const Right("No response generated.");
      }
    } catch (e) {
      if (e.toString().contains("404")) {
         return Left(ServerFailure("Model $model not found (404). Please check the model name in Settings."));
      }
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<Either<Failure, String>> generateStream(String prompt, {String? model, bool useSearch = false}) async* {
    if (_apiKey.isEmpty) {
      yield const Left(ServerFailure("Gemini API Key is not set. Please add it in Settings > AI Services."));
      return;
    }

    try {
      final modelName = _getModelName(model);
      
      if (useSearch) {
         final result = await _generateRaw(prompt, modelName);
         yield Right(result);
         return;
      }

      final genModel = GenerativeModel(
        model: modelName, 
        apiKey: _apiKey,
      );
      final content = [Content.text(prompt)];
      
      final stream = genModel.generateContentStream(content);
      
      await for (final response in stream) {
        if (response.text != null) {
          yield Right(response.text!);
        }
      }
    } catch (e) {
       yield Left(ServerFailure("Error: $e"));
    }
  }

  @override
  Future<List<String>> listModels() async {
    if (_apiKey.isEmpty) {
      return ["Error: API Key not set"];
    }
    
    try {
      final response = await http.get(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['models'] != null) {
          final List<dynamic> models = data['models'];
          return models
              .map<String>((m) => (m['name'] as String).replaceFirst('models/', ''))
              .where((id) => id.contains('gemini'))
              .toList();
        }
        return ["No models found in response"];
      } else {
        return ["Error: ${response.statusCode} - ${response.body}"];
      }
    } catch (e) {
      return ["Exception: $e"];
    }
  }

  Future<String> _generateRaw(String prompt, String modelName) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_apiKey');
    
    final body = jsonEncode({
      "contents": [{
        "parts": [{"text": prompt}]
      }],
      "tools": [{
        "google_search": {}
      }]
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['candidates'] != null && (data['candidates'] as List).isNotEmpty) {
        final candidate = data['candidates'][0];
        if (candidate['content'] != null && candidate['content']['parts'] != null) {
          final parts = candidate['content']['parts'] as List;
          if (parts.isNotEmpty) {
             return parts[0]['text'] ?? "No text returned.";
          }
        }
      }
      return "No content generated.";
    } else {
      throw Exception("API Error ${response.statusCode}: ${response.body}");
    }
  }
}

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
    if (modelAlias == null || modelAlias.isEmpty) return 'gemini-2.5-flash';
    
    final lower = modelAlias.toLowerCase();
    if (lower == 'gemini-1.5-flash' || lower == 'gemini-3.5-flash') {
      return 'gemini-2.5-flash';
    }
    if (lower == 'gemini-1.5-pro' || lower == 'gemini-3.1-pro-preview') {
      return 'gemini-2.5-pro';
    }

    // Allow passing full model names directly if they contain 'gemini'
    if (lower.contains('gemini')) return modelAlias;

    switch (modelAlias) {
      case 'pro': return 'gemini-2.5-pro';
      case 'flash': 
      default: return 'gemini-2.5-flash';
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
         final result = await _generateRaw(prompt, modelName, useSearch: true);
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
      if (e.toString().contains("Unhandled format for Content") ||
          e.toString().contains("GenerativeAISdkException")) {
        try {
          final fallbackResult = await _generateRaw(prompt, _getModelName(model), useSearch: useSearch);
          return Right(fallbackResult);
        } catch (rawErr) {
          return Left(ServerFailure("API Error: $rawErr"));
        }
      }
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

    final modelName = _getModelName(model);

    try {
      if (useSearch) {
         final result = await _generateRaw(prompt, modelName, useSearch: true);
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
        if (response.text != null && response.text!.isNotEmpty) {
          yield Right(response.text!);
        }
      }
    } catch (e) {
      if (e.toString().contains("Unhandled format for Content") ||
          e.toString().contains("GenerativeAISdkException")) {
        try {
          final fallbackResult = await _generateRaw(prompt, modelName, useSearch: useSearch);
          yield Right(fallbackResult);
          return;
        } catch (rawErr) {
          yield Left(ServerFailure("API Error: $rawErr"));
          return;
        }
      }
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

  Future<String> _generateRaw(String prompt, String modelName, {bool useSearch = false}) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_apiKey');
    
    final Map<String, dynamic> bodyMap = {
      "contents": [{
        "parts": [{"text": prompt}]
      }]
    };

    if (useSearch) {
      bodyMap["tools"] = [{
        "google_search": {}
      }];
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyMap),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['candidates'] != null && (data['candidates'] as List).isNotEmpty) {
        final candidate = data['candidates'][0];
        if (candidate['content'] != null && candidate['content']['parts'] != null) {
          final parts = candidate['content']['parts'] as List;
          final buffer = StringBuffer();
          for (final part in parts) {
            if (part is Map && part['text'] != null) {
              buffer.write(part['text']);
            }
          }
          if (buffer.isNotEmpty) {
             return buffer.toString();
          }
        }
      }
      return "No content generated.";
    } else {
      throw Exception("API Error ${response.statusCode}: ${response.body}");
    }
  }
}

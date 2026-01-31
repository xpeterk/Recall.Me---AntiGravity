import 'dart:async';
import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import '../errors/failures.dart';
import 'ai_service.dart';

class ClaudeAiService implements AiService {
  String _apiKey = '';
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _defaultModel = 'claude-3-5-sonnet-20240620';

  void setApiKey(String key) {
    _apiKey = key;
  }

  String _getModelName(String? modelAlias) {
    if (modelAlias == null || modelAlias.isEmpty) return _defaultModel;
    
    // Allow passing full model names
    if (modelAlias.startsWith('claude-')) return modelAlias;

    switch (modelAlias.toLowerCase()) {
      case 'opus': return 'claude-3-opus-20240229';
      case 'sonnet': return 'claude-3-5-sonnet-20240620';
      case 'haiku': return 'claude-3-haiku-20240307';
      default: return _defaultModel;
    }
  }

  @override
  Future<Either<Failure, String>> generate(String prompt, {String? model, bool useSearch = false}) async {
    if (_apiKey.isEmpty) return Left(ServerFailure("Claude API Key not set"));

    // TODO: Implement search for Claude if tool/MCP available
    
    try {
      final modelName = _getModelName(model);
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': modelName,
          'max_tokens': 1024,
          'messages': [
            {'role': 'user', 'content': prompt}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'] as List;
        if (content.isNotEmpty && content[0]['type'] == 'text') {
          return Right(content[0]['text']);
        }
        return const Right("No text content in response");
      } else {
        return Left(ServerFailure("Claude Error: ${response.statusCode} - ${response.body}"));
      }
    } catch (e) {
      return Left(ServerFailure("Exception: $e"));
    }
  }

  @override
  Stream<Either<Failure, String>> generateStream(String prompt, {String? model, bool useSearch = false}) async* {
    if (_apiKey.isEmpty) {
      yield Left(ServerFailure("Claude API Key not set"));
      return;
    }

    final modelName = _getModelName(model);
    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers.addAll({
      'x-api-key': _apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    });
    request.body = jsonEncode({
      'model': modelName,
      'max_tokens': 1024,
      'stream': true,
      'messages': [
        {'role': 'user', 'content': prompt}
      ]
    });

    try {
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        // Read full body for error
        final body = await response.stream.bytesToString();
        yield Left(ServerFailure("Claude Error: ${response.statusCode} - $body"));
        return;
      }

      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6);
          if (dataStr == '[DONE]') break;

          try {
            final data = jsonDecode(dataStr);
            final type = data['type'];

            if (type == 'content_block_delta') {
              final delta = data['delta'];
              if (delta['type'] == 'text_delta') {
                yield Right(delta['text']);
              }
            }
          } catch (e) {
            // Ignore parse errors for partial lines or keep-alives
          }
        }
      }
    } catch (e) {
      yield Left(ServerFailure("Stream Exception: $e"));
    }
  }


  @override
  Future<List<String>> listModels() async {
    if (_apiKey.isEmpty) {
      return ["Error: API Key not set"];
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.anthropic.com/v1/models'),
        headers: {
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> models = data['data'];
        
        // Filter for chat models and map to ID
        return models
            .where((m) => m['type'] == 'model')
            .map<String>((m) => m['id'] as String)
            .toList();
      } else {
        return ["Error: ${response.statusCode} - ${response.body}"];
      }
    } catch (e) {
      return ["Exception: $e"];
    }
  }
}

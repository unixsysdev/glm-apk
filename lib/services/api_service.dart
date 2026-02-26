import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import '../models/message_model.dart';

enum UserTier { free, byok, pro }

class ApiService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Send a chat message and stream the response tokens
  Stream<String> sendMessage({
    required List<MessageModel> messages,
    required UserTier tier,
    required String model,
    required String? cloudFunctionsUrl,
    required String? idToken,
    String? zaiEndpointUrl,
  }) async* {
    switch (tier) {
      case UserTier.free:
        yield* _sendViaCloudFunction(
          messages: messages,
          endpoint: '$cloudFunctionsUrl/freeTierProxy',
          idToken: idToken!,
          model: model,
        );
        break;
      case UserTier.byok:
        yield* _sendDirectToZai(
          messages: messages,
          model: model,
          endpointUrl: zaiEndpointUrl ?? ApiConstants.zaiEndpoints[ApiConstants.defaultZaiEndpoint]!,
        );
        break;
      case UserTier.pro:
        yield* _sendViaCloudFunction(
          messages: messages,
          endpoint: '$cloudFunctionsUrl/proTierProxy',
          idToken: idToken!,
          model: model,
        );
        break;
    }
  }

  /// BYOK: Direct call to Z.ai
  Stream<String> _sendDirectToZai({
    required List<MessageModel> messages,
    required String model,
    required String endpointUrl,
  }) async* {
    final apiKey = await _secureStorage.read(key: 'zai_api_key');
    if (apiKey == null) {
      throw Exception('No API key found. Please add your Z.ai API key.');
    }

    final request = http.Request('POST', Uri.parse(endpointUrl));
    request.headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => m.toApiFormat()).toList(),
      'stream': true,
      'temperature': 1.0,
    });

    yield* _handleStreamResponse(request);
  }

  /// Free/Pro: Via Cloud Function
  Stream<String> _sendViaCloudFunction({
    required List<MessageModel> messages,
    required String endpoint,
    required String idToken,
    String? model,
  }) async* {
    final request = http.Request('POST', Uri.parse(endpoint));
    request.headers.addAll({
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    });

    final body = <String, dynamic>{
      'messages': messages.map((m) => m.toApiFormat()).toList(),
    };
    if (model != null) {
      body['model'] = model;
    }
    request.body = jsonEncode(body);

    yield* _handleStreamResponse(request);
  }

  /// Handle SSE streaming response
  Stream<String> _handleStreamResponse(http.Request request) async* {
    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        debugPrint('API Error ${response.statusCode}: $body');
        String errorMessage;
        try {
          final errorJson = jsonDecode(body);
          errorMessage = errorJson['error']?['message'] ?? errorJson['message'] ?? body;
        } catch (_) {
          errorMessage = body;
        }
        throw ApiException(
          statusCode: response.statusCode,
          message: errorMessage,
        );
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta'];
            if (delta != null) {
              // Reasoning tokens (GLM-5 thinking)
              final reasoning = delta['reasoning_content'];
              if (reasoning != null && reasoning.isNotEmpty) {
                yield '<<REASONING>>$reasoning' as String;
              }
              // Regular content tokens
              final content = delta['content'];
              if (content != null && content.isNotEmpty) {
                yield content as String;
              }
            }
          } catch (_) {
            // Skip malformed JSON chunks
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// Validate a Z.ai API key by making a lightweight request
  Future<bool> validateZaiKey(String apiKey, {String? endpointUrl}) async {
    final url = endpointUrl ?? ApiConstants.zaiEndpoints[ApiConstants.defaultZaiEndpoint]!;
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'glm-4.7-flash',
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
          'max_tokens': 1,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Save API key securely
  Future<void> saveApiKey(String key) async {
    await _secureStorage.write(key: 'zai_api_key', value: key);
  }

  /// Read API key
  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: 'zai_api_key');
  }

  /// Delete API key
  Future<void> deleteApiKey() async {
    await _secureStorage.delete(key: 'zai_api_key');
  }

  /// Get masked API key for display
  Future<String?> getMaskedApiKey() async {
    final key = await getApiKey();
    if (key == null) return null;
    if (key.length <= 8) return '****';
    return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  bool get isQuotaExhausted => statusCode == 403;
  bool get isUnauthorized => statusCode == 401;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

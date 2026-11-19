import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/models/provider_models.dart';
import '../domain/provider_adapter.dart';

class GeminiAdapter implements ProviderAdapter {
  @override
  ProviderType get type => ProviderType.gemini;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  @override
  Future<ProviderTestResult> testConnection({
    required ProviderConfig config,
    required String? apiKey,
  }) async {
    try {
      final models = await listModels(config: config, apiKey: apiKey);
      return ProviderTestResult(
        ok: true,
        message: 'Conexão OK (${models.length} modelos)',
        models: models,
      );
    } catch (e) {
      return ProviderTestResult(ok: false, message: _friendlyError(e));
    }
  }

  @override
  Future<List<ModelInfo>> listModels({
    required ProviderConfig config,
    required String? apiKey,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key não configurada.');
    }
    final res = await _dio.get(
      '$_base/models',
      queryParameters: {'key': apiKey},
    );
    final list = (res.data is Map && res.data['models'] is List)
        ? res.data['models'] as List
        : const [];
    return [
      for (final m in list)
        if (m is Map && m['name'] is String)
          ModelInfo(
            id: (m['name'] as String).replaceFirst('models/', ''),
            displayName: m['displayName'] as String?,
            contextLimit: m['inputTokenLimit'] as int?,
          ),
    ];
  }

  @override
  Stream<ChatStreamEvent> streamChat({
    required ProviderConfig config,
    required String? apiKey,
    required String model,
    required List<ChatMessage> messages,
    Object? cancelToken,
  }) async* {
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key não configurada.');
    }
    final url =
        '$_base/models/$model:streamGenerateContent?alt=sse&key=$apiKey';
    final contents = [
      for (final m in messages.where((e) => e.role != MessageRole.system))
        {
          'role': m.role == MessageRole.user ? 'user' : 'model',
          'parts': [
            if (m.content.trim().isNotEmpty) {'text': m.content},
            for (final a in m.attachments.where(
              (a) =>
                  a.isImage &&
                  a.bytesBase64 != null &&
                  a.bytesBase64!.isNotEmpty,
            ))
              {
                'inline_data': {'mime_type': a.mimeType, 'data': a.bytesBase64},
              },
            if (m.content.trim().isEmpty &&
                m.attachments
                    .where((a) => a.isImage && a.bytesBase64 != null)
                    .isEmpty)
              {'text': ''},
          ],
        },
    ];
    final system = messages
        .where((e) => e.role == MessageRole.system)
        .map((e) => e.content)
        .join('\n');
    final body = {
      'contents': contents,
      if (system.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
    };
    final res = await _dio.post<ResponseBody>(
      url,
      data: jsonEncode(body),
      cancelToken: cancelToken is CancelToken ? cancelToken : null,
      options: Options(
        headers: const {'Content-Type': 'application/json'},
        responseType: ResponseType.stream,
      ),
    );
    final stream = res.data?.stream;
    if (stream == null) return;
    String buffer = '';
    await for (final chunk in stream.cast<List<int>>().transform(
      utf8.decoder,
    )) {
      buffer += chunk;
      while (true) {
        final idx = buffer.indexOf('\n');
        if (idx < 0) break;
        final line = buffer.substring(0, idx).trimRight();
        buffer = buffer.substring(idx + 1);
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;
        try {
          final j = jsonDecode(payload) as Map<String, dynamic>;
          ChatUsage? usage;
          if (j['usageMetadata'] is Map) {
            final u = j['usageMetadata'] as Map;
            usage = ChatUsage(
              promptTokens: u['promptTokenCount'] as int?,
              completionTokens: u['candidatesTokenCount'] as int?,
              totalTokens: u['totalTokenCount'] as int?,
            );
          }
          String? deltaText;
          final candidates = j['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts =
                ((candidates.first as Map)['content'] as Map?)?['parts']
                    as List?;
            if (parts != null) {
              final texts = <String>[];
              for (final p in parts) {
                final t = (p as Map)['text'];
                if (t is String && t.isNotEmpty) texts.add(t);
              }
              if (texts.isNotEmpty) deltaText = texts.join();
            }
          }
          if (deltaText != null || usage != null) {
            yield ChatStreamEvent(delta: deltaText, usage: usage);
          }
        } catch (_) {}
      }
    }
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) {
        return 'Geração cancelada.';
      }
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        return 'Falha de autenticação Gemini ($code).';
      }
      if (code == 429) {
        return 'Limite de requisições excedido (429).';
      }
      return 'Erro Gemini: ${e.message}';
    }
    return e.toString();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/models/provider_models.dart';
import '../domain/provider_adapter.dart';

class OpenAiCompatibleAdapter implements ProviderAdapter {
  OpenAiCompatibleAdapter(this.type);
  @override
  final ProviderType type;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  String _base(ProviderConfig config) {
    final e = (config.endpoint ?? type.defaultEndpoint ?? '').trim();
    return e.endsWith('/') ? e.substring(0, e.length - 1) : e;
  }

  Map<String, String> _headers(String? apiKey) => {
    'Content-Type': 'application/json',
    if (apiKey != null && apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    if (type == ProviderType.openrouter) ...{
      'HTTP-Referer': 'https://lotus-ai.local',
      'X-Title': 'Lotus AI',
    },
  };

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
    final base = _base(config);
    if (base.isEmpty) {
      throw Exception('Endpoint não configurado.');
    }
    final res = await _dio.get(
      '$base/models',
      options: Options(headers: _headers(apiKey)),
    );
    final data = res.data;
    final list = (data is Map && data['data'] is List)
        ? data['data'] as List
        : const [];
    return [
      for (final m in list)
        if (m is Map && m['id'] != null)
          ModelInfo(
            id: m['id'].toString(),
            displayName: m['id'].toString(),
            contextLimit: (m['context_length'] ?? m['context_window']) is int
                ? (m['context_length'] ?? m['context_window']) as int
                : null,
          ),
    ];
  }

  List<Map<String, dynamic>> _mapMessages(List<ChatMessage> messages) {
    return [
      for (final m in messages)
        {
          'role': m.role.name,
          'content': () {
            final imgs = m.attachments
                .where(
                  (a) =>
                      a.isImage &&
                      a.bytesBase64 != null &&
                      a.bytesBase64!.isNotEmpty,
                )
                .toList();
            if (imgs.isEmpty) return m.content;
            final parts = <Map<String, dynamic>>[];
            if (m.content.trim().isNotEmpty) {
              parts.add({'type': 'text', 'text': m.content});
            }
            for (final a in imgs) {
              parts.add({
                'type': 'image_url',
                'image_url': {
                  'url': 'data:${a.mimeType};base64,${a.bytesBase64}',
                },
              });
            }
            if (parts.isEmpty) return m.content;
            return parts;
          }(),
        },
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
    final base = _base(config);
    if (base.isEmpty) {
      throw Exception('Endpoint não configurado.');
    }
    final body = {
      'model': model,
      'stream': true,
      'stream_options': {'include_usage': true},
      'messages': _mapMessages(messages),
    };
    final res = await _dio.post<ResponseBody>(
      '$base/chat/completions',
      data: jsonEncode(body),
      cancelToken: cancelToken is CancelToken ? cancelToken : null,
      options: Options(
        headers: _headers(apiKey),
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
        if (payload.isEmpty || payload == '[DONE]') continue;
        try {
          final j = jsonDecode(payload) as Map<String, dynamic>;
          ChatUsage? usage;
          if (j['usage'] is Map) {
            final u = j['usage'] as Map;
            usage = ChatUsage(
              promptTokens: u['prompt_tokens'] as int?,
              completionTokens: u['completion_tokens'] as int?,
              totalTokens: u['total_tokens'] as int?,
            );
          }
          String? deltaText;
          final choices = j['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = (choices.first as Map)['delta'] as Map?;
            final content = delta?['content'];
            if (content is String && content.isNotEmpty) deltaText = content;
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
      final msg = e.response?.data;
      if (code == 401 || code == 403) {
        return 'Falha de autenticação ($code). Verifique a API key.';
      }
      if (code == 429) {
        return 'Limite de requisições excedido (429). Tente novamente mais tarde.';
      }
      if (code != null) {
        return 'Erro HTTP $code: ${_safeMsg(msg) ?? e.message}';
      }
      return 'Erro de rede: ${e.message}';
    }
    return e.toString();
  }

  String? _safeMsg(dynamic msg) {
    if (msg == null) return null;
    final s = msg.toString();
    return s.length > 300 ? '${s.substring(0, 300)}…' : s;
  }
}

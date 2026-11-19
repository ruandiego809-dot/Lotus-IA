import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/models/provider_models.dart';
import '../domain/provider_adapter.dart';

class CohereAdapter implements ProviderAdapter {
  @override
  ProviderType get type => ProviderType.cohere;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  String _base(ProviderConfig config) {
    final e =
        (config.endpoint ?? type.defaultEndpoint ?? 'https://api.cohere.com')
            .trim();
    return e.endsWith('/') ? e.substring(0, e.length - 1) : e;
  }

  Map<String, String> _headers(String? apiKey) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (apiKey != null && apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
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
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key não configurada.');
    }
    final base = _base(config);
    final res = await _dio.get(
      '$base/v1/models',
      options: Options(headers: _headers(apiKey)),
    );
    final data = res.data;
    final list = (data is Map && data['models'] is List)
        ? data['models'] as List
        : const [];
    return [
      for (final m in list)
        if (m is Map && m['name'] != null)
          ModelInfo(
            id: m['name'].toString(),
            displayName: m['name'].toString(),
            contextLimit: m['context_length'] is int
                ? m['context_length'] as int
                : null,
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
    final base = _base(config);
    final mapped = <Map<String, dynamic>>[];
    for (final m in messages) {
      final role = switch (m.role) {
        MessageRole.user => 'user',
        MessageRole.assistant => 'assistant',
        MessageRole.system => 'system',
      };
      mapped.add({'role': role, 'content': m.content});
    }
    final body = {'model': model, 'messages': mapped, 'stream': true};
    final res = await _dio.post<ResponseBody>(
      '$base/v2/chat',
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
        final line = buffer.substring(0, idx).trim();
        buffer = buffer.substring(idx + 1);
        if (line.isEmpty) continue;
        try {
          final j = jsonDecode(line) as Map<String, dynamic>;
          final type = j['type'] as String?;
          if (type == 'content-delta') {
            final text =
                (((j['delta'] as Map?)?['message'] as Map?)?['content']
                    as Map?)?['text'];
            if (text is String && text.isNotEmpty) {
              yield ChatStreamEvent(delta: text);
            }
          } else if (type == 'message-end') {
            final usage =
                (((j['delta'] as Map?)?['usage'] as Map?)?['tokens'] as Map?) ??
                (((j['delta'] as Map?)?['usage'] as Map?)?['billed_units']
                    as Map?);
            if (usage != null) {
              final input = usage['input_tokens'];
              final output = usage['output_tokens'];
              final inT = input is int
                  ? input
                  : (input is num ? input.toInt() : null);
              final outT = output is int
                  ? output
                  : (output is num ? output.toInt() : null);
              final total = (inT != null || outT != null)
                  ? ((inT ?? 0) + (outT ?? 0))
                  : null;
              if (inT != null || outT != null || total != null) {
                yield ChatStreamEvent(
                  usage: ChatUsage(
                    promptTokens: inT,
                    completionTokens: outT,
                    totalTokens: total,
                  ),
                );
              }
            }
          }
        } catch (_) {
          // ignore malformed lines
        }
      }
    }
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) return 'Geração cancelada.';
      final code = e.response?.statusCode;
      final msg = e.response?.data;
      if (code == 401 || code == 403) {
        return 'Falha de autenticação Cohere ($code). Verifique a API key.';
      }
      if (code == 429) return 'Limite de requisições excedido (429).';
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

// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/models/chat_models.dart';
import '../../../design/design.dart';

import '../data/chat_repository.dart';

/// Attach / conversation actions kept out of the widget tree so the chat page
/// stays readable and rebuilds stay cheap.
abstract final class ChatActions {
  static const _maxBytes = 200 * 1024;
  static const _maxChars = 12000;
  static const _extensions = [
    'txt',
    'md',
    'json',
    'dart',
    'yaml',
    'yml',
    'xml',
    'html',
    'css',
    'js',
    'ts',
    'py',
    'java',
    'kt',
    'gradle',
    'properties',
    'sh',
    'csv',
    'log',
  ];

  static Future<void> showAttachments(
    BuildContext context,
    TextEditingController input, {
    VoidCallback? onImagePicked,
  }) async {
    await showLotusSheet<void>(
      context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LotusSpace.xl,
                0,
                LotusSpace.xl,
                LotusSpace.md,
              ),
              child: Row(
                children: [
                  Text('Anexar', style: ctx.text.titleMedium),
                  const Spacer(),
                ],
              ),
            ),
            _SheetAction(
              icon: Icons.description_outlined,
              title: 'Arquivo de texto',
              subtitle: 'Inclui o conteúdo como texto na mensagem',
              onTap: () async {
                Navigator.pop(ctx);
                await attachTextFile(context, input);
              },
            ),
            _SheetAction(
              icon: Icons.image_outlined,
              title: 'Imagem',
              subtitle: 'Envia a imagem para modelos com visão',
              onTap: () async {
                Navigator.pop(ctx);
                if (onImagePicked != null) {
                  onImagePicked();
                }
              },
            ),
            const SizedBox(height: LotusSpace.md),
          ],
        ),
      ),
    );
  }

  static Future<void> attachTextFile(
    BuildContext context,
    TextEditingController input,
  ) async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _extensions,
      );
      if (picked == null || picked.path == null) return;
      final bytes = await File(picked.path!).length();
      if (bytes > _maxBytes) {
        if (context.mounted) {
          LotusFeedback.show(
            context,
            'Arquivo muito grande (limite de 200 KB).',
            tone: LotusSnackTone.warning,
          );
        }
        return;
      }
      final content = await File(picked.path!).readAsString();
      final snippet = content.length > _maxChars
          ? '${content.substring(0, _maxChars)}\n...[truncado]'
          : content;
      final block = '\n\n[Arquivo: ${picked.name}]\n```\n$snippet\n```\n';
      final current = input.text;
      input.text = current.isEmpty ? block.trimLeft() : '$current$block';
      input.selection = TextSelection.fromPosition(
        TextPosition(offset: input.text.length),
      );
      if (context.mounted) {
        LotusFeedback.show(
          context,
          content.length > _maxChars
              ? '${picked.name} incluído parcialmente.'
              : '${picked.name} incluído.',
          tone: LotusSnackTone.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        LotusFeedback.show(
          context,
          'Falha ao anexar: $error',
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  static const _maxImageBytes = 4 * 1024 * 1024; // 4 MB
  static const _imageExtensions = ['png', 'jpg', 'jpeg', 'webp', 'gif'];

  /// Escolhe uma imagem e retorna o [ChatAttachment] pronto para envio.
  static Future<ChatAttachment?> pickImage(BuildContext context) async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _imageExtensions,
      );
      if (picked == null || picked.path == null) return null;
      final file = File(picked.path!);
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        if (context.mounted) {
          LotusFeedback.show(
            context,
            'Imagem muito grande (limite de 4 MB).',
            tone: LotusSnackTone.warning,
          );
        }
        return null;
      }
      return ChatAttachment(
        name: picked.name,
        mimeType: 'image/${picked.extension ?? 'png'}',
        bytesBase64: base64Encode(bytes),
        isImage: true,
      );
    } catch (error) {
      if (context.mounted) {
        LotusFeedback.show(
          context,
          'Falha ao anexar imagem: $error',
          tone: LotusSnackTone.error,
        );
      }
      return null;
    }
  }

  static Future<void> run(
    BuildContext context,
    WidgetRef ref,
    String action,
    Conversation conversation,
  ) async {
    switch (action) {
      case 'rename':
        final title = await showLotusPrompt(
          context,
          title: 'Renomear conversa',
          hint: 'Título',
          initialValue: conversation.title,
          icon: Icons.edit_outlined,
          selectAll: true,
        );
        if (title == null) return;
        await ref
            .read(chatControllerProvider.notifier)
            .renameConversation(conversation.id, title);
      case 'system':
        final prompt = await showLotusPrompt(
          context,
          title: 'Prompt do sistema',
          message: 'Instruções aplicadas apenas a esta conversa. Deixe vazio para remover.',
          hint: 'Ex.: responda de forma curta e técnica.',
          initialValue: conversation.systemPrompt ?? '',
          maxLines: 6,
          icon: Icons.tune_rounded,
        );
        if (prompt == null) return;
        await ref
            .read(chatControllerProvider.notifier)
            .updateSystemPrompt(conversation.id, prompt);
      case 'export':
        await showLotusTextPreview(
          context,
          title: 'Exportar conversa',
          caption:
              '${conversation.messages.length} mensagens • ${conversation.modelId ?? 'modelo não definido'}',
          text: _formatConversation(conversation),
        );
      case 'clear':
        final confirmed = await showLotusConfirm(
          context,
          title: 'Limpar mensagens?',
          message: 'Todas as mensagens desta conversa serão removidas. A conversa e o prompt do sistema são mantidos.',
          confirmLabel: 'Limpar',
          destructive: true,
          icon: Icons.cleaning_services_outlined,
        );
        if (!confirmed) return;
        if (ref.read(chatControllerProvider).value?.generating == true) return;
        await ref
            .read(chatControllerProvider.notifier)
            .clearMessages(conversation.id);
      case 'archive':
        await ref
            .read(chatControllerProvider.notifier)
            .archive(conversation.id, !conversation.archived);
      case 'exportJson':
        await _exportConversationJson(context, conversation);
      case 'importJson':
        await _importConversationJson(context, ref);
    }
  }

  static Future<void> _exportConversationJson(
    BuildContext context,
    Conversation conversation,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${dir.path}/lotus_ai');
      await exportDir.create(recursive: true);
      final file = File(
        '${exportDir.path}/conversa_${conversation.id}.json',
      );
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(conversation.toJson()),
        flush: true,
      );
      if (!context.mounted) return;
      await showLotusTextPreview(
        context,
        title: 'Conversa exportada',
        caption:
            'Arquivo JSON com histórico completo e anexos. Salvo no armazenamento do app.',
        text: file.path,
      );
    } catch (error) {
      if (context.mounted) {
        LotusFeedback.show(
          context,
          'Falha ao exportar conversa: $error',
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  static Future<void> _importConversationJson(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (picked == null || picked.path == null) return;
      final raw = await File(picked.path!).readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final conversation = Conversation.fromJson(json);
      await ref
          .read(chatControllerProvider.notifier)
          .upsertConversation(conversation);
      if (!context.mounted) return;
      LotusFeedback.show(
        context,
        'Conversa “${conversation.title}” importada.',
        tone: LotusSnackTone.success,
      );
    } catch (error) {
      if (context.mounted) {
        LotusFeedback.show(
          context,
          'Falha ao importar conversa: $error',
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  static String _formatConversation(Conversation conversation) {
    final buffer = StringBuffer()
      ..writeln('# ${conversation.title}')
      ..writeln('Exportado em: ${DateTime.now().toIso8601String()}');
    if (conversation.providerId != null) {
      buffer.writeln('Provedor: ${conversation.providerId}');
    }
    if (conversation.modelId != null) {
      buffer.writeln('Modelo: ${conversation.modelId}');
    }
    if (conversation.systemPrompt != null) {
      buffer
        ..writeln('Prompt do sistema: ${conversation.systemPrompt}')
        ..writeln();
    }
    for (final message in conversation.messages) {
      final who = switch (message.role) {
        MessageRole.user => 'Usuário',
        MessageRole.assistant => 'Assistente',
        MessageRole.system => 'Sistema',
      };
      buffer
        ..writeln()
        ..writeln('## $who (${message.createdAt.toIso8601String()})')
        ..writeln(message.content);
      if (message.error != null) buffer.writeln('\n[Erro: ${message.error}]');
      if (message.usage?.totalTokens != null) {
        buffer.writeln('\n[Uso: ${message.usage!.totalTokens} tokens]');
      }
    }
    return buffer.toString();
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: LotusIconBadge(icon: icon, size: 40),
      title: Text(title, style: context.text.bodyMedium),
      subtitle: Text(subtitle, style: context.text.labelSmall),
      trailing: Icon(Icons.chevron_right_rounded, color: context.palette.muted),
    );
  }
}

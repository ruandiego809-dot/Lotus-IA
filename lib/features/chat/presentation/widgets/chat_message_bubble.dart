// ignore_for_file: deprecated_member_use
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/chat_models.dart';
import '../../../../design/design.dart';


class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.canEdit,
    required this.canRegenerate,
    required this.onEdit,
    required this.onRegenerate,
    this.onRetry,
    this.onReply,
  });

  final ChatMessage message;
  final bool canEdit;
  final bool canRegenerate;
  final VoidCallback onEdit;
  final VoidCallback onRegenerate;
  final VoidCallback? onRetry;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final palette = context.palette;
    final scheme = context.scheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.attachments.isNotEmpty) ...[
          _Attachments(attachments: message.attachments),
          const SizedBox(height: LotusSpace.sm),
        ],
        if (isUser)
          Text(
            message.content,
            style: context.text.bodyMedium?.copyWith(
              height: 1.5,
              color: palette.userBubbleText,
            ),
          )
        else
          _AssistantContent(message: message),
        if (message.error != null) ...[
          const SizedBox(height: LotusSpace.md),
          _ErrorBlock(error: message.error!, onRetry: onRetry),
        ],
        const SizedBox(height: LotusSpace.sm),
        Row(
          children: [
            Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: context.text.labelSmall?.copyWith(fontSize: 10.5),
            ),
            const Spacer(),
            if (message.usage?.totalTokens != null)
              Padding(
                padding: const EdgeInsets.only(right: LotusSpace.sm),
                child: LotusPill(
                  '${message.usage!.totalTokens} tok',
                  icon: Icons.bolt_rounded,
                  tone: LotusPillTone.primary,
                  dense: true,
                ),
              ),
            _BubbleAction(
              icon: Icons.copy_rounded,
              tooltip: 'Copiar',
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: message.content));
                if (context.mounted) {
                  LotusFeedback.show(
                    context,
                    'Mensagem copiada',
                    tone: LotusSnackTone.success,
                  );
                }
              },
            ),
            if (canEdit)
              _BubbleAction(
                icon: Icons.edit_outlined,
                tooltip: 'Editar e reenviar',
                onTap: onEdit,
              ),
            if (canRegenerate)
              _BubbleAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Regenerar resposta',
                onTap: onRegenerate,
              ),
            if (onReply != null)
              _BubbleAction(
                icon: Icons.reply_rounded,
                tooltip: 'Responder a esta mensagem',
                onTap: onReply!,
              ),
          ],
        ),
      ],
    );

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(left: 44, bottom: LotusSpace.xs),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                LotusSpace.lg,
                LotusSpace.md,
                LotusSpace.md,
                LotusSpace.xs,
              ),
              decoration: BoxDecoration(
                color: palette.userBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(LotusRadius.lg),
                  topRight: Radius.circular(LotusRadius.lg),
                  bottomLeft: Radius.circular(LotusRadius.lg),
                  bottomRight: Radius.circular(LotusRadius.xs),
                ),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: content,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 20, bottom: LotusSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: LotusBrandMark(size: 28, radius: 9),
          ),
          const SizedBox(width: LotusSpace.md),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                LotusSpace.lg,
                LotusSpace.md,
                LotusSpace.md,
                LotusSpace.xs,
              ),
              decoration: BoxDecoration(
                color: palette.assistantBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(LotusRadius.xs),
                  topRight: Radius.circular(LotusRadius.lg),
                  bottomLeft: Radius.circular(LotusRadius.lg),
                  bottomRight: Radius.circular(LotusRadius.lg),
                ),
                border: Border.all(color: palette.border),
              ),
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantContent extends StatelessWidget {
  const _AssistantContent({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final empty = message.content.isEmpty;
    if (message.isStreaming && empty) {
      return const _TypingDots();
    }
    if (empty) {
      return Text(
        '(sem conteúdo)',
        style: context.text.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      );
    }
    if (message.isStreaming) {
      // Rendering raw text while tokens arrive avoids re-parsing Markdown on
      // every frame. The formatted result appears once the answer completes.
      return Text(
        message.content,
        style: context.text.bodyMedium?.copyWith(height: 1.55, fontSize: 14.5),
      );
    }
    return MarkdownBody(
      data: message.content,
      selectable: false,
      styleSheet: _markdownStyleFor(Theme.of(context)),
    );
  }
}

ThemeData? _cachedTheme;
MarkdownStyleSheet? _cachedSheet;

MarkdownStyleSheet _markdownStyleFor(ThemeData theme) {
  if (identical(theme, _cachedTheme) && _cachedSheet != null) {
    return _cachedSheet!;
  }
  final palette = theme.extension<LotusPalette>() ?? LotusPalette.light;
  final scheme = theme.colorScheme;
  final body = theme.textTheme.bodyMedium?.copyWith(
    height: 1.55,
    fontSize: 14.5,
  );
  final sheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: body,
    a: TextStyle(color: scheme.primary, decoration: TextDecoration.underline),
    h1: theme.textTheme.headlineSmall?.copyWith(height: 1.25),
    h2: theme.textTheme.titleLarge?.copyWith(height: 1.25),
    h3: theme.textTheme.titleMedium?.copyWith(height: 1.3),
    em: body?.copyWith(fontStyle: FontStyle.italic),
    strong: body?.copyWith(fontWeight: FontWeight.w700),
    blockSpacing: LotusSpace.md,
    listIndent: LotusSpace.xxl,
    listBullet: body,
    code: TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.5,
      backgroundColor: Colors.transparent,
      color: scheme.onSurface,
    ),
    codeblockPadding: const EdgeInsets.all(LotusSpace.md),
    codeblockDecoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(LotusRadius.sm),
      border: Border.all(color: palette.border),
    ),
    blockquoteDecoration: BoxDecoration(
      color: scheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(LotusRadius.xs),
      border: Border(left: BorderSide(color: scheme.primary, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(
      LotusSpace.md,
      LotusSpace.sm,
      LotusSpace.md,
      LotusSpace.sm,
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: palette.border)),
    ),
  );
  _cachedTheme = theme;
  _cachedSheet = sheet;
  return sheet;
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.scheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Opacity(
                  opacity:
                      0.25 +
                      0.75 *
                          (0.5 +
                                  0.5 *
                                      (1 -
                                              ((_controller.value - i * 0.18) %
                                                      1.0) *
                                                  2)
                                          .abs())
                              .clamp(0.0, 1.0),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Text(
              'pensando…',
              style: context.text.labelSmall?.copyWith(color: color),
            ),
          ],
        );
      },
    );
  }
}

class _Attachments extends StatelessWidget {
  const _Attachments({required this.attachments});

  final List<ChatAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: LotusSpace.sm,
      runSpacing: LotusSpace.sm,
      children: [
        for (final a in attachments)
          if (a.isImage && a.bytesBase64 != null && a.bytesBase64!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(LotusRadius.xs),
              child: Image.memory(
                base64Decode(a.bytesBase64!),
                width: 140,
                height: 140,
                cacheWidth: 280,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            )
          else
            LotusPill(a.name, icon: Icons.attach_file_rounded, dense: true),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error, this.onRetry});

  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LotusSpace.md),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LotusRadius.xs),
        border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 16, color: scheme.error),
              const SizedBox(width: LotusSpace.sm),
              Expanded(
                child: Text(
                  error,
                  style: context.text.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: LotusSpace.sm),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tentar novamente'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BubbleAction extends StatelessWidget {
  const _BubbleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      color: context.palette.muted,
    );
  }
}

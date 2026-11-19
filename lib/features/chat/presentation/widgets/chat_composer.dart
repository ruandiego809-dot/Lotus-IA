// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/chat_models.dart';
import '../../../../core/utils/token_estimator.dart';
import '../../../../design/design.dart';
import '../../../providers/data/provider_repository.dart';
import '../../data/chat_repository.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.generating,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
    this.focusNode,
    this.replyTo,
    this.pendingAttachments = const [],
    this.onClearReply,
    this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final bool generating;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;
  final ChatMessage? replyTo;
  final List<ChatAttachment> pendingAttachments;
  final VoidCallback? onClearReply;
  final ValueChanged<int>? onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        LotusSpace.md,
        0,
        LotusSpace.md,
        LotusSpace.sm,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: LotusBreakpoints.chatMaxWidth,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              LotusSpace.md,
              LotusSpace.md,
              LotusSpace.sm,
              LotusSpace.sm,
            ),
            decoration: BoxDecoration(
              color: palette.elevated,
              borderRadius: BorderRadius.circular(LotusRadius.lg),
              border: Border.all(
                color: generating
                    ? context.scheme.primary.withValues(alpha: 0.45)
                    : palette.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDark ? 0.32 : 0.05,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  enabled: !generating,
                  style: context.text.bodyMedium?.copyWith(
                    fontSize: 15,
                    height: 1.45,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: LotusSpace.xs,
                      vertical: LotusSpace.xs,
                    ),
                    hintText: generating
                        ? 'Gerando resposta…'
                        : 'Escreva para o Lótus…',
                  ),
                ),
                if (replyTo != null) ...[
                  const SizedBox(height: LotusSpace.xs),
                  Container(
                    padding: const EdgeInsets.all(LotusSpace.sm),
                    decoration: BoxDecoration(
                      color: context.scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(LotusRadius.sm),
                      border: Border.all(
                        color: context.scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.reply_rounded,
                          size: 16,
                        ),
                        const SizedBox(width: LotusSpace.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Respondendo a',
                                style: context.text.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: context.scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                replyTo!.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall?.copyWith(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onClearReply,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                ],
              ),
            ),
            ],
            if (pendingAttachments.isNotEmpty) ...[
              const SizedBox(height: LotusSpace.xs),
              Wrap(
                spacing: LotusSpace.xs,
                runSpacing: LotusSpace.xs,
                children: [
                  for (var i = 0; i < pendingAttachments.length; i++)
                    _PendingAttachmentChip(
                      attachment: pendingAttachments[i],
                      onRemove: () => onRemoveAttachment?.call(i),
                    ),
                ],
              ),
            ],
            const SizedBox(height: LotusSpace.sm),
                Row(
                  children: [
                    _AttachButton(enabled: !generating, onTap: onAttach),
                    const SizedBox(width: LotusSpace.xs),
                    Flexible(child: ChatTokenMeter(draft: controller)),
                    const SizedBox(width: LotusSpace.sm),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final hasText = value.text.trim().isNotEmpty;
                        return _SendButton(
                          generating: generating,
                          enabled: hasText || generating,
                          onSend: onSend,
                          onStop: onStop,
                        );
                      },
                    ),
                  ],
                ),
                ],
                ),
              ),
            ),
          ),
        );
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: 'Anexar',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(LotusRadius.pill),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.scheme.surfaceContainerHighest.withValues(
              alpha: 0.6,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.attach_file_rounded,
            size: 19,
            color: enabled
                ? palette.muted
                : palette.muted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.generating,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  final bool generating;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final palette = context.palette;
    final foreground = enabled ? Colors.white : palette.muted;
    return Semantics(
      button: true,
      label: generating ? 'Parar geração' : 'Enviar mensagem',
      child: GestureDetector(
        onTap: !enabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                generating ? onStop() : onSend();
              },
        child: AnimatedContainer(
          duration: LotusMotion.fast,
          curve: LotusMotion.curve,
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: generating || !enabled ? null : palette.brandGradient,
            color: generating
                ? scheme.errorContainer
                : (enabled ? null : scheme.surfaceContainerHighest),
            borderRadius: BorderRadius.circular(LotusRadius.sm),
          ),
          child: AnimatedSwitcher(
            duration: LotusMotion.fast,
            child: Icon(
              generating ? Icons.stop_rounded : Icons.arrow_upward_rounded,
              key: ValueKey(generating),
              size: 22,
              color: generating ? scheme.onErrorContainer : foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact context usage indicator. Keeps the previous "token monitor" feature
/// but computes the conversation estimate only when the conversation changes,
/// never on every keystroke.
class ChatTokenMeter extends ConsumerStatefulWidget {
  const ChatTokenMeter({super.key, required this.draft});

  final TextEditingController draft;

  @override
  ConsumerState<ChatTokenMeter> createState() => _ChatTokenMeterState();
}

class _ChatTokenMeterState extends ConsumerState<ChatTokenMeter> {
  Conversation? get conversation =>
      ref.watch(chatControllerProvider.select((state) => state.value?.active));

  Conversation? _cachedConversation;
  ChatUsage? _cachedUsage;
  int _cachedTokens = 0;

  int _messageTokens(Conversation? conversation) {
    if (conversation == null) return 0;
    if (identical(conversation, _cachedConversation)) return _cachedTokens;
    var length = 0;
    final prompt = conversation.systemPrompt;
    if (prompt != null && prompt.isNotEmpty) length += prompt.length + 1;
    for (final message in conversation.messages) {
      if (message.error != null) continue;
      length += message.content.length + 1;
    }
    ChatUsage? usage;
    for (final message in conversation.messages.reversed) {
      if (message.usage != null) {
        usage = message.usage;
        break;
      }
    }
    _cachedConversation = conversation;
    _cachedUsage = usage;
    _cachedTokens = TokenEstimator.estimateLength(length);
    return _cachedTokens;
  }

  int? _contextLimit() {
    final configs = ref.watch(
      providerControllerProvider.select((state) => state.value?.configs),
    );
    final providerId = conversation?.providerId;
    if (configs == null || providerId == null) return null;
    for (final config in configs) {
      if (config.id == providerId) {
        return config.contextLimitFor(conversation?.modelId);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final base = _messageTokens(conversation);
    final limit = _contextLimit();
    return AnimatedBuilder(
      animation: widget.draft,
      builder: (context, _) {
        final estimated =
            base + TokenEstimator.estimateLength(widget.draft.text.length);
        final percent = (limit != null && limit > 0) ? estimated / limit : null;
        final tone = percent == null
            ? LotusPillTone.neutral
            : percent >= 0.9
            ? LotusPillTone.danger
            : percent >= 0.75
            ? LotusPillTone.warning
            : LotusPillTone.neutral;
        final label = limit == null || limit <= 0
            ? '~${_short(estimated)} tok'
            : '~${_short(estimated)} / ${_short(limit)}';
        return InkWell(
          borderRadius: BorderRadius.circular(LotusRadius.pill),
          onTap: () => _showMonitor(
            context,
            estimated: estimated,
            limit: limit,
            percent: percent,
          ),
          child: LotusPill(
            label,
            icon: Icons.pie_chart_outline_rounded,
            tone: tone,
            dense: true,
          ),
        );
      },
    );
  }

  String _short(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }

  Future<void> _showMonitor(
    BuildContext context, {
    required int estimated,
    required int? limit,
    required double? percent,
  }) async {
    final palette = context.palette;
    final scheme = context.scheme;
    final usage = _cachedUsage;
    final hasReal =
        usage != null &&
        (usage.promptTokens != null ||
            usage.completionTokens != null ||
            usage.totalTokens != null);
    final menu = NumberFormat.decimalPattern('pt_BR');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monitor de tokens'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasReal) ...[
                  const LotusSectionHeader(
                    title: 'Uso real reportado pela API',
                    padding: EdgeInsets.zero,
                  ),
                  if (usage.promptTokens != null)
                    _Row(
                      label: 'Prompt',
                      value: menu.format(usage.promptTokens),
                    ),
                  if (usage.completionTokens != null)
                    _Row(
                      label: 'Resposta',
                      value: menu.format(usage.completionTokens),
                    ),
                  if (usage.totalTokens != null)
                    _Row(label: 'Total', value: menu.format(usage.totalTokens)),
                  const SizedBox(height: LotusSpace.md),
                ],
                const LotusSectionHeader(
                  title: 'Estimativa local',
                  subtitle: 'Heurística de ~4 caracteres por token, incluindo texto da conversa e rascunho. Imagens e formatação não entram.',
                  padding: EdgeInsets.zero,
                ),
                _Row(label: 'Estimado', value: '~${menu.format(estimated)}'),
                if (limit != null && limit > 0) ...[
                  _Row(label: 'Limite do modelo', value: menu.format(limit)),
                  _Row(
                    label: 'Uso estimado',
                    value: '${(percent! * 100).toStringAsFixed(1)}%',
                  ),
                  _Row(
                    label: 'Restante',
                    value: menu.format((limit - estimated).clamp(0, limit)),
                  ),
                  if (percent >= 0.75) ...[
                    const SizedBox(height: LotusSpace.sm),
                    Container(
                      padding: const EdgeInsets.all(LotusSpace.md),
                      decoration: BoxDecoration(
                        color: (percent >= 0.9 ? scheme.error : palette.warning)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(LotusRadius.xs),
                      ),
                      child: Text(
                        percent >= 0.9
                            ? 'Atenção: próximo do limite de contexto.'
                            : 'Aviso: uso de contexto elevado.',
                        style: ctx.text.bodySmall?.copyWith(
                          color: percent >= 0.9
                              ? scheme.error
                              : palette.warning,
                        ),
                      ),
                    ),
                  ],
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: LotusSpace.sm),
                    child: Text(
                      'O limite de contexto não foi informado por este provedor/modelo. Defina-o em Ajustes.',
                      style: ctx.text.bodySmall,
                    ),
                  ),
                const SizedBox(height: LotusSpace.lg),
                Text(
                  'Créditos e limites de uso da API são diferentes de contexto. Valores não disponibilizados pela API não são inventados.',
                  style: ctx.text.labelSmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.text.bodySmall)),
          Text(value, style: context.text.labelLarge),
        ],
      ),
    );
  }
}

class _PendingAttachmentChip extends StatelessWidget {
  const _PendingAttachmentChip({
    required this.attachment,
    required this.onRemove,
  });

  final ChatAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return LotusCard(
      radius: LotusRadius.sm,
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LotusSpace.sm,
          vertical: LotusSpace.xs,
        ),
        leading: Icon(
          attachment.isImage ? Icons.image_rounded : Icons.attach_file_rounded,
          size: 20,
          color: context.palette.muted,
        ),
        title: Text(
          attachment.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded, size: 18),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
        ),
      ),
    );
  }
}

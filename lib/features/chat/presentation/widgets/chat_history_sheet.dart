// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/chat_models.dart';
import '../../../../core/utils/date_labels.dart';
import '../../../../design/design.dart';
import '../../data/chat_repository.dart';

Future<void> showChatHistory(BuildContext context) {
  return showLotusSheet<void>(
    context,
    builder: (_) => const ChatHistorySheet(),
  );
}

class ChatHistorySheet extends ConsumerStatefulWidget {
  const ChatHistorySheet({super.key});

  @override
  ConsumerState<ChatHistorySheet> createState() => _ChatHistorySheetState();
}

class _ChatHistorySheetState extends ConsumerState<ChatHistorySheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }

  List<Conversation> _filter(List<Conversation> conversations) {
    if (_query.isEmpty) return conversations;
    return [
      for (final conversation in conversations)
        if (conversation.title.toLowerCase().contains(_query) ||
            conversation.messages.any(
              (m) => m.content.toLowerCase().contains(_query),
            ))
          conversation,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider).value;
    if (state == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final items = _filter(state.conversations);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LotusSpace.xl,
              LotusSpace.xs,
              LotusSpace.xl,
              LotusSpace.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Histórico', style: context.text.titleMedium),
                      Text(
                        '${state.conversations.length} conversas salvas',
                        style: context.text.labelSmall,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LotusSpace.lg),
            child: TextField(
              controller: _search,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por título ou mensagem',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          _onQueryChanged('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: LotusSpace.md),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(LotusSpace.xxl),
                      child: Text(
                        _query.isEmpty
                            ? 'Nenhuma conversa ainda.'
                            : 'Nenhum resultado para “$_query”.',
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      LotusSpace.md,
                      0,
                      LotusSpace.md,
                      LotusSpace.xl,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final conversation = items[index];
                      final previous = index == 0 ? null : items[index - 1];
                      final day = formatDayLabel(conversation.updatedAt);
                      final newGroup =
                          previous == null ||
                          formatDayLabel(previous.updatedAt) != day;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (newGroup)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                LotusSpace.md,
                                LotusSpace.md,
                                LotusSpace.md,
                                LotusSpace.xs,
                              ),
                              child: Text(
                                day,
                                style: context.text.labelSmall?.copyWith(
                                  letterSpacing: 0.4,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          _HistoryRow(
                            conversation: conversation,
                            selected: conversation.id == state.activeId,
                            generating: state.generating,
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.conversation,
    required this.selected,
    required this.generating,
  });

  final Conversation conversation;
  final bool selected;
  final bool generating;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (generating) return;
    final confirmed = await showLotusConfirm(
      context,
      title: 'Excluir conversa?',
      message:
          '“${conversation.title}” e todas as suas ${conversation.messages.length} mensagens serão removidas.',
      confirmLabel: 'Excluir',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    if (ref.read(chatControllerProvider).value?.generating == true) return;
    await ref.read(chatControllerProvider.notifier).delete(conversation.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.scheme;
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: LotusSpace.xs),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.1)
            : palette.elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LotusRadius.sm),
          side: BorderSide(
            color: selected
                ? scheme.primary.withValues(alpha: 0.35)
                : palette.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            ref.read(chatControllerProvider.notifier).select(conversation.id);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              LotusSpace.md,
              LotusSpace.md,
              LotusSpace.xs,
              LotusSpace.md,
            ),
            child: Row(
              children: [
                LotusIconBadge(
                  icon: selected
                      ? Icons.chat_bubble_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 38,
                ),
                const SizedBox(width: LotusSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatRelative(conversation.updatedAt)} • ${conversation.messages.length} mensagens',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opções',
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                  onSelected: (value) {
                    if (value == 'delete') _delete(context, ref);
                    if (value == 'archive') {
                      ref
                          .read(chatControllerProvider.notifier)
                          .archive(conversation.id, !conversation.archived);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'archive',
                      enabled: !generating,
                      child: Row(
                        children: [
                          Icon(
                            conversation.archived
                                ? Icons.unarchive_rounded
                                : Icons.archive_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: LotusSpace.sm),
                          Text(
                            conversation.archived
                                ? 'Desarquivar'
                                : 'Arquivar',
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: !generating,
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18),
                          SizedBox(width: LotusSpace.sm),
                          Text('Excluir'),
                        ],
                      ),
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

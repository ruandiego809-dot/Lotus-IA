// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/design.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.title,
    required this.messageCount,
    required this.hasConversation,
    required this.generating,
    required this.onNew,
    required this.onHistory,
    required this.onAction,
  });

  final String? title;
  final int messageCount;
  final bool hasConversation;
  final bool generating;
  final VoidCallback onNew;
  final VoidCallback onHistory;
  final ValueChanged<String> onAction;

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    return LotusAppBar(
      showBrand: true,
      title: title ?? 'Lótus AI',
      subtitle: hasConversation
          ? '$messageCount ${messageCount == 1 ? 'mensagem' : 'mensagens'}'
          : 'Central de inteligência',
      actions: [
        IconButton.filledTonal(
          tooltip: 'Nova conversa',
          onPressed: generating ? null : onNew,
          icon: const Icon(Icons.add_rounded, size: 20),
        ),
        IconButton(
          tooltip: 'Histórico',
          onPressed: onHistory,
          icon: const Icon(Icons.history_rounded, size: 21),
        ),
        IconButton(
          tooltip: 'Chat em grupo',
          onPressed: generating ? null : () => context.go('/group-chat'),
          icon: const Icon(Icons.group_rounded, size: 21),
        ),
        if (hasConversation)
          PopupMenuButton<String>(
            tooltip: 'Opções da conversa',
            icon: const Icon(Icons.more_horiz_rounded, size: 21),
            onSelected: onAction,
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'rename',
                child: _MenuRow(icon: Icons.edit_outlined, label: 'Renomear'),
              ),
              const PopupMenuItem(
                value: 'system',
                child: _MenuRow(
                  icon: Icons.tune_rounded,
                  label: 'Prompt do sistema',
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: _MenuRow(
                  icon: Icons.ios_share_outlined,
                  label: 'Exportar',
                ),
              ),
              PopupMenuItem(
                value: 'exportJson',
                child: _MenuRow(
                  icon: Icons.description_outlined,
                  label: context.l10n.exportConversation,
                ),
              ),
              PopupMenuItem(
                value: 'importJson',
                child: _MenuRow(
                  icon: Icons.cloud_download,
                  label: context.l10n.importConversation,
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                enabled: !generating,
                child: _MenuRow(
                  icon: Icons.archive_rounded,
                  label: context.l10n.archive,
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                enabled: !generating && messageCount > 0,
                child: const _MenuRow(
                  icon: Icons.cleaning_services_outlined,
                  label: 'Limpar mensagens',
                ),
              ),
            ],
          )
        else
          const SizedBox(width: LotusSpace.sm),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.palette.muted),
        const SizedBox(width: LotusSpace.md),
        Text(label),
      ],
    );
  }
}

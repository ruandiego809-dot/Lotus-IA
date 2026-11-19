// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/provider_models.dart';
import '../../../../design/design.dart';
import '../../../providers/data/provider_repository.dart';
import '../../data/chat_repository.dart';

/// Compact provider/model selector. Replaces the previous pair of dropdowns
/// with large, touch-friendly pills and searchable pickers.
class ChatModelBar extends ConsumerWidget {
  const ChatModelBar({
    super.key,
    required this.providerId,
    required this.modelId,
    required this.disabled,
  });

  final String? providerId;
  final String? modelId;
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(providerControllerProvider).value;
    final enabled = state?.configs.where((c) => c.enabled).toList() ?? const [];
    ProviderConfig? current;
    for (final config in enabled) {
      if (config.id == providerId) {
        current = config;
        break;
      }
    }
    final model = modelId ?? current?.selectedModel;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LotusBreakpoints.chatMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LotusSpace.lg,
            LotusSpace.xs,
            LotusSpace.lg,
            LotusSpace.xs,
          ),
          child: Row(
            children: [
              Flexible(
                child: _SelectorPill(
                  icon: Icons.hub_outlined,
                  label: current?.name ?? 'Provedor',
                  muted: current == null,
                  onTap: disabled
                      ? null
                      : () => _pickProvider(context, ref, enabled, current),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: LotusSpace.sm),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: context.palette.muted.withValues(alpha: 0.6),
                ),
              ),
              Flexible(
                flex: 2,
                child: _SelectorPill(
                  icon: Icons.memory_rounded,
                  label: model ?? 'Modelo',
                  muted: model == null,
                  onTap: disabled
                      ? null
                      : () => _pickModel(context, ref, current, model),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProvider(
    BuildContext context,
    WidgetRef ref,
    List<ProviderConfig> configs,
    ProviderConfig? current,
  ) async {
    if (configs.isEmpty) {
      await _openSettings(context);
      return;
    }
    final selected = await showLotusSheet<ProviderConfig>(
      context,
      builder: (ctx) => _SheetList(
        title: 'Provedor',
        subtitle: 'Escolha qual serviço responde esta conversa.',
        children: [
          for (final config in configs)
            _SheetOption(
              icon: Icons.hub_outlined,
              title: config.name,
              subtitle: config.selectedModel ?? 'Modelo não selecionado',
              selected: config.id == current?.id,
              onTap: () => Navigator.pop(ctx, config),
            ),
          const SizedBox(height: LotusSpace.sm),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openSettings(context);
            },
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Gerenciar provedores'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    await ref
        .read(chatControllerProvider.notifier)
        .updateActiveSelection(
          providerId: selected.id,
          modelId: selected.selectedModel,
        );
  }

  Future<void> _pickModel(
    BuildContext context,
    WidgetRef ref,
    ProviderConfig? config,
    String? current,
  ) async {
    if (config == null) {
      await _openSettings(context);
      return;
    }
    final models = config.availableModels;
    if (models.isEmpty) {
      LotusFeedback.show(
        context,
        'Nenhum modelo listado. Teste a conexão do provedor em Ajustes.',
        tone: LotusSnackTone.warning,
      );
      return;
    }
    final selected = await showLotusSheet<String>(
      context,
      builder: (ctx) => _ModelPickerSheet(
        models: models,
        current: current,
        contextLimit: config.modelContextLimits,
      ),
    );
    if (selected == null) return;
    await ref
        .read(chatControllerProvider.notifier)
        .updateActiveSelection(modelId: selected);
  }

  Future<void> _openSettings(BuildContext context) async {
    if (context.mounted) context.go('/settings');
  }
}

class _SelectorPill extends StatelessWidget {
  const _SelectorPill({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.muted,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.scheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LotusRadius.pill),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: LotusSpace.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(LotusRadius.pill),
          border: Border.all(
            color: muted
                ? scheme.error.withValues(alpha: 0.35)
                : palette.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: muted ? scheme.error : scheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: muted ? scheme.error : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelPickerSheet extends StatefulWidget {
  const _ModelPickerSheet({
    required this.models,
    required this.current,
    required this.contextLimit,
  });

  final List<String> models;
  final String? current;
  final Map<String, int> contextLimit;

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  final _search = TextEditingController();
  late List<String> _filtered = widget.models;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.models
          : widget.models
                .where((m) => m.toLowerCase().contains(query))
                .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LotusSpace.xl,
              LotusSpace.sm,
              LotusSpace.lg,
              LotusSpace.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modelo', style: context.text.titleMedium),
                const SizedBox(height: LotusSpace.sm),
                TextField(
                  controller: _search,
                  autofocus: false,
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: 'Buscar entre ${widget.models.length} modelos',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _search.clear();
                              _filter('');
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum modelo corresponde à busca.',
                      style: context.text.bodySmall,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      LotusSpace.md,
                      0,
                      LotusSpace.md,
                      LotusSpace.xl,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final model = _filtered[index];
                      final limit = widget.contextLimit[model];
                      final selected = model == widget.current;
                      return _SheetOption(
                        icon: Icons.memory_rounded,
                        title: model,
                        subtitle: limit == null
                            ? null
                            : '${limit ~/ 1000}k tokens de contexto',
                        selected: selected,
                        onTap: () => Navigator.pop(context, model),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SheetList extends StatelessWidget {
  const _SheetList({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LotusSpace.md,
          LotusSpace.xs,
          LotusSpace.md,
          LotusSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LotusSpace.sm,
                0,
                LotusSpace.sm,
                LotusSpace.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.text.bodySmall),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LotusSpace.xs),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(LotusRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(LotusRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LotusSpace.md,
              vertical: LotusSpace.md,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? scheme.primary : context.palette.muted,
                ),
                const SizedBox(width: LotusSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall,
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, size: 20, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

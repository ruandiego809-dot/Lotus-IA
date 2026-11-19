// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/theme.dart';
import '../../../core/models/provider_models.dart';
import '../../../design/design.dart';

import '../../providers/data/provider_repository.dart';
import '../domain/config_import.dart';
import 'widgets/provider_editor_sheet.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;

  Future<void> _editProvider(ProviderConfig config) async {
    String? storedKey;
    try {
      storedKey = await ref.read(secureStoreProvider).readApiKey(config.id);
    } catch (_) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Não foi possível ler a chave no armazenamento seguro.',
          tone: LotusSnackTone.error,
        );
      }
      return;
    }
    if (!mounted) return;
    await showLotusSheet<void>(
      context,
      builder: (_) => ProviderEditorSheet(config: config, storedKey: storedKey),
    );
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final providers = ref.read(providerControllerProvider).value?.configs;
      if (providers == null) {
        throw StateError('Configurações de provedores indisponíveis.');
      }
      final data = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': {
          'themeMode': ThemeModeController.encode(ref.read(themeModeProvider)),
        },
        'providers': providers.map((p) => p.toJson()).toList(),
        'note': 'Chaves do armazenamento seguro não são exportadas. Endpoints podem conter dados sensíveis.',
      };
      final dir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${dir.path}/lotus_ai');
      await exportDir.create(recursive: true);
      final file = File('${exportDir.path}/lotus_config_export.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
      if (!mounted) return;
      await showLotusTextPreview(
        context,
        title: 'Configurações exportadas',
        caption: 'Chaves não incluídas. Endpoints podem conter dados sensíveis — verifique antes de compartilhar.',
        text: file.path,
      );
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Falha ao exportar: $error',
          tone: LotusSnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final input = await showDialog<String>(
      context: context,
      builder: (_) => const _ImportConfigDialog(),
    );
    if (input == null || !mounted) return;
    try {
      final imported = ConfigImport.parse(jsonDecode(input));
      await ref
          .read(providerControllerProvider.notifier)
          .save(imported.providers);
      await ref
          .read(themeModeProvider.notifier)
          .setMode(ThemeModeController.parse(imported.themeMode));
      if (mounted) {
        LotusFeedback.show(
          context,
          'Configurações importadas. As chaves locais foram mantidas.',
          tone: LotusSnackTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Importação inválida. Nenhuma alteração parcial foi confirmada.',
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(providerControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return LotusScaffold(
      appBar: const LotusAppBar(
        title: 'Ajustes',
        subtitle: 'Aparência, dados e provedores',
      ),
      body: providers.when(
        loading: () => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(LotusSpace.xxl),
            child: Text(
              'Não foi possível carregar os ajustes.\n$error',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ),
        ),
        data: (state) => LotusPage(
          onRefresh: () => ref.read(providerControllerProvider.notifier).load(),
          children: [
            if (_busy) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: LotusSpace.md),
            ],
            const LotusSectionHeader(title: 'Aparência'),
            LotusAppearanceSelector(
              mode: themeMode,
              onChanged: (mode) =>
                  ref.read(themeModeProvider.notifier).setMode(mode),
            ),
            const SizedBox(height: LotusSpace.xl),
            const LotusSectionHeader(
              title: 'Dados',
              subtitle: 'Portabilidade sem expor chaves de API.',
            ),
            LotusCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const LotusIconBadge(
                      icon: Icons.upload_file_outlined,
                      size: 38,
                    ),
                    title: const Text('Exportar configurações'),
                    subtitle: const Text('Gera um JSON sem chaves seguras'),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: context.palette.muted,
                    ),
                    onTap: _export,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const LotusIconBadge(
                      icon: Icons.download_outlined,
                      size: 38,
                    ),
                    title: const Text('Importar configurações'),
                    subtitle: const Text('Cole o JSON exportado'),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: context.palette.muted,
                    ),
                    onTap: _import,
                  ),
                ],
              ),
            ),
            const SizedBox(height: LotusSpace.xl),
            LotusSectionHeader(
              title: 'Provedores',
              subtitle: 'Chaves, endpoints, modelos e limites de contexto. Cada provedor usa um adaptador próprio.',
              trailing: LotusPill(
                '${state.configs.where((c) => c.enabled).length} ativos',
                tone: LotusPillTone.primary,
              ),
            ),
            for (final config in state.configs)
              Padding(
                padding: const EdgeInsets.only(bottom: LotusSpace.sm),
                child: _ProviderTile(
                  config: config,
                  onTap: () => _editProvider(config),
                ),
              ),
            const SizedBox(height: LotusSpace.xl),
            const LotusSectionHeader(title: 'Estado dos módulos'),
            const LotusCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Chat e provedores',
                    description: 'Streaming, histórico com busca e exportação, edição/regeneração, prompt por conversa e limites manuais de contexto. Métricas reais só aparecem quando a API as retorna.',
                    ok: true,
                  ),
                  Divider(height: LotusSpace.xl),
                  _StatusRow(
                    icon: Icons.folder_outlined,
                    title: 'Projetos',
                    description: 'Workspace local com criar, editar, renomear, excluir, diff e import/export ZIP. Clone Git autenticado e build in-app exigem integrações adicionais.',
                    ok: true,
                  ),
                  Divider(height: LotusSpace.xl),
                  _StatusRow(
                    icon: Icons.terminal_outlined,
                    title: 'Terminal Linux',
                    description: 'Alpine real via PRoot/PTY, com download do rootfs e sessões. Depende de binários compatíveis no Android sem root; falhas são reportadas sem simulação.',
                    ok: false,
                  ),
                  Divider(height: LotusSpace.xl),
                  _StatusRow(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Agentes e multimodal',
                    description: 'Sessões especializadas já funcionam. Orquestração autônoma e envio de imagens por modelo dependem de suporte real do provedor.',
                    ok: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: LotusSpace.lg),
            Center(
              child: Column(
                children: [
                  const LotusBrandMark(size: 34),
                  const SizedBox(height: LotusSpace.sm),
                  Text(
                    'Lótus AI 0.6.0',
                    style: context.text.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Design system premium • Flutter',
                    style: context.text.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Light / dark / system switch with clear affordances.
class LotusAppearanceSelector extends StatelessWidget {
  const LotusAppearanceSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return LotusCard(
      padding: const EdgeInsets.all(LotusSpace.sm),
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          side: BorderSide.none,
          backgroundColor: Colors.transparent,
          selectedBackgroundColor: context.scheme.primary.withValues(
            alpha: 0.12,
          ),
          selectedForegroundColor: context.scheme.primary,
          foregroundColor: context.palette.muted,
          padding: const EdgeInsets.symmetric(vertical: LotusSpace.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LotusRadius.sm),
          ),
        ),
        segments: const [
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_outlined, size: 18),
            label: Text('Claro'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_outlined, size: 18),
            label: Text('Escuro'),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.contrast_rounded, size: 18),
            label: Text('Sistema'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    );
  }
}

class _ProviderTile extends ConsumerWidget {
  const _ProviderTile({required this.config, required this.onTap});

  final ProviderConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyAsync = ref.watch(apiKeyProvider(config.id));
    final hasKey = keyAsync.valueOrNull?.isNotEmpty ?? false;
    final scheme = context.scheme;
    final palette = context.palette;
    return LotusCard(
      radius: LotusRadius.sm,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LotusSpace.md,
          LotusSpace.md,
          LotusSpace.sm,
          LotusSpace.md,
        ),
        child: Row(
          children: [
            LotusIconBadge(
              icon: Icons.hub_outlined,
              size: 40,
              color: config.enabled ? scheme.primary : palette.muted,
            ),
            const SizedBox(width: LotusSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          config.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (config.isDefault) ...[
                        const SizedBox(width: LotusSpace.sm),
                        const LotusPill(
                          'Padrão',
                          tone: LotusPillTone.primary,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      config.enabled ? 'Ativo' : 'Inativo',
                      hasKey ? 'Chave configurada' : 'Sem chave',
                      if (config.selectedModel != null) config.selectedModel!,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.ok,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: ok ? context.palette.success : context.palette.muted,
        ),
        const SizedBox(width: LotusSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  LotusPill(
                    ok ? 'Ativo' : 'Parcial',
                    tone: ok ? LotusPillTone.success : LotusPillTone.neutral,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: context.text.labelSmall?.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImportConfigDialog extends StatefulWidget {
  const _ImportConfigDialog();

  @override
  State<_ImportConfigDialog> createState() => _ImportConfigDialogState();
}

class _ImportConfigDialogState extends State<_ImportConfigDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importar configurações'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: TextField(
          controller: _controller,
          maxLines: 10,
          minLines: 6,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Cole aqui o JSON exportado',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Importar'),
        ),
      ],
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _checkingUpdate = false;
  String? _latestVersion;
  String? _updateUrl;

  static const _currentVersion = '0.6.3';
  static const _githubRepo = 'ruandiego809-dot/LOTUS';

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdate = true);
    try {
      const apiUrl = 'https://api.github.com/repos/$_githubRepo/releases/latest';
      final response = await Dio().get(apiUrl);
      final data = response.data as Map<String, dynamic>;
      _latestVersion = data['tag_name'] as String?;
      _updateUrl = data['html_url'] as String?;

      if (_latestVersion != null && _latestVersion != _currentVersion) {
        if (mounted) {
          await _showUpdateDialog();
        }
      } else if (mounted) {
        LotusFeedback.show(
          context,
          'You are on the latest version ($_currentVersion).',
          tone: LotusSnackTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Could not check for updates.',
          tone: LotusSnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _showUpdateDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New update available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current version: $_currentVersion\nNew version: $_latestVersion',
              style: ctx.text.bodyMedium,
            ),
            const SizedBox(height: LotusSpace.md),
            const Text(
              'What\'s new:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: LotusSpace.xs),
            Text(
              '• Code block with one-tap copy\n'
              '• "Copied" toast in settings\n'
              '• Compact mode\n'
              '• Quick reply from history\n'
              '• More empty state suggestions\n'
              '• New app icon (minimalist lotus flower)\n'
              '• Official API key website button in providers\n'
              '• Update check button',
              style: ctx.text.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_updateUrl != null && await canLaunchUrl(Uri.parse(_updateUrl!))) {
                await launchUrl(Uri.parse(_updateUrl!));
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _editProvider(ProviderConfig config) async {
    String? storedKey;
    try {
      storedKey = await ref.read(secureStoreProvider).readApiKey(config.id);
    } catch (_) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Could not read key from secure storage.',
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
        throw StateError('Provider configurations unavailable.');
      }
      final data = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': {
          'themeMode': ThemeModeController.encode(ref.read(themeModeProvider)),
        },
        'providers': providers.map((p) => p.toJson()).toList(),
        'note':
            'API keys are not exported. Endpoints may contain sensitive data — verify before sharing.',
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
        title: 'Settings exported',
        caption:
            'Keys not included. Endpoints may contain sensitive data — verify before sharing.',
        text: file.path,
      );
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Export failed: $error',
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
      await ref.read(providerControllerProvider.notifier).save(imported.providers);
      await ref.read(themeModeProvider.notifier).setMode(ThemeModeController.parse(imported.themeMode));
      if (mounted) {
        LotusFeedback.show(
          context,
          'Settings imported. Local keys were preserved.',
          tone: LotusSnackTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Invalid import. No partial changes were confirmed.',
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(providerControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final compactMode = ref.watch(compactModeProvider);
    return LotusScaffold(
      appBar: const LotusAppBar(
        title: 'Settings',
        subtitle: 'Appearance, data and providers',
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
              'Could not load settings.\n$error',
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
            const LotusSectionHeader(title: 'Appearance'),
            LoyalAppearanceSelector(
              mode: themeMode,
              onChanged: (mode) =>
                  ref.read(themeModeProvider.notifier).setMode(mode),
            ),
            const SizedBox(height: LotusSpace.md),
            ListTile(
              leading: const Icon(Icons.keyboard_rounded),
              title: const Text('Compact mode'),
              subtitle: const Text(
                'Tighter spacing for small screens',
              ),
              trailing: Switch(
                value: compactMode,
                onChanged: (value) =>
                    ref.read(compactModeProvider.notifier).setCompact(value),
              ),
            ),
            const SizedBox(height: LotusSpace.xl),
            const LotusSectionHeader(
              title: 'Updates',
              subtitle: 'Check for new available versions.',
            ),
            ListTile(
              leading: const LotusIconBadge(
                icon: Icons.update_rounded,
                size: 38,
              ),
              title: const Text('Check for updates'),
              subtitle: Text(
                'Current version: $_currentVersion',
                style: context.text.labelSmall,
              ),
              trailing: _checkingUpdate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.chevron_right_rounded,
                      color: context.palette.muted,
                    ),
              onTap: _checkingUpdate ? null : _checkForUpdates,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const LotusIconBadge(
                icon: Icons.upload_file_outlined,
                size: 38,
              ),
              title: const Text('Export settings'),
              subtitle: const Text('Generates a JSON without secure keys'),
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
              title: const Text('Import settings'),
              subtitle: const Text('Paste the exported JSON'),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: context.palette.muted,
              ),
              onTap: _import,
            ),
            const Divider(height: 1),
            const SizedBox(height: LotusSpace.xl),
            LotusSectionHeader(
              title: 'Providers',
              subtitle:
                  'Keys, endpoints, models and context limits. Each provider uses its own adapter.',
              trailing: LotusPill(
                '${state.configs.where((c) => c.enabled).length} active',
                tone: LotusPillTone.primary,
              ),
        ),
      ...[
        for (final config in state.configs)
          Padding(
            padding: const EdgeInsets.only(bottom: LotusSpace.sm),
            child: _ProviderTile(
              config: config,
              onTap: () => _editProvider(config),
            ),
          ),
      ],
            const SizedBox(height: LotusSpace.xl),
            const LotusSectionHeader(title: 'Module status'),
            const LotusCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Chat and providers',
                    description:
                        'Streaming, history with search and export, edit/regenerate, prompt per conversation and manual context limits. Real metrics only appear when the API returns them.',
                    ok: true,
                  ),
                  Divider(height: LotusSpace.xl),
                  _StatusRow(
                    icon: Icons.folder_outlined,
                    title: 'Projects',
                    description:
                        'Local workspace with create, edit, rename, delete, diff and import/export ZIP. Authenticated Git clone and in-app build require additional integrations.',
                    ok: true,
                  ),
                  Divider(height: LotusSpace.xl),
                  _StatusRow(
                    icon: Icons.terminal_outlined,
                    title: 'Linux Terminal',
                    description:
                        'Real Alpine via PRoot/PTY, with rootfs download and sessions. Depends on compatible binaries on Android without root; failures are reported without simulation.',
                    ok: false,
                  ),
                  Divider(height: LotusSpace.xl),
                  _StatusRow(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Agents and multimodal',
                    description:
                        'Specialized sessions already work. Autonomous orchestration and image sending by model depend on real provider support.',
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
                    'Lótus AI 0.6.1',
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
class LoyalAppearanceSelector extends StatelessWidget {
  const LoyalAppearanceSelector({
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
          selectedBackgroundColor:
              context.scheme.primary.withValues(alpha: 0.12),
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
            label: Text('Light'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_outlined, size: 18),
            label: Text('Dark'),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.contrast_rounded, size: 18),
            label: Text('System'),
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
                          style: context.text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (config.isDefault) ...[
                        const SizedBox(width: LotusSpace.sm),
                        const LotusPill(
                          'Default',
                          tone: LotusPillTone.primary,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      config.enabled ? 'Active' : 'Inactive',
                      hasKey ? 'Key configured' : 'No key',
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
                      style: context.text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  LotusPill(
                    ok ? 'Active' : 'Partial',
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
      title: const Text('Import settings'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: TextField(
          controller: _controller,
          maxLines: 10,
          minLines: 6,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Paste the exported JSON here',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Import'),
        ),
      ],
    );
  }
}

// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../design/design.dart';

import '../data/project_repository.dart';
import 'project_file_editor_page.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final _repo = ProjectRepository();
  Directory? _root;
  Directory? _current;
  List<ProjectEntry> _entries = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final root = await _repo.root();
      if (!mounted) return;
      _root = root;
      _current = root;
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final dir = _current;
    if (dir == null) return;
    final token = ++_loadToken;
    if (_entries.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final entries = await _repo.list(dir);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _openDirectory(Directory dir) async {
    _current = dir;
    _entries = const [];
    await _refresh();
  }

  Future<void> _goBack() async {
    final current = _current;
    final root = _root;
    if (current == null || root == null || current.path == root.path) return;
    await _openDirectory(current.parent);
  }

  Future<void> _createProject() async {
    final root = _root;
    if (root == null) return;
    final name = await showLotusPrompt(
      context,
      title: 'Novo projeto',
      message: 'Um README.md inicial é criado automaticamente.',
      hint: 'Nome do projeto',
      confirmLabel: 'Criar',
      icon: Icons.create_new_folder_outlined,
    );
    if (name == null) return;
    try {
      final dir = await _repo.createProject(root, name);
      if (!mounted) return;
      await _openDirectory(dir);
      if (mounted) {
        LotusFeedback.show(
          context,
          'Projeto "$name" criado',
          tone: LotusSnackTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Erro ao criar: $error',
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  Future<void> _createFolder() async {
    final current = _current;
    if (current == null) return;
    final name = await showLotusPrompt(
      context,
      title: 'Nova pasta',
      hint: 'Nome da pasta',
      initialValue: 'nova_pasta',
      confirmLabel: 'Criar',
      icon: Icons.folder_open_outlined,
    );
    if (name == null) return;
    try {
      await _repo.createFolder(current, name);
      await _refresh();
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Erro ao criar pasta: $error',
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  Future<void> _createFile() async {
    final current = _current;
    if (current == null) return;
    final name = await showLotusPrompt(
      context,
      title: 'Novo arquivo',
      hint: 'Nome do arquivo',
      initialValue: 'novo_arquivo.txt',
      confirmLabel: 'Criar',
      icon: Icons.note_add_outlined,
    );
    if (name == null) return;
    try {
      await _repo.createFile(current, name);
      await _refresh();
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Erro ao criar arquivo: $error',
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  Future<void> _rename(ProjectEntry entry) async {
    final name = await showLotusPrompt(
      context,
      title: 'Renomear',
      hint: 'Novo nome',
      initialValue: entry.name,
      selectAll: true,
      icon: Icons.drive_file_rename_outline_rounded,
    );
    if (name == null) return;
    try {
      await _repo.rename(entry.entity, name);
      await _refresh();
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Erro ao renomear: $error',
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  Future<void> _delete(ProjectEntry entry) async {
    final confirmed = await showLotusConfirm(
      context,
      title: 'Excluir item?',
      message: entry.isDirectory
          ? '"${entry.name}" e todo o seu conteúdo serão removidos.'
          : '"${entry.name}" será removido.',
      confirmLabel: 'Excluir',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    try {
      await _repo.delete(entry.entity);
      await _refresh();
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Erro ao excluir: $error',
          tone: LotusSnackTone.error,
        );
      }
    }
  }

  Future<void> _openEntry(ProjectEntry entry) async {
    if (entry.isDirectory) {
      await _openDirectory(entry.entity as Directory);
      return;
    }
    final file = entry.entity as File;
    String content;
    try {
      content = await file.readAsString();
    } catch (_) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Arquivo binário ou não legível como texto.',
          tone: LotusSnackTone.warning,
        );
      }
      return;
    }
    if (content.contains('\u0000')) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Arquivos binários não podem ser editados.',
          tone: LotusSnackTone.warning,
        );
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProjectFileEditorPage(file: file, initialContent: content),
      ),
    );
    await _refresh();
  }

  Future<void> _exportZip() async {
    final current = _current;
    if (current == null || _busy) return;
    setState(() => _busy = true);
    try {
      final path = await _repo.exportZip(current);
      if (!mounted) return;
      await showLotusTextPreview(
        context,
        title: 'ZIP exportado',
        caption: 'Arquivo salvo no armazenamento do app. Copie o caminho se precisar.',
        text: path,
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

  Future<void> _importZip() async {
    final current = _current;
    if (current == null || _busy) return;
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      if (picked == null || picked.path == null || !mounted) return;
      setState(() => _busy = true);
      await _repo.importZip(current, picked.path!);
      await _refresh();
      if (mounted) {
        LotusFeedback.show(
          context,
          'ZIP importado',
          tone: LotusSnackTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Falha ao importar ZIP: $error',
          tone: LotusSnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importGithub() async {
    final current = _current;
    if (current == null || _busy) return;
    final input = await showLotusPrompt(
      context,
      title: 'Importar do GitHub',
      message: 'Repositório público. O ZIP da branch main ou master é baixado.',
      hint: 'owner/repo',
      confirmLabel: 'Importar',
      icon: Icons.cloud_download_outlined,
    );
    if (input == null) return;
    final cleaned = input
        .trim()
        .replaceAll('https://github.com/', '')
        .replaceAll(RegExp(r'^/+|/+$'), '');
    final parts = cleaned.split('/').where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Formato inválido. Use owner/repo.',
          tone: LotusSnackTone.warning,
        );
      }
      return;
    }
    final repo = parts[1].replaceAll(RegExp(r'\.git$'), '');
    setState(() => _busy = true);
    try {
      final label = await _repo.importGithub(
        target: current,
        owner: parts[0],
        repo: repo,
      );
      await _refresh();
      if (mounted) {
        LotusFeedback.show(
          context,
          'Importado: $label',
          tone: LotusSnackTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Falha ao importar: $error',
          tone: LotusSnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showLimitations() async {
    await showLotusTextPreview(
      context,
      title: 'Escopo do workspace',
      text:
          'Disponível agora:\n'
          '• Workspace local com criar, renomear, editar e excluir.\n'
          '• Diff simples ao editar arquivos, com proteção contra perda de alterações.\n'
          '• Importação/exportação de ZIP e importação de repositório público do GitHub.\n\n'
          'Integrações adicionais (não simuladas):\n'
          '• Clone Git nativo com autenticação.\n'
          '• Execução de código e build Android dentro do app.\n'
          '• Modificações autônomas por agentes com permissões auditáveis.',
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  List<String> get _breadcrumbs {
    final root = _root;
    final current = _current;
    if (root == null || current == null) return const [];
    if (current.path == root.path) return const ['Projetos'];
    final relative = p.relative(current.path, from: root.path);
    return ['Projetos', ...relative.split(Platform.pathSeparator)];
  }

  @override
  Widget build(BuildContext context) {
    final isRoot = _root != null && _current?.path == _root?.path;
    return LotusScaffold(
      appBar: LotusAppBar(
        title: isRoot
            ? 'Projetos'
            : (_current?.path.split(Platform.pathSeparator).last ?? 'Projetos'),
        subtitle: isRoot ? 'Workspace local' : '${_entries.length} itens',
        leading: isRoot
            ? null
            : IconButton(
                tooltip: 'Voltar',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _goBack,
              ),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 21),
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            icon: const Icon(Icons.more_horiz_rounded, size: 21),
            onSelected: (value) {
              switch (value) {
                case 'zip-import':
                  _importZip();
                case 'zip-export':
                  _exportZip();
                case 'github':
                  _importGithub();
                case 'limitations':
                  _showLimitations();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'zip-import',
                child: _MenuRow(
                  icon: Icons.folder_zip_outlined,
                  label: 'Importar ZIP',
                ),
              ),
              PopupMenuItem(
                value: 'zip-export',
                child: _MenuRow(
                  icon: Icons.archive_outlined,
                  label: 'Exportar ZIP',
                ),
              ),
              PopupMenuItem(
                value: 'github',
                child: _MenuRow(
                  icon: Icons.cloud_download_outlined,
                  label: 'Importar do GitHub',
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'limitations',
                child: _MenuRow(
                  icon: Icons.info_outline_rounded,
                  label: 'Escopo do workspace',
                ),
              ),
            ],
          ),
          const SizedBox(width: LotusSpace.sm),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: LotusBreakpoints.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy) const LinearProgressIndicator(minHeight: 2),
              _Breadcrumbs(segments: _breadcrumbs, onTapRoot: _goBack),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LotusSpace.lg,
                  LotusSpace.xs,
                  LotusSpace.lg,
                  LotusSpace.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _createProject,
                        icon: const Icon(Icons.add_rounded, size: 19),
                        label: const Text('Novo projeto'),
                      ),
                    ),
                    const SizedBox(width: LotusSpace.sm),
                    _CompactAction(
                      tooltip: 'Nova pasta',
                      icon: Icons.create_new_folder_outlined,
                      onTap: _createFolder,
                    ),
                    const SizedBox(width: LotusSpace.sm),
                    _CompactAction(
                      tooltip: 'Novo arquivo',
                      icon: Icons.note_add_outlined,
                      onTap: _createFile,
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(LotusSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_off_outlined,
                size: 40,
                color: context.scheme.error,
              ),
              const SizedBox(height: LotusSpace.md),
              Text(
                'Não foi possível listar esta pasta.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: LotusSpace.xxs),
              Text(
                error,
                style: context.text.labelSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LotusSpace.lg),
              FilledButton.tonalIcon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LotusSpace.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const LotusIconBadge(
                  icon: Icons.folder_open_rounded,
                  size: 64,
                  gradient: true,
                ),
                const SizedBox(height: LotusSpace.lg),
                Text('Pasta vazia', style: context.text.titleMedium),
                const SizedBox(height: LotusSpace.xs),
                Text(
                  'Crie um projeto, uma pasta ou um arquivo para começar. Você também pode importar um ZIP.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: LotusSpace.lg),
                FilledButton.tonalIcon(
                  onPressed: _createProject,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Criar projeto'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          LotusSpace.lg,
          0,
          LotusSpace.lg,
          LotusSpace.xxl,
        ),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: LotusSpace.sm),
            child: _EntryTile(
              entry: entry,
              formatBytes: _formatBytes,
              onOpen: () => _openEntry(entry),
              onRename: () => _rename(entry),
              onDelete: () => _delete(entry),
            ),
          );
        },
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.formatBytes,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final ProjectEntry entry;
  final String Function(int) formatBytes;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitle = entry.isDirectory
        ? 'Pasta'
        : '${formatBytes(entry.size)} • ${_date(entry.modified)}';
    return LotusCard(
      radius: LotusRadius.sm,
      padding: EdgeInsets.zero,
      onTap: onOpen,
      child: ListTile(
        leading: LotusIconBadge(
          icon: entry.isDirectory
              ? Icons.folder_rounded
              : Icons.insert_drive_file_outlined,
          size: 38,
          color: entry.isDirectory ? null : context.palette.muted,
        ),
        title: Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: context.text.labelSmall),
        trailing: PopupMenuButton<String>(
          tooltip: 'Opções',
          icon: const Icon(Icons.more_vert_rounded, size: 18),
          onSelected: (value) {
            if (value == 'rename') onRename();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'rename',
              child: _MenuRow(
                icon: Icons.drive_file_rename_outline_rounded,
                label: 'Renomear',
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: 'Excluir',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime? value) {
    if (value == null) return '—';
    final d = value;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.segments, required this.onTapRoot});

  final List<String> segments;
  final VoidCallback onTapRoot;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        LotusSpace.lg,
        LotusSpace.xs,
        LotusSpace.lg,
        0,
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: context.palette.muted.withValues(alpha: 0.6),
                ),
              ),
            InkWell(
              onTap: i == 0 ? onTapRoot : null,
              borderRadius: BorderRadius.circular(LotusRadius.xs),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  segments[i],
                  style: context.text.labelSmall?.copyWith(
                    color: i == segments.length - 1
                        ? context.scheme.onSurface
                        : context.palette.muted,
                    fontWeight: i == segments.length - 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LotusRadius.sm),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: context.scheme.surfaceContainerHighest.withValues(
              alpha: 0.6,
            ),
            borderRadius: BorderRadius.circular(LotusRadius.sm),
            border: Border.all(color: context.palette.border),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
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

// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/simple_diff.dart';
import '../../../design/design.dart';



class ProjectFileEditorPage extends StatefulWidget {
  const ProjectFileEditorPage({
    super.key,
    required this.file,
    required this.initialContent,
  });

  final File file;
  final String initialContent;

  @override
  State<ProjectFileEditorPage> createState() => _ProjectFileEditorPageState();
}

class _ProjectFileEditorPageState extends State<ProjectFileEditorPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialContent,
  );
  late String _saved = widget.initialContent;
  bool _saving = false;

  bool get _dirty => _controller.text != _saved;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.file.writeAsString(_controller.text);
      _saved = _controller.text;
      if (mounted) {
        setState(() {});
        LotusFeedback.show(
          context,
          'Arquivo salvo',
          tone: LotusSnackTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        LotusFeedback.show(
          context,
          'Erro ao salvar: $error',
          tone: LotusSnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showDiff() async {
    final diff = simpleLineDiff(_saved, _controller.text);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterações'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            padding: const EdgeInsets.all(LotusSpace.md),
            decoration: BoxDecoration(
              color: ctx.scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(LotusRadius.sm),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                diff.isEmpty ? 'Sem alterações.' : diff,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
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

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return showLotusConfirm(
      context,
      title: 'Descartar alterações?',
      message:
          'As mudanças feitas em ${p.basename(widget.file.path)} não foram salvas.',
      confirmLabel: 'Descartar',
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = _controller.text.isEmpty
        ? 0
        : '\n'.allMatches(_controller.text).length + 1;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: LotusAppBar(
          title: p.basename(widget.file.path),
          subtitle: _dirty
              ? 'Alterações não salvas'
              : 'Todas as alterações salvas',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              final discard = await _confirmDiscard();
              if (discard && context.mounted) Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Ver alterações',
              onPressed: _showDiff,
              icon: const Icon(Icons.difference_outlined, size: 20),
            ),
            Padding(
              padding: const EdgeInsets.only(right: LotusSpace.sm),
              child: _dirty
                  ? FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_saving ? 'Salvando' : 'Salvar'),
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(horizontal: LotusSpace.md),
                      child: LotusPill(
                        'Salvo',
                        icon: Icons.check_rounded,
                        tone: LotusPillTone.success,
                      ),
                    ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(
                  LotusSpace.md,
                  LotusSpace.sm,
                  LotusSpace.md,
                  LotusSpace.sm,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: LotusSpace.md,
                  vertical: LotusSpace.sm,
                ),
                decoration: BoxDecoration(
                  color: context.palette.elevated,
                  borderRadius: BorderRadius.circular(LotusRadius.md),
                  border: Border.all(color: context.palette.border),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Conteúdo do arquivo',
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                LotusSpace.lg,
                0,
                LotusSpace.lg,
                LotusSpace.sm,
              ),
              child: Row(
                children: [
                  Text('$lines linhas', style: context.text.labelSmall),
                  const SizedBox(width: LotusSpace.md),
                  Text(
                    '${_controller.text.length} caracteres',
                    style: context.text.labelSmall,
                  ),
                  const Spacer(),
                  if (_dirty)
                    const LotusPill(
                      'Não salvo',
                      icon: Icons.circle,
                      tone: LotusPillTone.warning,
                      dense: true,
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

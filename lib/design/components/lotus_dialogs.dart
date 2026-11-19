// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'lotus_card.dart';

/// Text-input dialog that owns and disposes its controller.
Future<String?> showLotusPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String? hint,
  String initialValue = '',
  String confirmLabel = 'Salvar',
  int maxLines = 1,
  String? helperText,
  TextInputType? keyboardType,
  bool obscure = false,
  bool selectAll = false,
  String? validateMessage,
  IconData? icon,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _LotusPromptDialog(
      title: title,
      message: message,
      hint: hint,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
      maxLines: maxLines,
      helperText: helperText,
      keyboardType: keyboardType,
      obscure: obscure,
      selectAll: selectAll,
      validateMessage: validateMessage,
      icon: icon,
    ),
  );
}

class _LotusPromptDialog extends StatefulWidget {
  const _LotusPromptDialog({
    required this.title,
    required this.initialValue,
    required this.confirmLabel,
    required this.maxLines,
    required this.obscure,
    required this.selectAll,
    this.message,
    this.hint,
    this.helperText,
    this.keyboardType,
    this.validateMessage,
    this.icon,
  });

  final String title;
  final String? message;
  final String? hint;
  final String initialValue;
  final String confirmLabel;
  final int maxLines;
  final String? helperText;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool selectAll;
  final String? validateMessage;
  final IconData? icon;

  @override
  State<_LotusPromptDialog> createState() => _LotusPromptDialogState();
}

class _LotusPromptDialogState extends State<_LotusPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.selectAll ? widget.initialValue.length : 0,
        );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = widget.validateMessage ?? 'Informe um valor.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: LotusSpace.xl),
      title: Row(
        children: [
          if (widget.icon != null) ...[
            LotusIconBadge(icon: widget.icon!, size: 34),
            const SizedBox(width: LotusSpace.md),
          ],
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(widget.message!, style: context.text.bodyMedium),
              const SizedBox(height: LotusSpace.lg),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: widget.maxLines,
              minLines: 1,
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              textInputAction: widget.maxLines == 1
                  ? TextInputAction.done
                  : TextInputAction.newline,
              onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
              decoration: InputDecoration(
                hintText: widget.hint,
                helperText: widget.helperText,
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        LotusSpace.lg,
        0,
        LotusSpace.lg,
        LotusSpace.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Confirmation dialog with destructive styling.
Future<bool> showLotusConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: LotusSpace.xl),
      icon: icon == null
          ? null
          : Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (destructive ? ctx.scheme.error : ctx.scheme.primary)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: destructive ? ctx.scheme.error : ctx.scheme.primary,
                size: 22,
              ),
            ),
      title: Text(title, textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(message, textAlign: TextAlign.center),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(
        LotusSpace.lg,
        0,
        LotusSpace.lg,
        LotusSpace.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: ctx.scheme.error,
                  foregroundColor: ctx.scheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Copy-to-clipboard dialog used for exports.
Future<void> showLotusTextPreview(
  BuildContext context, {
  required String title,
  required String text,
  String? caption,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (caption != null) ...[
              Text(caption, style: ctx.text.bodySmall),
              const SizedBox(height: LotusSpace.md),
            ],
            Container(
              constraints: const BoxConstraints(maxHeight: 380),
              width: double.infinity,
              padding: const EdgeInsets.all(LotusSpace.md),
              decoration: BoxDecoration(
                color: ctx.scheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(LotusRadius.sm),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fechar'),
        ),
        FilledButton.tonalIcon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copiar'),
        ),
      ],
    ),
  );
}

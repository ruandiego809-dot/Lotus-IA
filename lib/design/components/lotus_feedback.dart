// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens.dart';

enum LotusSnackTone { info, success, warning, error }

/// Consistent, compact floating messages across the app.
abstract final class LotusFeedback {
  static void show(
    BuildContext context,
    String message, {
    LotusSnackTone tone = LotusSnackTone.info,
  }) {
    final palette = context.palette;
    final scheme = context.scheme;
    final color = switch (tone) {
      LotusSnackTone.info => scheme.primary,
      LotusSnackTone.success => palette.success,
      LotusSnackTone.warning => palette.warning,
      LotusSnackTone.error => scheme.error,
    };
    final icon = switch (tone) {
      LotusSnackTone.info => Icons.info_outline_rounded,
      LotusSnackTone.success => Icons.check_circle_outline_rounded,
      LotusSnackTone.warning => Icons.error_outline_rounded,
      LotusSnackTone.error => Icons.report_gmailerrorred_rounded,
    };
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 2800),
          content: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: LotusSpace.md),
              Expanded(
                child: Text(
                  message,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

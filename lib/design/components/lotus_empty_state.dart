// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'lotus_card.dart';

/// Empty/zero state with generous whitespace and a single clear action.
class LotusEmptyState extends StatelessWidget {
  const LotusEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.local_florist_rounded,
    this.actionLabel,
    this.onAction,
    this.features = const [],
    this.gradient = true,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<(IconData, String)> features;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: LotusSpace.xxl,
          vertical: LotusSpace.xxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LotusBrandMark(size: 76, radius: 26),
              const SizedBox(height: LotusSpace.xxl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.headlineSmall,
              ),
              const SizedBox(height: LotusSpace.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: LotusSpace.xxl),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_comment_outlined, size: 19),
                  label: Text(actionLabel!),
                ),
              ],
              if (features.isNotEmpty) ...[
                const SizedBox(height: LotusSpace.xl),
                Wrap(
                  spacing: LotusSpace.sm,
                  runSpacing: LotusSpace.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final f in features)
                      LotusPill(f.$2, icon: f.$1, dense: true),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

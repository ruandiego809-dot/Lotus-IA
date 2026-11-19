// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';
import 'lotus_feedback.dart';

/// Rounded, bordered surface used across every screen.
class LotusCard extends StatelessWidget {
  const LotusCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LotusSpace.lg),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = LotusRadius.lg,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? palette.border),
    );
    final content = Padding(padding: padding, child: child);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: color ?? palette.elevated,
          shape: shape,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: onTap == null
              ? content
              : InkWell(onTap: onTap, customBorder: shape, child: content),
        ),
      ),
    );
  }
}

/// Compact label with optional leading icon.
enum LotusPillTone { neutral, primary, success, warning, danger }

/// Code block with a one-tap copy button for Markdown content.
class LotusCodeBlock extends StatelessWidget {
  const LotusCodeBlock({
    super.key,
    required this.code,
    this.language,
  });

  final String code;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (language != null && language!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(LotusSpace.md, LotusSpace.sm, LotusSpace.md, 0),
            child: Text(
              language!,
              style: context.text.labelSmall?.copyWith(
                color: palette.muted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        GestureDetector(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) {
              LotusFeedback.show(
                context,
                'Código copiado',
                tone: LotusSnackTone.success,
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(LotusSpace.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(LotusRadius.sm),
              border: Border.all(color: palette.border),
            ),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LotusPill extends StatelessWidget {
  const LotusPill(
    this.label, {
    super.key,
    this.icon,
    this.tone = LotusPillTone.neutral,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final LotusPillTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final palette = context.palette;
    final (bg, fg) = switch (tone) {
      LotusPillTone.primary => (
        scheme.primary.withValues(alpha: 0.12),
        scheme.primary,
      ),
      LotusPillTone.success => (
        palette.success.withValues(alpha: 0.14),
        palette.success,
      ),
      LotusPillTone.warning => (
        palette.warning.withValues(alpha: 0.16),
        palette.warning,
      ),
      LotusPillTone.danger => (
        scheme.error.withValues(alpha: 0.12),
        scheme.error,
      ),
      LotusPillTone.neutral => (
        scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? LotusSpace.sm : LotusSpace.md,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(LotusRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient brand mark used in the header and empty states.
class LotusBrandMark extends StatelessWidget {
  const LotusBrandMark({super.key, this.size = 36, this.radius});

  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: context.palette.brandGradient,
        borderRadius: BorderRadius.circular(radius ?? size * 0.3),
        boxShadow: [
          BoxShadow(
            color: LotusColors.primary.withValues(alpha: 0.28),
            blurRadius: size * 0.45,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.local_florist_rounded,
        size: size * 0.52,
        color: Colors.white,
      ),
    );
  }
}

class LotusSectionHeader extends StatelessWidget {
  const LotusSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(
      left: LotusSpace.xs,
      right: LotusSpace.xs,
      bottom: LotusSpace.sm,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: LotusSpace.xxs),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Esqueleto (shimmer) usado enquanto o conteúdo é carregado.
class LotusSkeleton extends StatelessWidget {
  const LotusSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = LotusRadius.xs,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(decoration: BoxDecoration(color: palette.border)),
      ),
    );
  }
}

class LotusIconBadge extends StatelessWidget {
  const LotusIconBadge({
    super.key,
    required this.icon,
    this.size = 42,
    this.color,
    this.gradient = false,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient ? context.palette.brandGradient : null,
        color: gradient ? null : tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        icon,
        size: size * 0.48,
        color: gradient ? Colors.white : tint,
      ),
    );
  }
}

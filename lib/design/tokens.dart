// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Spacing, radius, motion and layout tokens shared by every Lótus surface.
///
/// Keeping the scale in one place is what makes screens feel consistent:
/// spacing is an 4pt grid, radii stay within four sizes and motion uses a
/// single set of curves.
abstract final class LotusSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

abstract final class LotusRadius {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 30;
  static const double pill = 999;

  static BorderRadius all(double value) => BorderRadius.circular(value);
}

abstract final class LotusMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
}

abstract final class LotusBreakpoints {
  static const double compact = 700;
  static const double expanded = 1040;
  static const double chatMaxWidth = 920;
  static const double contentMaxWidth = 1080;
  static const double sheetMaxWidth = 620;
}

/// Brand palette. Values are intentionally explicit instead of generated so
/// that light and dark stay visually related.
abstract final class LotusColors {
  static const Color primary = Color(0xFF6355F2);
  static const Color primaryDeep = Color(0xFF4A3BD6);
  static const Color accent = Color(0xFF12B5A0);
  static const Color accentSoft = Color(0xFF7FE3D6);

  static const Color lightBackground = Color(0xFFF6F5FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF0EFF7);
  static const Color lightBorder = Color(0xFFE3E1EE);
  static const Color lightText = Color(0xFF14151D);
  static const Color lightMuted = Color(0xFF6C6E80);

  static const Color darkBackground = Color(0xFF08090F);
  static const Color darkSurface = Color(0xFF111320);
  static const Color darkSurfaceAlt = Color(0xFF181B2C);
  static const Color darkBorder = Color(0xFF262A42);
  static const Color darkText = Color(0xFFF3F4FA);
  static const Color darkMuted = Color(0xFF9CA0B6);

  static const Color success = Color(0xFF2FA37C);
  static const Color warning = Color(0xFFD99A2B);
  static const Color danger = Color(0xFFD9534F);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF8C6BFF), accent],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient surfaceGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1A6355F2), Color(0x0012B5A0)],
  );
}

/// Theme extension carrying the brand-specific colours that Material's
/// [ColorScheme] cannot express.
@immutable
class LotusPalette extends ThemeExtension<LotusPalette> {
  const LotusPalette({
    required this.border,
    required this.muted,
    required this.elevated,
    required this.success,
    required this.warning,
    required this.brandGradient,
    required this.userBubble,
    required this.userBubbleText,
    required this.assistantBubble,
    required this.glow,
    this.compact = false,
  });

  final Color border;
  final Color muted;
  final Color elevated;
  final Color success;
  final Color warning;
  final LinearGradient brandGradient;
  final Color userBubble;
  final Color userBubbleText;
  final Color assistantBubble;
  final Gradient glow;
  final bool compact;

  static const LotusPalette light = LotusPalette(
    border: LotusColors.lightBorder,
    muted: LotusColors.lightMuted,
    elevated: LotusColors.lightSurface,
    success: LotusColors.success,
    warning: LotusColors.warning,
    brandGradient: LotusColors.brandGradient,
    userBubble: Color(0xFFE9E6FF),
    userBubbleText: Color(0xFF241B57),
    assistantBubble: Color(0xFFF3F2F9),
    glow: LotusColors.surfaceGlow,
    compact: false,
  );

  static const LotusPalette dark = LotusPalette(
    border: LotusColors.darkBorder,
    muted: LotusColors.darkMuted,
    elevated: LotusColors.darkSurfaceAlt,
    success: Color(0xFF4BD3A6),
    warning: Color(0xFFF0B54B),
    brandGradient: LotusColors.brandGradient,
    userBubble: Color(0xFF2A2650),
    userBubbleText: Color(0xFFEDEAFF),
    assistantBubble: Color(0xFF151829),
    glow: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x248C7DFF), Color(0x0012B5A0)],
    ),
    compact: false,
  );

  @override
  LotusPalette copyWith({
    Color? border,
    Color? muted,
    Color? elevated,
    Color? success,
    Color? warning,
    LinearGradient? brandGradient,
    Color? userBubble,
    Color? userBubbleText,
    Color? assistantBubble,
    Gradient? glow,
    bool? compact,
  }) {
    return LotusPalette(
      border: border ?? this.border,
      muted: muted ?? this.muted,
      elevated: elevated ?? this.elevated,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      brandGradient: brandGradient ?? this.brandGradient,
      userBubble: userBubble ?? this.userBubble,
      userBubbleText: userBubbleText ?? this.userBubbleText,
      assistantBubble: assistantBubble ?? this.assistantBubble,
      glow: glow ?? this.glow,
      compact: compact ?? this.compact,
    );
  }

  @override
  LotusPalette lerp(covariant ThemeExtension<LotusPalette>? other, double t) {
    if (other is! LotusPalette) return this;
    return LotusPalette(
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      brandGradient: LinearGradient.lerp(
        brandGradient,
        other.brandGradient,
        t,
      )!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      userBubbleText: Color.lerp(userBubbleText, other.userBubbleText, t)!,
      assistantBubble: Color.lerp(assistantBubble, other.assistantBubble, t)!,
      glow: Gradient.lerp(glow, other.glow, t)!,
      compact: t >= 0.5 ? other.compact : compact,
    );
  }
}

extension LotusPaletteContext on BuildContext {
  LotusPalette get palette =>
      Theme.of(this).extension<LotusPalette>() ?? LotusPalette.light;

  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizations('pt');
}

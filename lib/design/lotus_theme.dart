// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Single source of truth for the Lótus look. Every screen consumes this
/// theme (directly or through the design-system widgets), so visual changes
/// happen in one place.
abstract final class LotusTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final palette = dark ? LotusPalette.dark : LotusPalette.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: LotusColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFF8C7DFF) : LotusColors.primary,
          onPrimary: Colors.white,
          primaryContainer: dark
              ? const Color(0xFF2A2650)
              : const Color(0xFFE9E6FF),
          onPrimaryContainer: dark
              ? const Color(0xFFEDEAFF)
              : const Color(0xFF241B57),
          secondary: dark ? const Color(0xFF35D0B8) : LotusColors.accent,
          onSecondary: dark ? const Color(0xFF04211C) : Colors.white,
          secondaryContainer: dark
              ? const Color(0xFF123430)
              : const Color(0xFFD9F6F0),
          onSecondaryContainer: dark
              ? const Color(0xFFB9F2E8)
              : const Color(0xFF063F37),
          surface: dark ? LotusColors.darkSurface : LotusColors.lightSurface,
          onSurface: dark ? LotusColors.darkText : LotusColors.lightText,
          surfaceContainerHighest: dark
              ? LotusColors.darkSurfaceAlt
              : LotusColors.lightSurfaceAlt,
          outline: dark ? const Color(0xFF3A3F5C) : const Color(0xFFC9C6DA),
          outlineVariant: palette.border,
          error: dark ? const Color(0xFFFF8A80) : LotusColors.danger,
          surfaceTint: Colors.transparent,
        );

    final textTheme = _textTheme(dark);
    final background = dark
        ? LotusColors.darkBackground
        : LotusColors.lightBackground;

    BorderRadius radius(double value) => BorderRadius.circular(value);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      primaryColor: scheme.primary,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: LotusSpace.lg,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        titleTextStyle: textTheme.titleLarge,
        toolbarHeight: 64,
      ),
      cardTheme: CardThemeData(
        color: palette.elevated,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius(LotusRadius.lg),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LotusSpace.lg,
          vertical: LotusSpace.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius(LotusRadius.sm)),
        minVerticalPadding: LotusSpace.md,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? LotusColors.darkSurfaceAlt : Colors.white,
        isDense: false,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: palette.muted.withValues(alpha: 0.8),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: palette.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LotusSpace.lg,
          vertical: LotusSpace.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: radius(LotusRadius.sm),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius(LotusRadius.sm),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius(LotusRadius.sm),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius(LotusRadius.sm),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius(LotusRadius.sm),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: LotusSpace.xl,
            vertical: LotusSpace.md + 2,
          ),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radius(LotusRadius.sm)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          padding: const EdgeInsets.symmetric(
            horizontal: LotusSpace.xl,
            vertical: LotusSpace.md + 2,
          ),
          side: BorderSide(color: palette.border),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radius(LotusRadius.sm)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: LotusSpace.lg,
            vertical: LotusSpace.sm,
          ),
          shape: RoundedRectangleBorder(borderRadius: radius(LotusRadius.xs)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: radius(LotusRadius.xs)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? LotusColors.darkSurfaceAlt : Colors.white,
        side: BorderSide(color: palette.border),
        labelStyle: textTheme.labelSmall?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelSmall,
        padding: const EdgeInsets.symmetric(
          horizontal: LotusSpace.sm,
          vertical: LotusSpace.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius(LotusRadius.pill)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? LotusColors.darkSurfaceAlt
            : const Color(0xFF1B1C26),
        contentTextStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        insetPadding: const EdgeInsets.fromLTRB(
          LotusSpace.lg,
          0,
          LotusSpace.lg,
          LotusSpace.lg,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius(LotusRadius.sm)),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: radius(LotusRadius.xl)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.elevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.elevated,
        showDragHandle: true,
        dragHandleColor: palette.border,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LotusRadius.xl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius(LotusRadius.sm)),
        textStyle: textTheme.bodyMedium,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: palette.border,
        circularTrackColor: palette.border,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2A2E44) : const Color(0xFF23242F),
          borderRadius: radius(LotusRadius.xs),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: Colors.white),
        waitDuration: const Duration(milliseconds: 450),
      ),
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
    );
  }

  static TextTheme _textTheme(bool dark) {
    final color = dark ? LotusColors.darkText : LotusColors.lightText;
    final muted = dark ? LotusColors.darkMuted : LotusColors.lightMuted;
    TextStyle style(
      double size,
      FontWeight weight, {
      double height = 1.35,
      double spacing = -0.2,
      Color? tone,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: tone ?? color,
    );

    return TextTheme(
      displaySmall: style(34, FontWeight.w800, height: 1.15, spacing: -0.8),
      headlineMedium: style(28, FontWeight.w800, height: 1.18, spacing: -0.6),
      headlineSmall: style(24, FontWeight.w700, height: 1.2, spacing: -0.5),
      titleLarge: style(20, FontWeight.w700, height: 1.25, spacing: -0.3),
      titleMedium: style(16, FontWeight.w700, height: 1.3, spacing: -0.2),
      titleSmall: style(14, FontWeight.w700, height: 1.3, spacing: -0.1),
      bodyLarge: style(16, FontWeight.w400, height: 1.5, spacing: -0.1),
      bodyMedium: style(14, FontWeight.w400, height: 1.5, spacing: 0),
      bodySmall: style(
        12,
        FontWeight.w400,
        height: 1.45,
        spacing: 0.1,
        tone: muted,
      ),
      labelLarge: style(14, FontWeight.w600, height: 1.25, spacing: 0),
      labelMedium: style(
        12,
        FontWeight.w600,
        height: 1.25,
        spacing: 0.1,
        tone: muted,
      ),
      labelSmall: style(
        11,
        FontWeight.w600,
        height: 1.25,
        spacing: 0.2,
        tone: muted,
      ),
    );
  }
}

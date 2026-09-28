import 'package:flutter/material.dart';
import 'app_colors_ext.dart';
import 'app_palette.dart';

class AppTheme {
  static ThemeData build(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primaryContainer,
      onPrimaryContainer: p.onPrimaryContainer,
      secondary: p.secondary,
      onSecondary: p.onPrimary,
      secondaryContainer: p.secondaryContainer,
      onSecondaryContainer: p.onSecondaryContainer,
      error: p.error,
      onError: p.onPrimary,
      surface: p.surface,
      onSurface: p.onSurface,
      onSurfaceVariant: p.onSurfaceMuted,
      outline: p.outline,
      outlineVariant: p.outline.withAlpha(90),
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surfaceContainer,
      surfaceContainerHigh: p.surfaceContainer,
      surfaceContainerHighest: p.surfaceContainer,
    );

    final radius = BorderRadius.circular(14);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: radius, borderSide: BorderSide(color: c, width: w));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      extensions: [AppColorsExt.from(p)],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.outline.withAlpha(70)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: border(p.outline.withAlpha(120)),
        enabledBorder: border(p.outline.withAlpha(120)),
        focusedBorder: border(p.primary, 2),
        errorBorder: border(p.error),
        focusedErrorBorder: border(p.error, 2),
        prefixIconColor: p.onSurfaceMuted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.primary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        elevation: 0,
        indicatorColor: p.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected)
                  ? p.onPrimaryContainer
                  : p.onSurfaceMuted,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: s.contains(WidgetState.selected)
                  ? p.primary
                  : p.onSurfaceMuted,
            )),
      ),
      listTileTheme: ListTileThemeData(iconColor: p.primary),
    );
  }

  static final light = build(AppPalette.light, Brightness.light);
  static final dark = build(AppPalette.dark, Brightness.dark);
}

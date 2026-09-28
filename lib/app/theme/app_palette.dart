import 'package:flutter/material.dart';

/// ÚNICO archivo donde se escriben valores de color.
/// Negro + verde. El modo oscuro usa gris verdoso (no negro puro) para que no sea tan cerrado.
class AppPalette {
  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.outline,
    required this.error,
    required this.success,
    required this.warning,
    required this.streak,
  });

  final Color primary, onPrimary, primaryContainer, onPrimaryContainer;
  final Color secondary, secondaryContainer, onSecondaryContainer;
  final Color background, surface, surfaceContainer;
  final Color onSurface, onSurfaceMuted, outline;
  final Color error, success, warning;
  final Color streak;

  static const light = AppPalette(
    primary: Color(0xFF15803D),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFBBF7D0),
    onPrimaryContainer: Color(0xFF052E16),
    secondary: Color(0xFF1E2723), // el "negro" de la marca
    secondaryContainer: Color(0xFFDDE7E1),
    onSecondaryContainer: Color(0xFF1E2723),
    background: Color(0xFFF2F7F3),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFE4EEE7),
    onSurface: Color(0xFF111814),
    onSurfaceMuted: Color(0xFF4F5F56),
    outline: Color(0xFF8DA396),
    error: Color(0xFFB3261E),
    success: Color(0xFF15803D),
    warning: Color(0xFFD97706),
    streak: Color(0xFFFF7A3D),
  );

  static const dark = AppPalette(
    primary: Color(0xFF4ADE80),
    onPrimary: Color(0xFF06301A),
    primaryContainer: Color(0xFF1F6B3F),
    onPrimaryContainer: Color(0xFFC9F7DA),
    secondary: Color(0xFFA3E635),
    secondaryContainer: Color(0xFF405228),
    onSecondaryContainer: Color(0xFFE3F7B8),
    background: Color(0xFF1C2320), // gris verdoso, más claro que el negro
    surface: Color(0xFF27302B),
    surfaceContainer: Color(0xFF323D37),
    onSurface: Color(0xFFEAF2EC),
    onSurfaceMuted: Color(0xFFA7B8AE),
    outline: Color(0xFF6E8177),
    error: Color(0xFFF2B8B5),
    success: Color(0xFF86EFAC),
    warning: Color(0xFFFBBF24),
    streak: Color(0xFFFF8A5B),
  );
}

import 'package:flutter/material.dart';
import 'app_palette.dart';

class AppColorsExt extends ThemeExtension<AppColorsExt> {
  const AppColorsExt({required this.success, required this.warning, required this.streak});

  final Color success, warning, streak;

  factory AppColorsExt.from(AppPalette p) =>
      AppColorsExt(success: p.success, warning: p.warning, streak: p.streak);

  @override
  AppColorsExt copyWith({Color? success, Color? warning, Color? streak}) => AppColorsExt(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        streak: streak ?? this.streak,
      );

  @override
  AppColorsExt lerp(AppColorsExt? other, double t) => other == null
      ? this
      : AppColorsExt(
          success: Color.lerp(success, other.success, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
          streak: Color.lerp(streak, other.streak, t)!,
        );
}

extension AppColorsContext on BuildContext {
  AppColorsExt get appColors => Theme.of(this).extension<AppColorsExt>()!;
}

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// iPick 앱 테마. DESIGN.md 토큰을 Material [ThemeData]로 묶는다.
///
/// 이 앱은 밝은(light) UI에 커밋한다 (DESIGN.md canvas #FFFFFF). 다크 테마는 후속.
abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary, // 틸 위 진한 텍스트 (흰색 금지)
      surface: AppColors.canvas,
      onSurface: AppColors.foreground,
      error: AppColors.danger,
      outline: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: AppTextStyles.fontFamily,
      textTheme: const TextTheme(
        headlineMedium: AppTextStyles.h1,
        titleLarge: AppTextStyles.h2,
        titleMedium: AppTextStyles.h3,
        titleSmall: AppTextStyles.h4,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.bodySmall,
        labelSmall: AppTextStyles.caption,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.foreground,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      // 기본 primary 버튼: 틸 채움 + 진한 틸 텍스트
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(52),
          textStyle: AppTextStyles.h4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
    );
  }
}

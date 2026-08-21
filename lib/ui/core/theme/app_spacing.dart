import 'package:flutter/cupertino.dart';

/// 간격·라운드 토큰. `docs/design/DESIGN.md`에서 옮김 (8pt 계열).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// 모서리 둥글기 토큰.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double card = 16;
  static const double button = 12;
  static const double pill = 999;
}

/// 위젯 사이 여백. `SizedBox(height/width: AppSpacing.x)`를 앱 전역에서
/// 이 이름으로 통일해 쓴다.
abstract final class AppGap {
  /// Vertical
  static const SizedBox vXs = SizedBox(height: AppSpacing.xs);
  static const SizedBox vSm = SizedBox(height: AppSpacing.sm);
  static const SizedBox vMd = SizedBox(height: AppSpacing.md);
  static const SizedBox vLg = SizedBox(height: AppSpacing.lg);
  static const SizedBox vXl = SizedBox(height: AppSpacing.xl);
  static const SizedBox vXxl = SizedBox(height: AppSpacing.xxl);

  /// Horizontal
  static const SizedBox hXs = SizedBox(width: AppSpacing.xs);
  static const SizedBox hSm = SizedBox(width: AppSpacing.sm);
  static const SizedBox hMd = SizedBox(width: AppSpacing.md);
  static const SizedBox hLg = SizedBox(width: AppSpacing.lg);
  static const SizedBox hXl = SizedBox(width: AppSpacing.xl);
  static const SizedBox hXxl = SizedBox(width: AppSpacing.xxl);
}

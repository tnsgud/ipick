import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 타이포 토큰. `docs/design/DESIGN.md`의 타입 스케일을 옮김.
abstract final class AppTextStyles {
  static const String? fontFamily = 'Pretendard';

  // height = 행간(px) / 폰트크기(px)
  static const h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 32 / 24,
    color: AppColors.foreground,
  );
  static const h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 28 / 20,
    color: AppColors.foreground,
  );
  static const h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 26 / 18,
    color: AppColors.foreground,
  );
  static const h4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
    color: AppColors.foreground,
  );
  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
    color: AppColors.body,
  );
  static const bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 19 / 13,
    color: AppColors.body,
  );
  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    color: AppColors.muted,
  );
}

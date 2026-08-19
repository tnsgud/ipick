import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 타이포 토큰. `docs/design/DESIGN.md`의 타입 스케일을 옮김.
///
/// 폰트: DESIGN.md는 Pretendard(오픈소스)를 지정한다. 아직 폰트 에셋을 번들하지
/// 않아 시스템 폰트로 폴백된다. Pretendard를 쓰려면 pubspec의 fonts에 등록하고
/// 아래 [fontFamily]를 활성화하면 된다. (로직 문서 §타이포 참고)
abstract final class AppTextStyles {
  static const String? fontFamily = null; // TODO: 'Pretendard' (에셋 등록 후)

  // height = 행간(px) / 폰트크기(px)
  static const h1 = TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w700, height: 32 / 24, color: AppColors.foreground);
  static const h2 = TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w700, height: 28 / 20, color: AppColors.foreground);
  static const h3 = TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w600, height: 26 / 18, color: AppColors.foreground);
  static const h4 = TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600, height: 24 / 16, color: AppColors.foreground);
  static const body = TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w400, height: 22 / 15, color: AppColors.body);
  static const bodySmall = TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w400, height: 19 / 13, color: AppColors.body);
  static const caption = TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, height: 16 / 12, color: AppColors.muted);
}

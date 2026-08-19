import 'package:flutter/material.dart';

/// iPick 색상 토큰. `docs/design/DESIGN.md`(Primary 틸 #39C5BB 확정본)에서 옮김.
///
/// 틸은 밝은 색이라 흰 텍스트 대비가 부족하다. 그래서 두 역할을 분리한다:
/// - [onPrimary] : 틸 채움 위 텍스트 (진한 틸)
/// - [primaryInk]: 흰 배경 위 브랜드 텍스트/아이콘 (워드마크·활성 탭·칩 텍스트)
abstract final class AppColors {
  // 브랜드 · 액션
  static const primary = Color(0xFF39C5BB); // 채움(버튼·인디케이터)
  static const primaryHover = Color(0xFF1FAEA4);
  static const primaryPressed = Color(0xFF159A90);
  static const primaryInk = Color(0xFF12897E); // 흰 배경 위 브랜드 텍스트
  static const onPrimary = Color(0xFF063D38); // 틸 채움 위 텍스트 (흰색 금지)

  // 뉴트럴 (틸 기미)
  static const canvas = Color(0xFFFFFFFF);
  static const foreground = Color(0xFF14201E);
  static const body = Color(0xFF465350);
  static const muted = Color(0xFF869390);
  static const surface = Color(0xFFF2F6F5);
  static const border = Color(0xFFE0EAE8);

  // 약한 틸 (틴트 배경 + 진한 텍스트)
  static const weakBackground = Color(0xFFE2F6F3);
  static const weakForeground = Color(0xFF12897E);

  // 시맨틱 (상태)
  static const success = Color(0xFF1FA971);
  static const warning = Color(0xFFF5A524);
  static const danger = Color(0xFFE5484D);
  static const info = Color(0xFF3B5BDB); // 틸과 구분되도록 인디고
  static const highlight = Color(0xFF8B5CF6);
}

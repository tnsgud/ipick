import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// iPick 워드마크. 'i'는 브랜드 틸(흰 배경용 진한 틸 = primaryInk), 'Pick'은 전경색.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.fontSize = 20});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, letterSpacing: -0.5);
    return RichText(
      text: TextSpan(
        style: base,
        children: const [
          TextSpan(text: 'i', style: TextStyle(color: AppColors.primaryInk)),
          TextSpan(text: 'Pick', style: TextStyle(color: AppColors.foreground)),
        ],
      ),
    );
  }
}

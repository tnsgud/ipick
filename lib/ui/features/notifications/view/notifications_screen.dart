import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// 알림 화면 (디자인 골격). 실제 알림 목록·읽음 처리는 후속 + FCM 연동은 님이 구현.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림', style: AppTextStyles.h2), titleSpacing: AppSpacing.lg),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppColors.weakBackground, shape: BoxShape.circle),
                child: const Icon(Icons.notifications_none_rounded, color: AppColors.primaryInk, size: 30),
              ),
              AppGap.vLg,
              const Text('새 알림이 여기 모여요', style: AppTextStyles.h4),
              AppGap.vXs,
              const Text(
                '구독한 IP의 발매·예약 소식이 뜨면\n푸시로 알려드릴게요.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

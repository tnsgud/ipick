import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// MY 화면 (디자인 골격). 실제 인증·프로필·알림설정은 로직 문서 §인증 참고.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MY', style: AppTextStyles.h2), titleSpacing: AppSpacing.lg),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, color: AppColors.muted, size: 30),
              ),
              AppGap.hMd,
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('로그인하기', style: AppTextStyles.h3),
                  SizedBox(height: 2),
                  Text('구독을 기기 간에 동기화하세요', style: AppTextStyles.bodySmall),
                ],
              ),
            ],
          ),
          AppGap.vXl,
          _row(Icons.notifications_active_outlined, '알림 설정'),
          _row(Icons.tune_rounded, '피드 취향 관리'),
          _row(Icons.info_outline_rounded, '앱 정보'),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.body),
        title: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.foreground)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        onTap: () {},
      );
}

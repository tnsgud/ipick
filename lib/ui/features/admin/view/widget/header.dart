import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ipick/ui/core/theme/app_colors.dart';
import 'package:ipick/ui/core/theme/app_spacing.dart';
import 'package:ipick/ui/core/theme/app_text_styles.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsGeometry.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: BoxBorder.fromLTRB(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('관리자', style: AppTextStyles.h2),
                AppGap.hSm,
                Text(
                  'iPick 콘솔',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryInk,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.replace('/admin/login'),
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                border: BoxBorder.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(
                child: Text(
                  '로그아웃',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

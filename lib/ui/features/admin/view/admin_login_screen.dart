import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ipick/ui/core/theme/app_colors.dart';
import 'package:ipick/ui/core/theme/app_spacing.dart';
import 'package:ipick/ui/core/theme/app_text_styles.dart';
import 'package:ipick/ui/core/widgets/ipick_chip.dart';

import 'widget/input.dart';

class AdminLoginScreen extends StatelessWidget {
  AdminLoginScreen({super.key});

  final TextEditingController _emailController = TextEditingController(),
      _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: AppSpacing.xxl,
                  height: AppSpacing.xxl,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: Text(
                      "i",
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                AppGap.hSm,
                Text(
                  'iPick',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.weakForeground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                AppGap.hSm,
                IPickChip(label: 'ADMIN', selected: true),
              ],
            ),
            AppGap.vSm,
            Text('관리자 콘솔', style: AppTextStyles.h1),
            AppGap.vSm,
            Text('카테고리·IP·소스를 SQL 없이 관리합니다.'),
            AppGap.vSm,
            Input(label: '이메일', controller: _emailController),
            AppGap.vSm,
            Input(label: '비밀번호', controller: _passwordController),
            AppGap.vSm,
            FilledButton(
              onPressed: () => context.replace('/admin/home'),
              child: Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}

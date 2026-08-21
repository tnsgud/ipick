import 'package:flutter/material.dart';
import 'package:ipick/ui/core/theme/app_colors.dart';
import 'package:ipick/ui/core/theme/app_spacing.dart';
import 'package:ipick/ui/core/theme/app_text_styles.dart';

class Input extends StatelessWidget {
  const Input({super.key, required this._controller, required this.label});

  final TextEditingController _controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        AppGap.vXs,
        TextField(
          controller: _controller,
          style: AppTextStyles.body.copyWith(color: AppColors.foreground),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ],
    );
  }
}

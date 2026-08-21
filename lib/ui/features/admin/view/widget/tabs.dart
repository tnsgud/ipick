import 'package:flutter/material.dart';
import 'package:ipick/ui/core/theme/app_colors.dart';
import 'package:ipick/ui/core/theme/app_spacing.dart';
import 'package:ipick/ui/core/theme/app_text_styles.dart';

class Tabs extends StatefulWidget {
  const Tabs({super.key});

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  int _index = 0;

  List<(String, int)> _data = [('카테고리', 3), ('IP', 4), ('소스', 5), ('피드', 5)];

  void _changeIndex(int index) {
    setState(() {
      _index = index;
    });
  }

  Widget _generateTab(String label, int count, int index) {
    var isSelected = _index == index;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        AppGap.hXs,
        Container(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.weakBackground : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$count',
            style: AppTextStyles.caption.copyWith(
              color: isSelected ? AppColors.weakForeground : AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TabBar(
      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.primaryInk,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.bold,
      ),
      onTap: (index) => _changeIndex(index),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: AppColors.border,
      labelPadding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      tabs: _data.indexed
          .map((pair) => _generateTab(pair.$2.$1, pair.$2.$2, pair.$1))
          .toList(),
    );
  }
}

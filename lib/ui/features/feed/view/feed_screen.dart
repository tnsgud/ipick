import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipick/domain/models/feed_item.dart';
import 'package:ipick/ui/features/feed/view_model/feed_view_model.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_wordmark.dart';
import '../../../core/widgets/goods_feed_card.dart';
import '../../../core/widgets/ipick_chip.dart';

/// 통합 피드 화면. 내가 구독한 IP들의 발매·굿즈·소식이 한 타임라인으로 모인다.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  static const _filters = ['전체', '발매·굿즈', '소식'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedViewModel);
    final feeds = state.visible;
    final filter = state.filter;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: const AppWordmark(),
        actions: [
          _NotificationBell(onTap: () {}),
          AppGap.hSm,
        ],
      ),
      body: Column(
        children: [
          // 검색
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: _SearchField(),
          ),
          // 필터 칩
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (_, i) => IPickChip(
                label: _filters[i],
                selected: filter == i,
                onTap: () => ref.read(feedViewModel.notifier).setFilter(i),
              ),
            ),
          ),
          AppGap.vMd,
          // 피드 리스트
          Expanded(
            child: _FeedBody(
              feeds: feeds,
              isLoading: state.isLoading,
              errorMessage: state.errorMessage,
              onRetry: () => ref.read(feedViewModel.notifier).load(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 피드 본문. 로딩·오류·빈 목록·정상 네 가지 상태를 그린다.
class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.feeds,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final List<FeedItem> feeds;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading && feeds.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null && feeds.isEmpty) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: errorMessage!,
        action: TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      );
    }

    if (feeds.isEmpty) {
      return const _Message(
        icon: Icons.inbox_rounded,
        title: '아직 소식이 없어요',
        description: '구독한 IP에 새 소식이 올라오면 여기에 모아드릴게요.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: feeds.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm + 2),
      itemBuilder: (_, i) => GoodsFeedCard(item: feeds[i], onAction: () {}),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.weakBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryInk, size: 28),
            ),
            AppGap.vLg,
            Text(title, textAlign: TextAlign.center, style: AppTextStyles.h4),
            if (description != null) ...[
              AppGap.vXs,
              Text(
                description!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
            if (action != null) ...[AppGap.vSm, action!],
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
          AppGap.hSm,
          Text(
            '굿즈 · IP 검색',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.weakBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 19,
              color: AppColors.primaryInk,
            ),
          ),
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.canvas, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

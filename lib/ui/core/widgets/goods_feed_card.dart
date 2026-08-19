import 'package:flutter/material.dart';
import '../../../domain/models/feed_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'goods_thumbnail.dart';
import 'status_badge.dart';

/// 통합 피드의 기본 단위. 썸네일 + 출처/시간 + 굿즈명 + 상태 뱃지 + 구매/예약 버튼.
/// 이미지가 주역이 되도록 텍스트는 절제한다.
class GoodsFeedCard extends StatelessWidget {
  const GoodsFeedCard({super.key, required this.item, this.onAction});

  final FeedItem item;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(color: Color(0x0F141F1E), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GoodsThumbnail(seed: item.thumbnailSeed, isVideo: item.isVideo),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 출처 · 시간
                Row(
                  children: [
                    Flexible(
                      child: Text('${item.ipName} · ${item.sourceName}',
                          overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
                    ),
                    Text('  ${item.timeAgo}', style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 3),
                // 굿즈명
                Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h4.copyWith(fontSize: 14, height: 1.35)),
                const SizedBox(height: 6),
                // 상태 뱃지
                if (item.badges.isNotEmpty)
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [for (final b in item.badges) StatusBadge(b)],
                  ),
                const SizedBox(height: 8),
                // 가격 + 액션
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 가격이 있으면 가격, 영상이면 "영상", 그 외(일반 소식)엔 아무것도
                    // 쓰지 않는다. 예전엔 가격이 없으면 무조건 "영상"이라 실제 뉴스가
                    // 전부 영상으로 표시됐다.
                    if (item.priceLabel != null)
                      Text(
                        item.priceLabel!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      )
                    else if (item.isVideo)
                      Text(
                        '영상',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    _ActionButton(label: item.actionLabel, onTap: onAction),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드 내 소형 액션 버튼 (틸 채움 + 진한 틸 텍스트).
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onPrimary, // 틸 위 진한 텍스트
            ),
          ),
        ),
      ),
    );
  }
}

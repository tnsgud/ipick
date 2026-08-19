import 'package:flutter/material.dart';
import '../../../../domain/models/ip.dart';
import '../../../../mock/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/goods_thumbnail.dart';

/// 구독 화면. IP를 둘러보고 구독/해제한다.
///
/// [디자인 전용] 구독 토글 상태만 로컬로 관리한다. 실제 구독 저장(upsert/delete)은
/// 로직 문서 §구독의 SubscriptionRepository로 붙인다.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  late final List<Ip> _ips = List.of(MockData.subscriptions);

  void _toggle(int i) => setState(() => _ips[i] = _ips[i].copyWith(subscribed: !_ips[i].subscribed));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('구독', style: AppTextStyles.h2), titleSpacing: AppSpacing.lg),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.92,
        ),
        itemCount: _ips.length,
        itemBuilder: (_, i) => _IpCard(ip: _ips[i], onToggle: () => _toggle(i)),
      ),
    );
  }
}

class _IpCard extends StatelessWidget {
  const _IpCard({required this.ip, required this.onToggle});
  final Ip ip;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: GoodsThumbnail(seed: ip.thumbnailSeed, size: 72)),
          const SizedBox(height: AppSpacing.md),
          Text(ip.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.h4),
          Text(ip.category, style: AppTextStyles.caption),
          const Spacer(),
          _SubscribeButton(subscribed: ip.subscribed, onTap: onToggle),
        ],
      ),
    );
  }
}

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({required this.subscribed, required this.onTap});
  final bool subscribed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: subscribed ? AppColors.weakBackground : AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              subscribed ? '구독중' : '구독하기',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: subscribed ? AppColors.weakForeground : AppColors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

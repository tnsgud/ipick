import 'package:flutter/material.dart';
import '../../../domain/models/badge_kind.dart';
import '../theme/app_spacing.dart';

/// 상태 라벨 뱃지 (발매/예약중/한정/임박/품절/소식).
/// 설명용이며 클릭 액션이 아니다. 색은 DESIGN.md §Badge 표에서 옮김.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.kind, {super.key});

  final BadgeKind kind;

  static const _spec = <BadgeKind, (_C, String)>{
    BadgeKind.release: (_C(Color(0xFFE2F6F3), Color(0xFF12897E)), '발매'),
    BadgeKind.reserving: (_C(Color(0xFFE8F1FF), Color(0xFF3B5BDB)), '예약중'),
    BadgeKind.limited: (_C(Color(0xFFF1EAFE), Color(0xFF6D3BE0)), '한정'),
    BadgeKind.closingSoon: (_C(Color(0xFFFFF3E0), Color(0xFFC77A00)), '임박'),
    BadgeKind.soldOut: (_C(Color(0xFFEEF0F0), Color(0xFF64706D)), '품절'),
    BadgeKind.news: (_C(Color(0xFFEEF0F0), Color(0xFF64706D)), '소식'),
  };

  @override
  Widget build(BuildContext context) {
    final (colors, label) = _spec[kind]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.fg, height: 1.2),
      ),
    );
  }
}

class _C {
  const _C(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

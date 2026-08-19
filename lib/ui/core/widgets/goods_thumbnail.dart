import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// 굿즈 썸네일 자리표시자. 실제로는 상품 이미지가 들어갈 자리 —
/// 디자인 단계에서는 seed로 변주한 그라데이션으로 대체한다.
class GoodsThumbnail extends StatelessWidget {
  const GoodsThumbnail({super.key, this.seed = 0, this.size = 66, this.isVideo = false});

  final int seed;
  final double size;
  final bool isVideo;

  static const _gradients = <List<Color>>[
    [Color(0xFF2C2735), Color(0xFF4B3752)],
    [Color(0xFFECDCC2), Color(0xFFCBA871)],
    [Color(0xFF2E9E96), Color(0xFF7FD8D0)],
    [Color(0xFF241F2E), Color(0xFF3B2F4B)],
    [Color(0xFF3D5B79), Color(0xFF83ACCB)],
    [Color(0xFF6D3BE0), Color(0xFFB79BF2)],
    [Color(0xFFF06AA0), Color(0xFFF9C3D9)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[seed % _gradients.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: isVideo
          ? const Center(
              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            )
          : null,
    );
  }
}

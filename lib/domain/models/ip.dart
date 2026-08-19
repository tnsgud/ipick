/// 팬덤 대상 IP (UI 표시용 모델). DB의 `ips` 행과 대응.
class Ip {
  const Ip({
    required this.id,
    required this.name,
    required this.category,
    this.subscribed = false,
    this.thumbnailSeed = 0,
  });

  final String id;
  final String name; // 예: 귀멸의 칼날
  final String category; // 예: 애니메
  final bool subscribed;
  final int thumbnailSeed;

  Ip copyWith({bool? subscribed}) => Ip(
        id: id,
        name: name,
        category: category,
        subscribed: subscribed ?? this.subscribed,
        thumbnailSeed: thumbnailSeed,
      );
}

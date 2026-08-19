import 'badge_kind.dart';

/// 통합 피드의 한 항목 (UI 표시용 모델).
///
/// DB의 `feed_items` 행과 대응한다. Repository가 DB 행을 이 모델로 변환한다
/// (로직 문서 §데이터 레이어 참고).
class FeedItem {
  const FeedItem({
    required this.id,
    required this.ipName,
    required this.sourceName,
    required this.timeAgo,
    required this.title,
    this.badges = const [],
    this.priceLabel,
    required this.actionLabel,
    this.thumbnailSeed = 0,
    this.isVideo = false,
    this.isGoods = false,
  });

  final String id;
  final String ipName; // 예: 귀멸의 칼날
  final String sourceName; // 예: 공식 스토어 / 굿스마일 / 공식 유튜브
  final String timeAgo; // 예: "방금", "12분 전" (표시용 문자열)
  final String title; // 굿즈명/소식 제목
  final List<BadgeKind> badges;
  final String? priceLabel; // 예: "₩18,000" (없으면 null → "영상" 등)
  final String actionLabel; // 예: 예약하기 / 구매하기 / 보기
  final int thumbnailSeed; // 목업 썸네일 색 변주용
  final bool isVideo; // 영상 항목이면 썸네일에 재생 아이콘

  /// 발매·굿즈 항목인지(= 살 수 있거나 발매 공지인지). 피드 필터의 기준이 된다.
  /// 이게 아니면 일반 "소식"으로 분류한다.
  final bool isGoods;

  static List<BadgeKind> _badgesFrom(Map<String, dynamic> row) {
    var list = <BadgeKind>[];

    if (row['item_type'] == 'release') list.add(BadgeKind.release);
    if (row['buy_url'] != null) list.add(BadgeKind.closingSoon);

    return list;
  }

  static String _relativeTime(DateTime dateTime) {
    var diff = DateTime.now().difference(dateTime);

    if (diff <= Duration(minutes: 1)) {
      return '방금';
    }

    if (diff < Duration(hours: 1)) {
      return '${diff.inMinutes}분 전';
    }

    if (diff < Duration(days: 1)) {
      return '${diff.inHours}시간 전';
    }

    return '${diff.inDays}일 전';
  }

  /// 원문 링크의 호스트를 출처로 쓴다 (예: "news.ycombinator.com").
  ///
  /// `sources` 테이블에 표시용 이름 컬럼이 없고, RLS상 익명 사용자는 sources를
  /// 조회할 수 없어 조인으로 가져올 수도 없다. 관리자 페이지에서 소스에 표시
  /// 이름을 붙일 수 있게 되면 그 값으로 교체하는 게 좋다.
  static String _sourceNameFrom(String? url) {
    if (url == null || url.isEmpty) return '';
    final host = Uri.tryParse(url)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  /// 영상 항목인지 판별한다. 지금은 링크가 영상 플랫폼인지로 추정한다.
  static bool _isVideoFrom(String? url) {
    if (url == null) return false;
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('vimeo.com');
  }

  factory FeedItem.fromRow(Map<String, dynamic> row) {
    final url = row['url'] as String?;

    return FeedItem(
      id: row['id'] as String,
      ipName: (row['ips']?['name'] ?? '') as String,
      sourceName: _sourceNameFrom(url),
      timeAgo: _relativeTime(DateTime.parse(row['published_at'] as String)),
      title: row['title'] as String,
      badges: _badgesFrom(row),
      actionLabel: (row['buy_url'] != null) ? '구매하기' : '보기',
      isVideo: _isVideoFrom(url),
      isGoods: row['buy_url'] != null || row['item_type'] == 'release',
    );
  }
}

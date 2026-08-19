import '../domain/models/badge_kind.dart';
import '../domain/models/feed_item.dart';
import '../domain/models/ip.dart';

/// 디자인/미리보기용 목업 데이터. 실제 연동 시 Repository가 대체한다.
abstract final class MockData {
  static const feed = <FeedItem>[
    FeedItem(
      id: '1',
      ipName: '귀멸의 칼날',
      sourceName: '공식 스토어',
      timeAgo: '방금',
      title: '「무한성편」 극장판 아크릴 스탠드 6종',
      badges: [BadgeKind.release],
      priceLabel: '₩18,000',
      actionLabel: '예약하기',
      thumbnailSeed: 0,
    ),
    FeedItem(
      id: '2',
      ipName: '귀멸의 칼날',
      sourceName: '굿스마일',
      timeAgo: '12분 전',
      title: '탄지로 넨도로이드 재판',
      badges: [BadgeKind.reserving, BadgeKind.closingSoon],
      priceLabel: '₩68,000',
      actionLabel: '예약하기',
      thumbnailSeed: 1,
    ),
    FeedItem(
      id: '3',
      ipName: '하츠네 미쿠',
      sourceName: 'aniplex+',
      timeAgo: '1시간 전',
      title: '미쿠 15th 1/7 스케일 피규어',
      badges: [BadgeKind.limited],
      priceLabel: '₩250,000',
      actionLabel: '구매하기',
      thumbnailSeed: 2,
    ),
    FeedItem(
      id: '4',
      ipName: '귀멸의 칼날',
      sourceName: '공식 유튜브',
      timeAgo: '2시간 전',
      title: '「무한성편」 본예고 PV 공개',
      badges: [BadgeKind.news],
      actionLabel: '보기',
      thumbnailSeed: 3,
      isVideo: true,
    ),
    FeedItem(
      id: '5',
      ipName: '하츠네 미쿠',
      sourceName: '공식 스토어',
      timeAgo: '어제',
      title: '매지컬 미라이 2026 티셔츠',
      badges: [BadgeKind.soldOut],
      priceLabel: '₩39,000',
      actionLabel: '재입고 알림',
      thumbnailSeed: 4,
    ),
  ];

  static const subscriptions = <Ip>[
    Ip(id: 'a', name: '귀멸의 칼날', category: '애니메', subscribed: true, thumbnailSeed: 0),
    Ip(id: 'b', name: '하츠네 미쿠', category: '보컬로이드', subscribed: true, thumbnailSeed: 2),
    Ip(id: 'c', name: '주술회전', category: '애니메', thumbnailSeed: 5),
    Ip(id: 'd', name: '원신', category: '게임', thumbnailSeed: 3),
    Ip(id: 'e', name: '산리오', category: '캐릭터', thumbnailSeed: 6),
    Ip(id: 'f', name: '체인소맨', category: '애니메', thumbnailSeed: 1),
  ];
}

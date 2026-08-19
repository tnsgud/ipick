import 'package:flutter_test/flutter_test.dart';
import 'package:ipick/domain/models/badge_kind.dart';
import 'package:ipick/domain/models/feed_item.dart';

/// `FeedItem.fromRow`는 Supabase `feed_items` 행(+ `ips(name)` 조인)을 UI 표시용
/// 모델로 바꾸는 순수 변환이다. 네트워크 없이 검증할 수 있는 가장 중요한 로직이라
/// 최우선으로 테스트한다.
void main() {
  /// 실제 Supabase 응답 형태를 그대로 본뜬 행. (Cloud에서 anon key로 조회한
  /// 실제 응답을 기반으로 함 — 필드명/중첩 구조가 실물과 같다.)
  Map<String, dynamic> row({
    String id = 'aba286ce-6c43-4760-87c4-74d078c8a4f0',
    String title = 'Tiny satellite will use the dark side of the Moon',
    String? buyUrl,
    String? itemType,
    Map<String, dynamic>? ips = const {'name': '귀멸의 칼날'},
    String? publishedAt,
  }) {
    return {
      'id': id,
      'title': title,
      'url': 'https://example.com/article',
      'buy_url': buyUrl,
      'image_url': null,
      'item_type': itemType,
      'published_at':
          publishedAt ??
          DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String(),
      'ips': ips,
    };
  }

  group('FeedItem.fromRow — 기본 매핑', () {
    test('id·title을 그대로 옮기고, 조인된 ips.name을 ipName으로 쓴다', () {
      final item = FeedItem.fromRow(row());

      expect(item.id, 'aba286ce-6c43-4760-87c4-74d078c8a4f0');
      expect(item.title, 'Tiny satellite will use the dark side of the Moon');
      expect(item.ipName, '귀멸의 칼날');
    });

    test('ips 조인이 없으면 ipName은 빈 문자열 (크래시하지 않는다)', () {
      final item = FeedItem.fromRow(row(ips: null));

      expect(item.ipName, '');
    });
  });

  group('FeedItem.fromRow — actionLabel', () {
    test('buy_url이 있으면 "구매하기"', () {
      final item = FeedItem.fromRow(row(buyUrl: 'https://shop.example.com/1'));

      expect(item.actionLabel, '구매하기');
    });

    test('buy_url이 없으면 "보기"', () {
      final item = FeedItem.fromRow(row());

      expect(item.actionLabel, '보기');
    });
  });

  group('FeedItem.fromRow — 상태 뱃지', () {
    test('item_type이 release면 발매 뱃지가 붙는다', () {
      final item = FeedItem.fromRow(row(itemType: 'release'));

      expect(item.badges, contains(BadgeKind.release));
    });

    test('buy_url이 있으면 임박 뱃지가 붙는다', () {
      final item = FeedItem.fromRow(row(buyUrl: 'https://shop.example.com/1'));

      expect(item.badges, contains(BadgeKind.closingSoon));
    });

    test('둘 다 해당하면 뱃지 두 개가 모두 붙는다', () {
      final item = FeedItem.fromRow(
        row(itemType: 'release', buyUrl: 'https://shop.example.com/1'),
      );

      expect(item.badges, containsAll([BadgeKind.release, BadgeKind.closingSoon]));
    });

    test('아무 조건도 없으면 뱃지가 비어 있다 (수집기가 넣는 일반 소식의 기본 형태)', () {
      final item = FeedItem.fromRow(row());

      expect(item.badges, isEmpty);
    });
  });

  group('FeedItem.fromRow — timeAgo 상대시간', () {
    String timeAgoFor(Duration ago) {
      return FeedItem.fromRow(
        row(publishedAt: DateTime.now().toUtc().subtract(ago).toIso8601String()),
      ).timeAgo;
    }

    test('1분 이내는 "방금"', () {
      expect(timeAgoFor(const Duration(seconds: 20)), '방금');
    });

    test('1시간 미만은 분 단위', () {
      expect(timeAgoFor(const Duration(minutes: 12)), '12분 전');
    });

    test('하루 미만은 시간 단위', () {
      expect(timeAgoFor(const Duration(hours: 3)), '3시간 전');
    });

    test('하루 이상은 일 단위', () {
      expect(timeAgoFor(const Duration(days: 2, hours: 5)), '2일 전');
    });

    test('published_at이 타임존 오프셋(+00:00) 형식이어도 올바르게 계산한다', () {
      // Supabase는 "2026-08-19T01:06:03+00:00" 형태로 내려준다.
      final threeHoursAgo = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      final withOffset =
          '${threeHoursAgo.toIso8601String().replaceFirst('Z', '')}+00:00';

      final item = FeedItem.fromRow(row(publishedAt: withOffset));

      expect(item.timeAgo, '3시간 전');
    });
  });
}

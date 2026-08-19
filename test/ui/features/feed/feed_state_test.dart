import 'package:flutter_test/flutter_test.dart';
import 'package:ipick/domain/models/feed_item.dart';
import 'package:ipick/ui/features/feed/model/feed_state.dart';

/// FeedState는 불변 상태 + 파생 값(visible)만 담당한다. 순수 로직이라
/// 네트워크·위젯 없이 검증한다.
void main() {
  FeedItem item({required String id, bool isGoods = false}) {
    return FeedItem(
      id: id,
      ipName: '귀멸의 칼날',
      sourceName: '',
      timeAgo: '방금',
      title: '항목 $id',
      actionLabel: '보기',
      isGoods: isGoods,
    );
  }

  final goods = item(id: 'goods', isGoods: true);
  final news = item(id: 'news');

  group('visible — 필터별로 걸러진 목록', () {
    test('filter 0(전체)은 전부 보여준다', () {
      final state = FeedState(items: [goods, news], filter: 0);

      expect(state.visible, [goods, news]);
    });

    test('filter 1(발매·굿즈)은 굿즈 항목만', () {
      final state = FeedState(items: [goods, news], filter: 1);

      expect(state.visible, [goods]);
    });

    test('filter 2(소식)는 굿즈가 아닌 항목만', () {
      final state = FeedState(items: [goods, news], filter: 2);

      expect(state.visible, [news]);
    });

    test('items가 비어 있으면 어떤 필터에서도 빈 목록', () {
      for (final f in [0, 1, 2]) {
        expect(FeedState(items: const [], filter: f).visible, isEmpty);
      }
    });
  });

  group('copyWith', () {
    test('지정한 필드만 바뀌고 나머지는 유지된다', () {
      final original = FeedState(items: [goods], isLoading: true, filter: 1);

      final updated = original.copyWith(filter: 2);

      expect(updated.filter, 2);
      expect(updated.items, [goods]); // 유지
      expect(updated.isLoading, true); // 유지
    });

    test('인자를 주지 않으면 값이 그대로 복사된다', () {
      final original = FeedState(items: [goods, news], isLoading: true, filter: 2);

      final copy = original.copyWith();

      expect(copy.items, original.items);
      expect(copy.isLoading, original.isLoading);
      expect(copy.filter, original.filter);
    });

    test('기본 생성자는 빈 목록·비로딩·전체필터로 시작한다', () {
      final state = FeedState();

      expect(state.items, isEmpty);
      expect(state.isLoading, false);
      expect(state.filter, 0);
    });
  });
}

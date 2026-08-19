import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipick/data/repositories/feed_repository.dart';
import 'package:ipick/ui/features/feed/model/feed_state.dart';
import 'package:ipick/ui/features/feed/view_model/feed_view_model.dart';

import '../../../support/fake_feed_repository.dart';

/// FeedNotifier는 Repository에서 받은 데이터를 화면이 쓸 상태로 관리한다.
/// 가짜 Repository를 주입해 네트워크 없이 검증한다.
void main() {
  /// 가짜 Repository를 주입한 컨테이너를 만든다.
  ProviderContainer containerWith(FakeFeedRepository fake) {
    final container = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('build() 직후 자동 로딩', () {
    test('provider를 처음 읽으면 로딩이 시작되고, 끝나면 items가 채워진다', () async {
      final fake = FakeFeedRepository(
        items: [testFeedItem(id: '1'), testFeedItem(id: '2')],
      );
      final container = containerWith(fake);

      // 최초 읽기 → build()가 Future.microtask(load)를 예약한다.
      final initial = container.read(feedViewModel);
      expect(initial.items, isEmpty, reason: '로딩 전에는 비어 있어야 한다');

      // 예약된 마이크로태스크와 비동기 로딩이 끝나기를 기다린다.
      await container.read(feedViewModel.notifier).load();

      final loaded = container.read(feedViewModel);
      expect(loaded.items.length, 2);
      expect(loaded.isLoading, false);
    });
  });

  group('load()', () {
    test('성공하면 items를 채우고 isLoading을 내린다', () async {
      final fake = FakeFeedRepository(items: [testFeedItem(id: 'a')]);
      final container = containerWith(fake);

      await container.read(feedViewModel.notifier).load();

      final state = container.read(feedViewModel);
      expect(state.items.single.id, 'a');
      expect(state.isLoading, false);
    });

    test('빈 결과도 정상 처리한다 (구독 IP가 없거나 수집 전인 경우)', () async {
      final container = containerWith(FakeFeedRepository(items: const []));

      await container.read(feedViewModel.notifier).load();

      final state = container.read(feedViewModel);
      expect(state.items, isEmpty);
      expect(state.isLoading, false);
    });

    test('실패하면 예외를 던지지 않고 errorMessage에 담는다', () async {
      final fake = FakeFeedRepository(items: const []);
      final container = containerWith(fake);
      await container.read(feedViewModel.notifier).load();

      fake.error = Exception('네트워크 실패');

      // build()에서 자동 호출되므로 예외를 밖으로 던지면 아무도 잡지 못한다.
      await container.read(feedViewModel.notifier).load();

      final state = container.read(feedViewModel);
      expect(state.hasError, true);
      expect(state.errorMessage, isNotNull);
      expect(
        state.isLoading,
        false,
        reason: '실패해도 로딩 스피너가 영원히 도는 일은 없어야 한다',
      );
    });

    test('build()의 자동 로딩이 실패해도 앱이 죽지 않는다', () async {
      // 처음부터 실패하는 Repository. 예전에는 여기서 unhandled async exception이
      // 터졌다 (네트워크가 끊긴 상태로 앱을 켠 상황).
      final fake = FakeFeedRepository(error: Exception('오프라인'));
      final container = containerWith(fake);

      container.read(feedViewModel); // build() → 자동 load 예약
      await Future<void>.delayed(Duration.zero);

      expect(container.read(feedViewModel).hasError, true);
    });

    test('실패 후 다시 성공하면 errorMessage가 지워진다', () async {
      final fake = FakeFeedRepository(error: Exception('일시적 실패'));
      final container = containerWith(fake);
      await container.read(feedViewModel.notifier).load();
      expect(container.read(feedViewModel).hasError, true);

      fake.error = null;
      fake.items = [testFeedItem(id: 'ok')];
      await container.read(feedViewModel.notifier).load();

      final state = container.read(feedViewModel);
      expect(state.hasError, false);
      expect(state.items.single.id, 'ok');
    });
  });

  group('setFilter()', () {
    test('필터를 바꾸면 상태에 반영된다', () async {
      final container = containerWith(FakeFeedRepository(items: const []));
      await container.read(feedViewModel.notifier).load();

      container.read(feedViewModel.notifier).setFilter(2);

      expect(container.read(feedViewModel).filter, 2);
    });

    test('필터를 바꿔도 이미 불러온 items는 유지된다 (재조회하지 않는다)', () async {
      final fake = FakeFeedRepository(
        items: [
          testFeedItem(id: 'goods', isGoods: true),
          testFeedItem(id: 'news'),
        ],
      );
      final container = containerWith(fake);
      await container.read(feedViewModel.notifier).load();
      final callsAfterLoad = fake.loadCallCount;

      container.read(feedViewModel.notifier).setFilter(1);

      final state = container.read(feedViewModel);
      expect(state.items.length, 2, reason: '원본 목록은 그대로여야 한다');
      expect(fake.loadCallCount, callsAfterLoad, reason: '필터 변경은 재조회를 유발하지 않는다');
    });

    test('필터가 바뀌면 visible 결과도 함께 바뀐다', () async {
      final fake = FakeFeedRepository(
        items: [
          testFeedItem(id: 'goods', isGoods: true),
          testFeedItem(id: 'news'),
        ],
      );
      final container = containerWith(fake);
      await container.read(feedViewModel.notifier).load();

      container.read(feedViewModel.notifier).setFilter(1);
      expect(container.read(feedViewModel).visible.map((i) => i.id), ['goods']);

      container.read(feedViewModel.notifier).setFilter(2);
      expect(container.read(feedViewModel).visible.map((i) => i.id), ['news']);
    });
  });

  group('상태 타입', () {
    test('provider가 FeedState를 노출한다', () {
      final container = containerWith(FakeFeedRepository(items: const []));

      expect(container.read(feedViewModel), isA<FeedState>());
    });
  });
}

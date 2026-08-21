import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipick/data/repositories/feed_repository.dart';
import 'package:ipick/ui/core/theme/app_theme.dart';
import 'package:ipick/ui/features/feed/view/feed_screen.dart';
import 'package:ipick/ui/features/shell/app_shell.dart';

import 'support/fake_feed_repository.dart';

/// 화면 단위 테스트.
///
/// 진짜 `IPickApp`은 main()에서 Supabase가 초기화된 뒤에만 동작하므로, 여기서는
/// 같은 테마·같은 화면을 쓰되 Repository만 가짜로 바꿔 띄운다.
void main() {
  Widget appWith(FakeFeedRepository fake, {Widget home = const AppShell()}) {
    return ProviderScope(
      overrides: [feedRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(theme: AppTheme.light, home: home),
    );
  }

  group('앱 셸', () {
    testWidgets('하단 탭 4개가 보인다', (tester) async {
      await tester.pumpWidget(appWith(FakeFeedRepository(items: const [])));
      await tester.pumpAndSettle();

      expect(find.text('피드'), findsOneWidget);
      expect(find.text('구독'), findsOneWidget);
      expect(find.text('알림'), findsOneWidget);
      expect(find.text('MY'), findsOneWidget);
    });

    testWidgets('구독 탭으로 전환하면 IP 카드가 보인다', (tester) async {
      await tester.pumpWidget(appWith(FakeFeedRepository(items: const [])));
      await tester.pumpAndSettle();

      await tester.tap(find.text('구독'));
      await tester.pumpAndSettle();

      expect(find.text('구독하기'), findsWidgets);
    });
  });

  group('피드 화면', () {
    testWidgets('Repository가 준 항목이 카드로 렌더링된다', (tester) async {
      final fake = FakeFeedRepository(
        items: [
          testFeedItem(id: '1', title: '「무한성편」 아크릴 스탠드'),
          testFeedItem(id: '2', title: '탄지로 넨도로이드'),
        ],
      );

      await tester.pumpWidget(appWith(fake, home: const FeedScreen()));
      await tester.pumpAndSettle();

      expect(find.text('「무한성편」 아크릴 스탠드'), findsOneWidget);
      expect(find.text('탄지로 넨도로이드'), findsOneWidget);
    });

    testWidgets('데이터가 없어도 크래시 없이 빈 화면을 그린다', (tester) async {
      await tester.pumpWidget(
        appWith(FakeFeedRepository(items: const []), home: const FeedScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FeedScreen), findsOneWidget);
      expect(find.text('전체'), findsOneWidget); // 필터 칩은 여전히 보임
    });

    testWidgets('필터 칩 3개가 보이고 기본값은 "전체"가 선택된 상태다', (tester) async {
      await tester.pumpWidget(
        appWith(FakeFeedRepository(items: const []), home: const FeedScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('전체'), findsOneWidget);
      expect(find.text('발매·굿즈'), findsOneWidget);
      expect(find.text('소식'), findsOneWidget);
    });

    testWidgets('"발매·굿즈" 필터를 누르면 소식 항목이 목록에서 빠진다', (tester) async {
      final fake = FakeFeedRepository(
        items: [
          testFeedItem(id: 'goods', title: '아크릴 스탠드', isGoods: true),
          testFeedItem(id: 'news', title: 'PV 공개'),
        ],
      );

      await tester.pumpWidget(appWith(fake, home: const FeedScreen()));
      await tester.pumpAndSettle();

      // 처음엔 둘 다 보인다.
      expect(find.text('아크릴 스탠드'), findsOneWidget);
      expect(find.text('PV 공개'), findsOneWidget);

      await tester.tap(find.text('발매·굿즈'));
      await tester.pumpAndSettle();

      expect(find.text('아크릴 스탠드'), findsOneWidget);
      expect(
        find.text('PV 공개'),
        findsNothing,
        reason: '발매·굿즈 필터에서는 소식 항목이 보이지 않아야 한다',
      );
    });

    testWidgets('"소식" 필터를 누르면 굿즈 항목이 목록에서 빠진다', (tester) async {
      final fake = FakeFeedRepository(
        items: [
          testFeedItem(id: 'goods', title: '아크릴 스탠드', isGoods: true),
          testFeedItem(id: 'news', title: 'PV 공개'),
        ],
      );

      await tester.pumpWidget(appWith(fake, home: const FeedScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('소식'));
      await tester.pumpAndSettle();

      expect(find.text('PV 공개'), findsOneWidget);
      expect(find.text('아크릴 스탠드'), findsNothing);
    });

    testWidgets('불러오기에 실패하면 오류 메시지와 다시 시도 버튼이 보인다', (tester) async {
      final fake = FakeFeedRepository(error: Exception('오프라인'));

      await tester.pumpWidget(appWith(fake, home: const FeedScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('불러오지 못했'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('다시 시도를 누르면 재조회하고, 성공하면 항목이 나온다', (tester) async {
      final fake = FakeFeedRepository(error: Exception('오프라인'));

      await tester.pumpWidget(appWith(fake, home: const FeedScreen()));
      await tester.pumpAndSettle();

      fake.error = null;
      fake.items = [testFeedItem(id: '1', title: '복구된 항목')];

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('복구된 항목'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets('데이터가 없으면 빈 상태 안내를 보여준다', (tester) async {
      await tester.pumpWidget(
        appWith(FakeFeedRepository(items: const []), home: const FeedScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('아직 소식이 없어요'), findsOneWidget);
    });
  });
}

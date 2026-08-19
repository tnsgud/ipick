import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipick/domain/models/feed_item.dart';
import 'package:ipick/ui/core/widgets/goods_feed_card.dart';

/// 카드의 "가격 자리" 표시 규칙을 검증한다. 예전에는 가격이 없으면 무조건 "영상"이라
/// 실제 뉴스 항목이 전부 영상으로 표시되는 문제가 있었다.
void main() {
  Widget wrap(FeedItem item) =>
      MaterialApp(home: Scaffold(body: GoodsFeedCard(item: item)));

  FeedItem item({String? priceLabel, bool isVideo = false}) => FeedItem(
    id: '1',
    ipName: '귀멸의 칼날',
    sourceName: 'example.com',
    timeAgo: '방금',
    title: '테스트 항목',
    actionLabel: '보기',
    priceLabel: priceLabel,
    isVideo: isVideo,
  );

  testWidgets('가격이 있으면 가격을 보여준다', (tester) async {
    await tester.pumpWidget(wrap(item(priceLabel: '₩18,000')));

    expect(find.text('₩18,000'), findsOneWidget);
    expect(find.text('영상'), findsNothing);
  });

  testWidgets('가격이 없고 영상이면 "영상"을 보여준다', (tester) async {
    await tester.pumpWidget(wrap(item(isVideo: true)));

    expect(find.text('영상'), findsOneWidget);
  });

  testWidgets('가격도 없고 영상도 아니면 아무 라벨도 안 보인다 (일반 소식)', (tester) async {
    await tester.pumpWidget(wrap(item()));

    expect(find.text('영상'), findsNothing);
  });

  testWidgets('출처와 IP 이름이 함께 보인다', (tester) async {
    await tester.pumpWidget(wrap(item()));

    expect(find.textContaining('귀멸의 칼날'), findsOneWidget);
    expect(find.textContaining('example.com'), findsOneWidget);
  });
}

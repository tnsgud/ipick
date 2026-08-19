import 'package:ipick/data/repositories/feed_repository.dart';
import 'package:ipick/domain/models/badge_kind.dart';
import 'package:ipick/domain/models/feed_item.dart';

/// 테스트용 가짜 Repository.
///
/// `implements`를 쓰기 때문에 진짜 [FeedRepository]의 생성자(→ SupabaseService →
/// Supabase.instance)를 거치지 않는다. 덕분에 Supabase 초기화 없이 ViewModel과
/// 화면을 테스트할 수 있다.
class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository({this.items = const [], this.error});

  List<FeedItem> items;

  /// 값이 있으면 [loadFeed]가 이 예외를 던진다 (실패 경로 테스트용).
  ///
  /// mutable인 이유: `FeedNotifier.build()`가 생성 직후 자동으로 load를 부르기
  /// 때문에, 처음부터 error를 심어두면 그 자동 로딩이 먼저 터져버린다. 자동
  /// 로딩은 성공시키고 이후 수동 호출만 실패시키려면 도중에 바꿀 수 있어야 한다.
  Object? error;

  /// loadFeed가 몇 번 호출됐는지 (중복 로딩 검증용).
  int loadCallCount = 0;

  @override
  Future<List<FeedItem>> loadFeed() async {
    loadCallCount++;
    if (error != null) throw error!;
    return items;
  }
}

/// 테스트에서 쓰는 표본 피드 항목.
FeedItem testFeedItem({
  required String id,
  String title = '테스트 항목',
  bool isVideo = false,
  bool isGoods = false,
  List<BadgeKind> badges = const [],
  String actionLabel = '보기',
}) {
  return FeedItem(
    id: id,
    ipName: '귀멸의 칼날',
    sourceName: '',
    timeAgo: '방금',
    title: title,
    badges: badges,
    actionLabel: actionLabel,
    isVideo: isVideo,
    isGoods: isGoods,
  );
}

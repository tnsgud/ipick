import '../../../../domain/models/feed_item.dart';

class FeedState {
  FeedState({
    this.items = const [],
    this.isLoading = false,
    this.filter = 0,
    this.errorMessage,
  });

  final List<FeedItem> items;
  final bool isLoading;
  final int filter; // 0 전체 / 1 발매·굿즈 / 2 소식

  /// 로딩에 실패했을 때 화면에 보여줄 메시지. 성공하면 null로 지워진다.
  final String? errorMessage;

  bool get hasError => errorMessage != null;

  /// 현재 필터가 적용된 목록. 발매·굿즈와 소식은 [FeedItem.isGoods]로 가른다
  /// (살 수 있거나 발매 공지인 항목 = 굿즈, 나머지 = 소식).
  List<FeedItem> get visible => switch (filter) {
    1 => items.where((i) => i.isGoods).toList(),
    2 => items.where((i) => !i.isGoods).toList(),
    _ => items,
  };

  FeedState copyWith({
    List<FeedItem>? items,
    bool? isLoading,
    int? filter,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FeedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      filter: filter ?? this.filter,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipick/data/repositories/feed_repository.dart';

import '../model/feed_state.dart';

class FeedNotifier extends Notifier<FeedState> {
  @override
  FeedState build() {
    Future.microtask(load);
    return FeedState();
  }

  /// 피드를 불러온다.
  ///
  /// 실패해도 예외를 밖으로 던지지 않고 상태(errorMessage)에 담는다. build()에서
  /// 자동 호출되기 때문에, 던지면 아무도 잡지 않는 비동기 예외가 되어 앱이
  /// 그대로 터진다(네트워크가 끊긴 상황 등).
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final items = await ref.read(feedRepositoryProvider).loadFeed();

      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '피드를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  void setFilter(int filter) {
    state = state.copyWith(filter: filter);
  }
}

final feedViewModel = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);

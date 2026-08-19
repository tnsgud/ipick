import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipick/data/services/supabase_service.dart';

import '../../domain/models/feed_item.dart';

class FeedRepository {
  FeedRepository(this._supabaseService);
  final SupabaseService _supabaseService;

  Future<List<FeedItem>> loadFeed() async {
    final ipIds = await _supabaseService.fetchMySubscriptionIpIds();
    final rows = await _supabaseService.fetchFeed(ipIds);

    return rows.map(FeedItem.fromRow).toList();
  }
}

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(SupabaseService());
});

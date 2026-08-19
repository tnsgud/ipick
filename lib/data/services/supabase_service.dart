import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchFeed(List<String> ipIds) async {
    if (ipIds.isEmpty) return [];

    final data = await _client
        .from('feed_items')
        .select(
          'id, title, url, buy_url, image_url, published_at, item_type, ips(name)',
        )
        .inFilter('ip_id', ipIds)
        .order('published_at', ascending: false)
        .limit(50);

    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchIps() async {
    final data = await _client
        .from('ips')
        .select('id, name, category_id, categories(name)');

    return (data as List).cast<Map<String, dynamic>>();
  }

  /// 피드에 보여줄 IP 목록.
  ///
  /// - 로그인 상태: 내가 구독한 IP만.
  /// - 미로그인 상태: 전체 IP(둘러보기용 샘플 피드). 설계 문서 §4의 "미로그인은
  ///   샘플/추천 피드를 보여주고 구독은 로그인을 유도한다" 방침을 따른다.
  Future<List<String>> fetchMySubscriptionIpIds() async {
    final uid = _client.auth.currentUser?.id;

    if (uid == null) return _fetchAllIpIds();

    final data = await _client
        .from('subscriptions')
        .select('ip_id')
        .eq('user_id', uid);

    final ipIds = (data as List).map((r) => r['ip_id'] as String).toList();

    // 로그인은 했지만 아직 아무것도 구독하지 않았다면 빈 피드 대신 둘러보기를 보여준다.
    return ipIds.isEmpty ? _fetchAllIpIds() : ipIds;
  }

  Future<List<String>> _fetchAllIpIds() async {
    final data = await _client.from('ips').select('id');
    return (data as List).map((r) => r['id'] as String).toList();
  }

  Future<void> subscribe(String ipId) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('subscriptions').upsert({'user_id': uid, 'ip_id': ipId});
  }

  Future<void> unsubscribe(String ipId) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('subscriptions').delete().match({
      'user_id': uid,
      'ip_id': ipId,
    });
  }
}

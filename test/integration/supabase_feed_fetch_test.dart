@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipick/data/repositories/feed_repository.dart';
import 'package:ipick/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 진짜 Supabase Cloud에 붙는 통합 테스트.
///
/// 네트워크에 의존하므로 기본 `flutter test`에서는 제외된다(integration 태그).
/// 실행:
///   flutter test --tags integration
///
/// 여기서 쓰는 키는 앱에 이미 들어있는 publishable(anon) 키다 — 공개돼도 안전하도록
/// 설계된 값이고, 실제 방어선은 DB의 RLS다. secret/service_role 키는 절대 쓰지 않는다.
void main() {
  const url = 'https://obxjpqemljdtxyhykber.supabase.co';
  const publishableKey = 'sb_publishable_XZt4olfVPGBrEO4p0aXYJg_ik1LxnKK';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_test는 실수로 네트워크를 타지 않도록 모든 HTTP 요청을 가짜 400으로
    // 막는다. 이 파일은 의도적으로 진짜 Cloud에 붙는 통합 테스트이므로 해제한다.
    HttpOverrides.global = null;
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      // 테스트에서는 세션을 디스크에 저장할 필요가 없다. 기본값은 shared_preferences
      // 플러그인을 쓰는데, 플러그인이 없는 순수 테스트 환경에서는 초기화가 실패한다.
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _InMemoryAsyncStorage(),
      ),
    );
  });

  test('SupabaseService.fetchFeed — 구독 IP의 피드를 실제로 가져온다', () async {
    final service = SupabaseService();

    final ipIds = await service.fetchMySubscriptionIpIds();
    expect(ipIds, isNotEmpty, reason: '구독 IP 목록이 비면 피드도 비게 된다');

    final rows = await service.fetchFeed(ipIds);

    expect(rows, isNotEmpty, reason: '수집기가 넣어둔 feed_items가 있어야 한다');

    // 앱이 실제로 읽는 필드들이 응답에 들어있는지 확인한다.
    final first = rows.first;
    expect(first['id'], isA<String>());
    expect(first['title'], isA<String>());
    expect(first['published_at'], isA<String>());
    expect(first['ips'], isA<Map>(), reason: 'ips(name) 조인이 동작해야 ipName을 채울 수 있다');
  });

  test('FeedRepository.loadFeed — 실제 응답이 FeedItem으로 변환된다', () async {
    final repository = FeedRepository(SupabaseService());

    final items = await repository.loadFeed();

    expect(items, isNotEmpty);

    final first = items.first;
    expect(first.id, isNotEmpty);
    expect(first.title, isNotEmpty);
    expect(first.ipName, isNotEmpty, reason: '조인된 IP 이름이 채워져야 한다');
    expect(first.timeAgo, isNotEmpty, reason: '상대시간 문자열이 계산돼야 한다');
    expect(
      first.timeAgo,
      anyOf(contains('방금'), contains('분 전'), contains('시간 전'), contains('일 전')),
    );
  });

  test('anon 키로는 sources 테이블에 접근할 수 없다 (RLS 방어선 확인)', () async {
    // sources는 정책이 없어 익명 접근이 막혀 있어야 한다. 관리자 화면을 붙이기
    // 전까지 이 상태가 유지되는지 확인하는 회귀 테스트.
    final client = Supabase.instance.client;

    final result = await client.from('sources').select('id');

    expect(result, isEmpty, reason: 'RLS가 익명 사용자에게 sources를 노출하면 안 된다');
  });
}

/// 테스트용 인메모리 PKCE 저장소. 실기기에서는 shared_preferences가 쓰이지만
/// 순수 테스트 환경에는 플러그인이 없어 대체가 필요하다.
class _InMemoryAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _store.remove(key);
  }
}

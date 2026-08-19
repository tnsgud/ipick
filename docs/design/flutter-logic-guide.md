# iPick Flutter — 내부 로직 구현 가이드

- 대상: **UI는 이미 구현됨(목업 데이터).** 이 문서는 남은 "내부 로직"을 직접 구현하려는 개발자를 위한 설명서다.
- 원칙: 이 앱은 **MVVM + Repository** 레이어를 따른다 (Flutter 공식 아키텍처 권장안).

```
┌─────────── 이미 만들어진 것 (UI 레이어) ───────────┐
  lib/ui/core/         테마·토큰·재사용 위젯
  lib/ui/features/     화면(View) — 지금은 목업을 직접 읽음
  lib/domain/models/   FeedItem, Ip, BadgeKind (표시용 모델)
  lib/mock/            MockData (교체 대상)
└────────────────────────────────────────────────┘
┌─────────── 당신이 만들 것 (로직) ─────────────────┐
  lib/data/services/       Supabase 클라이언트 래퍼
  lib/data/repositories/   Feed/Subscription/Auth Repository
  lib/ui/**/view_model/    각 화면의 ViewModel (Riverpod Notifier)
  FCM 연동 (앱 + 백엔드 양쪽)
└────────────────────────────────────────────────┘
```

핵심 흐름: **View → ViewModel(상태) → Repository(단일 진실원천) → Service(Supabase) → DB**.
지금 View는 `MockData`를 직접 읽는다. 목표는 **View가 ViewModel(Provider)을 구독**하고,
ViewModel이 Repository에서 실제 데이터를 받아오게 바꾸는 것이다.

> **상태관리: Riverpod.** 코드젠 없는 `Notifier`/`NotifierProvider` 스타일(§3-a, §6)을
> 기준으로 쓴다. `feed` 기능이 이미 이 패턴으로 구현돼 있으니(`lib/ui/features/feed/`),
> 나머지 기능(구독·인증)도 같은 모양을 따르면 된다.

---

## 0. 의존성 추가

`pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.17.1    # 인증 + DB 접근
  flutter_riverpod: ^3.4.2     # DI + ViewModel 구독
```
```bash
flutter pub get
```

Supabase 프로젝트의 **URL**과 **publishable/anon key**가 필요하다 (백엔드가 이미 로컬/원격에
있음). 앱에서는 반드시 **publishable(anon) key**만 쓴다 — `secret`/`service_role` 키는 절대
앱에 넣지 않는다(수집기 전용). RLS 정책상 anon/authenticated는 `categories/ips/feed_items`
**읽기**와 본인 `subscriptions`(§신규, 아래 참고)·`device_tokens` 쓰기만 가능하다(백엔드
마이그레이션 `0001_core_schema.sql`, `0004_subscriptions.sql` 참고).

`main()`에서 초기화 (Riverpod은 `ProviderScope`로 앱을 감싼다):
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: '<SUPABASE_URL>',
    publishableKey: '<SUPABASE_PUBLISHABLE_OR_ANON_KEY>',
  );
  runApp(ProviderScope(child: const IPickApp()));
}
```

> 참고: 지금 `feed_items`를 앱이 읽으려면 RLS read 정책은 이미 있지만, **구독 기반 필터**는
> 앱에서 `where ip_id in (내 구독 IP들)`로 건다(§3). 서버가 유저별로 걸러주지 않는다.

> **`subscriptions` 테이블 상태 (갱신):** 처음 이 문서를 쓸 때는 아직 없었지만, 이제
> `supabase/migrations/0004_subscriptions.sql`로 존재한다 — `(user_id, ip_id)` PK,
> RLS로 본인 행만 read/insert/delete, `service_role`에는 select만 부여(다음 계획의 푸시
> 팬아웃이 전체 구독자를 조회할 때 씀). `SupabaseService`의 관련 메서드를 이 테이블에 맞춰
> 활성화하면 된다.

---

## 1. 도메인 모델 ↔ DB 매핑

이미 있는 표시용 모델(`lib/domain/models/`)을 DB 행과 잇는다. 표시용 문자열(`timeAgo`,
`priceLabel`)은 Repository에서 계산해 채운다.

| 표시 모델 필드 | DB 출처 (`feed_items`) | 비고 |
|---|---|---|
| `id` | `id` | |
| `ipName` | `ips.name` (조인) | |
| `sourceName` | `sources` 또는 `feed_items`에 별도 저장 | MVP는 IP명만 써도 됨 |
| `timeAgo` | `published_at` → 상대시간 포맷 | `"12분 전"` 등 |
| `title` | `title` | |
| `badges` | `item_type` + 발매/예약 규칙 | §3-b |
| `priceLabel` | (굿즈면) 가격 필드 | MVP엔 없을 수 있음 |
| `actionLabel` | `buy_url` 유무로 결정 | 링크 있으면 "구매하기" |

`fromMap` 팩토리를 각 모델에 추가하는 걸 권장:
```dart
factory FeedItem.fromRow(Map<String, dynamic> row) {
  return FeedItem(
    id: row['id'] as String,
    ipName: (row['ips']?['name'] ?? '') as String,   // 조인 결과
    sourceName: '',
    timeAgo: _relativeTime(DateTime.parse(row['published_at'] as String)),
    title: row['title'] as String,
    badges: _badgesFrom(row),                         // §3-b
    priceLabel: null,
    actionLabel: (row['buy_url'] != null) ? '구매하기' : '보기',
    isVideo: false,
  );
}
```

---

## 2. Data 레이어

### 2-a. Service (Supabase 래퍼, 무상태)
```dart
// lib/data/services/supabase_service.dart
class SupabaseService {
  final SupabaseClient _c = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchFeed(List<String> ipIds) async {
    if (ipIds.isEmpty) return [];
    final data = await _c
        .from('feed_items')
        .select('id, title, url, buy_url, image_url, published_at, item_type, ips(name)')
        .inFilter('ip_id', ipIds)
        .order('published_at', ascending: false)
        .limit(50);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchIps() async {
    final data = await _c.from('ips').select('id, name, category_id, categories(name)');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<String>> fetchMySubscriptionIpIds() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _c.from('subscriptions').select('ip_id').eq('user_id', uid);
    return (data as List).map((r) => r['ip_id'] as String).toList();
  }

  Future<void> subscribe(String ipId) async {
    final uid = _c.auth.currentUser!.id;
    await _c.from('subscriptions').upsert({'user_id': uid, 'ip_id': ipId});
  }

  Future<void> unsubscribe(String ipId) async {
    final uid = _c.auth.currentUser!.id;
    await _c.from('subscriptions').delete().match({'user_id': uid, 'ip_id': ipId});
  }
}
```

### 2-b. Repository (단일 진실원천, 도메인 모델 반환)
```dart
// lib/data/repositories/feed_repository.dart
class FeedRepository {
  FeedRepository(this._svc);
  final SupabaseService _svc;

  Future<List<FeedItem>> loadFeed() async {
    final ipIds = await _svc.fetchMySubscriptionIpIds();
    final rows = await _svc.fetchFeed(ipIds);
    return rows.map(FeedItem.fromRow).toList();
  }
}
```
`SubscriptionRepository`, `AuthRepository`도 같은 패턴으로 만든다.

---

## 3. 화면별 "목업 → 실제" 전환

### 3-a. Feed 화면 (구현됨 — 다른 기능의 참고 템플릿)

`lib/ui/features/feed/`에 이미 이 패턴으로 구현돼 있다. 상태는 불변 클래스로, 로직은
`Notifier`로 분리한다:

```dart
// lib/ui/features/feed/model/feed_state.dart
class FeedState {
  FeedState({this.items = const [], this.isLoading = false, this.filter = 0});
  final List<FeedItem> items;
  final bool isLoading;
  final int filter; // 0 전체 / 1 발매·굿즈 / 2 소식

  List<FeedItem> get visible => switch (filter) {
    1 => items.where((i) => !i.isVideo).toList(),
    2 => items.where((i) => i.isVideo).toList(),
    _ => items,
  };

  FeedState copyWith({List<FeedItem>? items, bool? isLoading, int? filter}) => FeedState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    filter: filter ?? this.filter,
  );
}
```

```dart
// lib/ui/features/feed/view_model/feed_view_model.dart
class FeedNotifier extends Notifier<FeedState> {
  @override
  FeedState build() {
    Future.microtask(load); // build 중 상태변경 금지 → microtask로 미룸
    return FeedState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await ref.watch(feedRepositoryProvider).loadFeed();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  void setFilter(int filter) => state = state.copyWith(filter: filter);
}

final feedViewModel = NotifierProvider<FeedNotifier, FeedState>(FeedNotifier.new);
```

View에서 구독:
```dart
class FeedScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedViewModel);
    // state.visible 를 ListView에, 필터 칩 onTap에는
    // ref.read(feedViewModel.notifier).setFilter(i) 호출
  }
}
```

**주의 (자주 하는 실수):** 필터 탭 같은 사용자 액션은 반드시
`ref.read(feedViewModel.notifier).setFilter(i)`처럼 **Notifier의 메서드**를 호출해야
한다. `ref.watch(...)`로 꺼낸 값을 `setState(() => 지역변수 = i)`로 바꾸는 건 그 build()
안에서만 사는 지역 변수를 바꾸는 것이라, 다음 리빌드에서 `ref.watch`가 다시 원래 상태를
읽어와 덮어써 버린다 — 즉 아무 효과가 없다. 상태 변경은 항상 Notifier(또는
Repository→Notifier 경로)를 통해서만 한다.

### 3-b. 상태 뱃지 규칙 (`_badgesFrom`)
`feed_items`엔 원문 상태가 구조화돼 있지 않으므로, MVP에서는 **규칙 기반**으로 매핑한다:
- `item_type == 'release'` → `BadgeKind.release`
- `buy_url != null` && 마감일 임박 → `BadgeKind.closingSoon`
- 그 외 소식(영상/공지) → `BadgeKind.news`

정교한 분류(한정/예약중 자동판별)는 후속. 지금은 운영자가 `item_type`을 채우거나 간단
키워드 규칙으로 시작한다(설계 문서 §6 참고).

### 3-c. Subscriptions 화면
- `SubscriptionsViewModel`이 `fetchIps()` + `fetchMySubscriptionIpIds()`를 합쳐 각 IP의
  `subscribed`를 채운다.
- 토글 시 `subscribe()/unsubscribe()` 호출 → 성공하면 로컬 상태 갱신(낙관적 업데이트 권장).
- 지금 `_toggle`(로컬)을 VM 호출로 교체.

---

## 4. 인증 (Supabase Auth)

- MVP는 익명 로그인 또는 매직링크/OAuth 중 택1. 구독을 기기 간 동기화하려면 로그인이 필요.
- `AuthRepository`가 `Supabase.instance.client.auth`를 감싼다:
  - `signInWithOtp(email)` / `signInWithOAuth(Provider.google)` / `signOut()`
  - `onAuthStateChange` 스트림으로 로그인 상태를 앱 전역에 반영.
- 미로그인 상태에서는 피드를 "샘플/추천"으로 보여주고, 구독은 로그인 유도.
- **주의**: 인증 관련 값(비밀번호·토큰)을 코드에 하드코딩하지 말 것.

---

## 5. FCM 푸시 (당신이 직접 구현) — 앱 + 백엔드 양쪽

FCM은 두 쪽이 맞물린다. **앱**은 토큰을 받아 저장하고 알림을 표시하고, **백엔드**(수집기)는
새 글 저장 시 구독자에게 발송한다. 아래는 앱 쪽 골격 + 백엔드 연결 지점이다.

### 5-a. 앱 쪽 (Flutter)
1. Firebase 프로젝트 생성 → `flutterfire configure` 로 `firebase_options.dart` 생성.
   의존성: `firebase_core`, `firebase_messaging`.
2. iOS는 Apple 개발자 계정에서 **APNs 키**를 발급해 Firebase 콘솔에 등록(1회). Android는 별도 설정 거의 없음.
3. 초기화 + 토큰 저장:
```dart
Future<void> registerPush() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();               // iOS 권한
  final token = await messaging.getToken();
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (token != null && uid != null) {
    await Supabase.instance.client.from('device_tokens').upsert({
      'user_id': uid,
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'token');
  }
  messaging.onTokenRefresh.listen((t) { /* 위와 동일하게 갱신 저장 */ });
}
```
4. 포그라운드 수신은 `FirebaseMessaging.onMessage`, 백그라운드/종료는
   `onBackgroundMessage` 핸들러로 처리. 탭 시 해당 피드 항목으로 딥링크.

> **`device_tokens` 테이블은 아직 백엔드에 없다.** 백엔드 설계 §6에 정의돼 있으나 이번
> 백엔드 계획(수집 파이프라인)에서는 범위 밖이었다. FCM을 하려면 이 테이블 마이그레이션을
> 먼저 추가해야 한다(설계 문서의 스키마 그대로).

### 5-b. 백엔드 쪽 (수집기 팬아웃 — 다음 백엔드 계획)
수집기(`runCollector`)는 이미 **새로 삽입된 항목을 `newItems`로 반환**하도록 만들어져 있다
(그래서 중복이 아닌 진짜 새 글만 담긴다). 푸시 계획에서는:
1. `runCollector` 결과의 `newItems` 각각에 대해, 그 `ip_id`를 구독한 유저의 `device_tokens`를 조회.
2. FCM HTTP v1 API로 그 토큰들에 발송.
3. 만료 토큰(`unregistered`) 응답이면 해당 `device_tokens` 행 삭제.

즉 앱은 "토큰 저장 + 알림 표시"만, 실제 발송 결정은 백엔드가 한다. 이 팬아웃은 별도 계획
(brainstorming→plan→구현)으로 진행하는 걸 권장한다.

---

## 6. DI 배선 (Riverpod)

Riverpod은 `MultiProvider` 같은 위젯 트리 배선이 없다. 각 레이어를 최상위 `Provider`로
선언하고, 상위 Provider 안에서 `ref.watch`/생성자 주입으로 아래 레이어를 가져온다:

```dart
// lib/data/services/supabase_service.dart
final supabaseServiceProvider = Provider<SupabaseService>((ref) => SupabaseService());

// lib/data/repositories/feed_repository.dart
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(supabaseServiceProvider));
});

// lib/ui/features/feed/view_model/feed_view_model.dart
final feedViewModel = NotifierProvider<FeedNotifier, FeedState>(FeedNotifier.new);
// FeedNotifier 내부에서 ref.watch(feedRepositoryProvider)로 Repository에 접근 (§3-a)
```

앱 진입점은 `ProviderScope`로 한 번만 감싸면 끝 (§0):
```dart
runApp(ProviderScope(child: const IPickApp()));
```

View에서 접근:
- 상태 구독(리빌드 필요) → `ref.watch(feedViewModel)`
- 액션만 호출(리빌드 불필요) → `ref.read(feedViewModel.notifier).setFilter(i)`
- `StatelessWidget`/`State` 대신 `ConsumerWidget`/`ConsumerStatefulWidget`을 써야
  `ref`를 받을 수 있다 (`build(BuildContext context, WidgetRef ref)`).

`SubscriptionRepository`·`AuthRepository`·그 ViewModel들도 위와 같은 모양
(Provider/NotifierProvider 선언 + `ref.watch`로 하위 의존성 주입)으로 추가하면 된다.

---

## 7. 폰트 (Pretendard) — 선택

DESIGN.md는 Pretendard를 지정한다. 지금은 시스템 폰트로 폴백 중이다. 적용하려면:
1. Pretendard(OFL) `.ttf`를 `assets/fonts/`에 넣고 `pubspec.yaml`의 `fonts:`에 등록.
2. `lib/ui/core/theme/app_text_styles.dart`의 `fontFamily`를 `'Pretendard'`로.

---

## 8. 구현 순서 제안

1. 의존성 추가 + `Supabase.initialize` (§0) — 완료
2. 인증 없이 **읽기 전용 피드**부터: `SupabaseService.fetchFeed` + `FeedRepository` +
   `feedViewModel` → FeedScreen 목업 교체 (§2, §3-a) — 완료
3. 인증 (§4) → `subscriptions` 테이블은 이미 있으니(§0 참고) 구독 화면 실제 연동 (§3-c)
4. FCM (§5) — `device_tokens` 마이그레이션 추가 후 앱 토큰 저장 → 백엔드 팬아웃은 별도 계획

각 단계 끝에 `flutter analyze` + 위젯 테스트로 회귀 확인.
```

> UI 위젯/화면은 그대로 두고 데이터 소스만 갈아끼우도록 설계돼 있으니, 목업을 VM으로
> 교체하는 작업이 대부분이다.

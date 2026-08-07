# 마이너 팬덤 소식 통합 알리미 — 설계 문서 (MVP)

- 작성일: 2026-08-06
- 상태: 설계 승인됨 (구현 계획 전 단계)

## 1. 배경 & 문제 정의

마이너한 취향(특정 애니메·게임·아이돌 IP 등)을 가진 사람은, 좋아하는 IP의
소식(신제품, IP 협업, 이벤트)을 얻으려면 Instagram·X·공식 웹사이트·YouTube 등
**여러 곳을 일일이 돌아다녀야 한다.** 소식이 흩어져 있어 한눈에 파악하기 어렵다.

이 프로젝트는 **IP별 공식 소스를 한곳에 모아 통합 피드 + 푸시 알림으로 전달**해
이 문제를 해결한다.

검증할 핵심 가설: *"흩어진 IP 소식을 한곳에 모아주면 팬덤 사용자가 쓸 것인가?"*

## 2. 범위 (Scope)

### MVP 포함
- 인접 팬덤/덕후 카테고리 몇 개 (예: 애니메, 게임, 아이돌 굿즈)
- 운영자가 IP별 **공식 소스 화이트리스트**를 큐레이션
- 수집 소스: **공식 웹사이트(RSS/스크래핑) + YouTube** (난이도 낮은 소스 우선)
- 사용자: IP 구독, **앱 내 통합 피드**, **푸시 알림**
- 플랫폼: **Flutter** 네이티브 앱 (iOS + Android 단일 코드베이스)

### MVP 제외 (다음 단계로 연기)
- **X / Instagram 수집** — 공식 API 유료·차단·법적 리스크가 커서 MVP 이후로 연기.
  어댑터 패턴으로 확장 여지만 남겨둔다.
- **교차 소스 중복 묶기** — 같은 소식이 웹사이트·유튜브에 동시 게시되면 피드에
  2개로 표시(허용). 텍스트 유사도 기반 묶기는 v2.
- 별도 Admin 웹 페이지 (초기엔 Supabase 대시보드로 운영)
- 알림 발송 로그 테이블, 태그/검색, 유저 프로필 확장

## 3. 접근 방식

**선택: 매니지드 서비스 기반 린 MVP.** 인프라 실력이 아니라 제품 가설을 최소
비용·최단 시간으로 검증하는 것이 목표. 검증되면 자체 호스팅(전용 서버·큐·워커)으로
확장할 여지를 남긴다.

## 4. 아키텍처

```
                        ┌─────────────────────────────┐
   운영자 (큐레이션)  →  │  Admin (MVP: Supabase 대시보드)│
                        │  Category·IP·Source 등록·관리  │
                        └──────────────┬──────────────┘
                                       │ 소스 화이트리스트
                                       ▼
   ┌───────────────┐   cron    ┌────────────────────────────┐
   │  Scheduler     │─────────▶│  Collector (Edge Function)  │
   │  (pg_cron)     │  15분마다  │  ├ RssAdapter               │
   └───────────────┘          │  ├ YoutubeAdapter           │
                              │  └ WebsiteAdapter            │
                              │   → 정규화 → 중복제거 → 저장  │
                              └──────────────┬─────────────┘
                                             │ 새 FeedItem
                        ┌────────────────────┼────────────────────┐
                        ▼                     ▼                    ▼
                 ┌────────────┐      ┌──────────────┐      ┌──────────────┐
                 │  Postgres   │      │  Push (FCM)   │      │   REST API    │
                 │  (Supabase) │      │  구독자 팬아웃  │      │  (피드·구독)   │
                 └────────────┘      └──────┬───────┘      └──────┬───────┘
                                            │ 푸시            │ 피드 조회
                                            ▼                 ▼
                                     ┌──────────────────────────────┐
                                     │  모바일 앱 (Flutter)           │
                                     │  통합 피드 · 구독관리 · 알림설정 │
                                     └──────────────────────────────┘
```

### 구성요소

| 구성요소 | 역할 | MVP 구현 |
|---------|------|---------|
| 모바일 앱 | 통합 피드, IP 구독/해제, 알림 설정, 푸시 수신 | Flutter (iOS+AOS) |
| Backend | Postgres DB + 인증 + REST API + 푸시 트리거 | Supabase (관리형) |
| Collector | 소스별 어댑터로 수집 → 정규화 → 중복제거 → 저장 → 푸시 팬아웃 | Supabase Edge Function (TypeScript/Deno) |
| Scheduler | Collector를 주기적으로 실행 | Supabase pg_cron |
| Push | 폰에 푸시 알림 배달 (iOS APNs + Android) | Firebase Cloud Messaging (FCM) |
| Admin | 운영자가 Category·IP·Source 화이트리스트 관리 | Supabase 대시보드 Table Editor |

### 핵심 설계 원칙: 어댑터 패턴
소스 종류마다 `SourceAdapter` 인터페이스(`fetch()` → `normalize()`)를 구현한다.
RSS·YouTube·Website 어댑터가 각각 독립적이라, 나중에 X·Instagram 추가 시
**파이프라인은 그대로 두고 어댑터만 추가**한다.

## 5. 데이터 모델 (Supabase / Postgres)

`users`는 Supabase 인증(`auth.users`)을 사용한다.

```
categories ──1:N──▶ ips ──1:N──▶ sources
                     │
                     ├──1:N──▶ feed_items ◀──N:1── sources
                     │
                     └──N:M──▶ subscriptions ◀──N:1── auth.users ──1:N──▶ device_tokens
```

### categories — 대분류
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid PK | |
| name | text | "애니메" |
| slug | text unique | "anime" |

### ips — 팬덤 대상
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid PK | |
| category_id | uuid FK→categories | |
| name | text | "귀멸의 칼날" |
| slug | text unique | "demon-slayer" |
| description | text null | 소개 |
| thumbnail_url | text null | 구독 화면 썸네일 |

### sources — IP별 공식 소스 화이트리스트 (운영자 등록)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid PK | |
| ip_id | uuid FK→ips | |
| type | text enum | `rss` \| `youtube` \| `website` |
| url | text | RSS 주소 / 채널ID / 페이지 URL |
| config | jsonb null | 스크래핑 CSS 선택자 등 타입별 설정 |
| is_active | bool default true | 폴링 on/off |
| last_polled_at | timestamptz null | 마지막 시도 시각 |
| last_success_at | timestamptz null | 마지막 성공 시각 |
| consecutive_failures | int default 0 | 연속 실패 횟수 (헬스체크) |

### feed_items — 정규화된 소식 (Collector 저장)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid PK | |
| ip_id | uuid FK→ips | 피드 필터링용 (비정규화) |
| source_id | uuid FK→sources | |
| external_id | text | RSS guid / YouTube videoId / url해시 |
| title | text | |
| summary | text null | |
| url | text | 원문 링크 |
| image_url | text null | 썸네일 |
| published_at | timestamptz | 원문 게시 시각 |
| created_at | timestamptz default now() | 수집 시각 |
| — | UNIQUE(source_id, external_id) | **중복제거의 핵심** |

### subscriptions — 유저 ↔ IP (다대다)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| user_id | uuid FK→auth.users | |
| ip_id | uuid FK→ips | |
| — | PK(user_id, ip_id) | 중복 구독 방지 |

### device_tokens — FCM 푸시 대상
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | uuid PK | |
| user_id | uuid FK→auth.users | |
| token | text unique | FCM 토큰 |
| platform | text enum | `ios` \| `android` |
| updated_at | timestamptz | 토큰 갱신 시각 |

### 설계 포인트
1. **중복제거는 DB가 강제** — `feed_items`의 `UNIQUE(source_id, external_id)`로
   같은 글 재삽입을 DB가 거부(`ON CONFLICT DO NOTHING`).
2. **`feed_items.ip_id` 비정규화** — 조인 없이 "구독한 IP들의 피드"를 빠르게 조회.
3. **소스 헬스 필드**(`last_success_at`, `consecutive_failures`)로 고장난 소스 자동
   비활성화(§7).

## 6. 수집 파이프라인

### Collector 1회 실행 흐름
```
Scheduler(pg_cron, 15분마다)
   └─▶ Collector Edge Function 호출
         1. sources 에서 is_active=true 소스 전부 조회
         2. 소스마다 (실패해도 서로 격리):
              ├ type에 맞는 어댑터 선택
              ├ adapter.fetch(source)   → RawItem[]  (원본 긁기)
              ├ adapter.normalize(raw)  → FeedItem[] (공통 형태로 변환)
              ├ INSERT ... ON CONFLICT DO NOTHING → 새 글만 저장
              └ 소스 헬스 갱신 (last_success_at, consecutive_failures=0)
         3. 이번에 새로 삽입된 feed_items 모으기
         4. 각 새 글 → ip_id 구독자의 device_tokens 조회 → FCM 발송
```

### 어댑터 인터페이스
```typescript
interface SourceAdapter {
  fetch(source: Source): Promise<RawItem[]>;
  normalize(raw: RawItem, source: Source): FeedItem; // external_id 생성 포함
}

const adapters = {
  rss:     new RssAdapter(),
  youtube: new YoutubeAdapter(),
  website: new WebsiteAdapter(),
};
```

### 어댑터별 구현 요점
| 어댑터 | fetch 방법 | external_id | 난이도 |
|--------|-----------|-------------|-------|
| RssAdapter | RSS/Atom XML 파싱 | `<guid>` 또는 링크 | 낮음 |
| YoutubeAdapter | YouTube Data API v3, 채널 최신 업로드 | `videoId` | 낮음 |
| WebsiteAdapter | HTML fetch → config의 CSS 선택자로 추출 | url 해시 | 중(사이트마다 다름) |

### 설계 포인트
1. **새 소스 타입 = 어댑터 1개 추가** — 파이프라인은 불변. X·Instagram은
   `XAdapter`·`InstagramAdapter` 추가 후 `adapters` 맵 등록만.
2. **`fetch`(네트워크)와 `normalize`(순수 변환) 분리** — 정규화는 fixture만으로
   테스트 가능.
3. **폴링(풀) 방식** — 대부분 소스에 웹훅이 없어 주기 폴링. 15분은
   지연 vs 차단·비용 절충값이며 소스별 조정 여지를 둔다.
4. **비용/차단 방지** — 요청 간 간격, User-Agent 설정, 실패 시 백오프.
   YouTube는 "채널 최신 업로드"만 최소 호출로 일일 할당량 관리.

## 7. 에러 처리

수집은 외부 의존이므로 실패가 정상. 원칙: **격리 + 자가치유.**

1. **소스별 격리** — 소스 순회 시 각 소스를 `try/catch`로 감싼다. 한 소스 실패가
   전체 폴링을 죽이지 않는다.
2. **소스 헬스 & 자동 비활성화**
   ```
   성공 → last_success_at=now(), consecutive_failures=0
   실패 → consecutive_failures += 1
   consecutive_failures >= 5 → is_active=false (운영자가 확인 후 재활성화)
   ```
3. **발송 실패 처리** — FCM이 토큰 만료(unregistered) 반환 시 해당 device_tokens
   행 삭제. 그 외 일시 오류는 로그 후 다음 사이클에서 자연 재시도.
4. **관측 가능성(최소선)** — Edge Function 로그에 소스별 결과 한 줄:
   `[demon-slayer/youtube] fetched 3, inserted 1`.

## 8. 테스트 전략 (TDD)

구현은 test-driven-development로 진행. 테스트 우선순위:

| 대상 | 방식 | 우선순위 |
|------|------|---------|
| 각 어댑터 `normalize` | 저장된 fixture XML/JSON → 기대 FeedItem 검증 (네트워크 불필요) | 최우선 |
| 중복제거 | 같은 external_id 2번 INSERT → 1개만 저장 | 최우선 |
| 소스 헬스 로직 | 실패 5회 → is_active=false | 중 |
| 푸시 팬아웃 | 새 글 → 구독자 토큰 조회 → FCM 호출(모킹) | 중 |
| 폴링 1사이클(통합) | 가짜 소스로 fetch→저장→푸시 전 과정 | 여유 시 |

`fetch`/`normalize` 분리 덕에 가장 깨지기 쉬운 변환 로직을 네트워크 없이 fixture로
검증한다. 외부 API·FCM은 모킹.

## 9. 사용자가 새로 학습할 항목

| 항목 | 학습 내용 | 난이도 |
|------|----------|-------|
| Collector | Edge Function 작성(TypeScript), RSS/HTTP 처리 | 중 |
| Scheduler | pg_cron SQL 1줄 + cron 표기법 | 하 |
| FCM | Flutter 토큰 저장 + 서버 HTTP 발송 + iOS APNs 인증서 1회 설정 | 중 |
| Admin | 없음 (Supabase 대시보드 사용) | — |
| Flutter / Supabase | 기존 경험 보유 | — |

## 10. 구현 순서 (제안)

1. 데이터 모델 마이그레이션 (테이블 6개 + 제약)
2. RssAdapter + normalize TDD → Collector 골격 (fetch→normalize→중복제거 저장)
3. pg_cron으로 Collector 스케줄링
4. YoutubeAdapter, WebsiteAdapter 추가
5. Flutter: 인증 → IP 구독 화면 → 통합 피드 화면
6. FCM: 토큰 저장(앱) + 푸시 팬아웃(Collector) + iOS 설정
7. 소스 헬스/자동 비활성화 + 로그
8. 운영자가 Supabase 대시보드로 초기 IP·소스 시드 등록

## 11. 향후 확장 (MVP 이후)

- X / Instagram 어댑터 (유료 API 또는 대체 수집 경로 검토)
- 교차 소스 중복 묶기 (텍스트 유사도)
- 별도 Admin 웹 페이지
- 검색·태그·개인화 추천
- 자체 호스팅 파이프라인으로 확장 (전용 서버·큐·워커)

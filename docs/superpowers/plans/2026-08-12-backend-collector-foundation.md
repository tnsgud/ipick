# iPick 백엔드 기반 (데이터 모델 + RSS 수집 파이프라인) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 운영자가 등록한 소스를 주기적으로 폴링해 RSS 글을 수집·정규화·중복제거하여 `feed_items`에 저장하는, 단독으로 동작·테스트 가능한 백엔드 파이프라인을 만든다.

**Architecture:** Supabase(Postgres)에 핵심 스키마를 두고, Supabase Edge Function(Deno/TypeScript)이 어댑터 패턴으로 소스를 수집한다. 소스 종류별 어댑터(`fetch`→`parse`→`normalize`)는 순수 함수로 분리해 네트워크 없이 테스트하고, 중복제거는 DB의 `UNIQUE(source_id, external_id)` 제약으로 강제한다. 소스별 실패는 격리되며 연속 5회 실패 시 자동 비활성화된다. pg_cron이 15분마다 함수를 호출한다.

**Tech Stack:** Supabase CLI, Postgres, Deno, TypeScript, `@supabase/supabase-js` v2, `@mikaelporttila/rss` (RSS 파싱), Deno test runner, pg_cron + pg_net.

## Global Constraints

- Edge Function 런타임은 **Deno + TypeScript** 고정. Node 전용 API 사용 금지.
- 중복제거는 애플리케이션이 아니라 **DB 제약** `UNIQUE(source_id, external_id)`로 보장. 삽입은 항상 conflict-ignore.
- 수집 순회는 **소스별 `try/catch`로 격리** — 한 소스 실패가 전체를 중단시키지 않는다.
- 소스 헬스: 성공 시 `consecutive_failures=0`·`last_success_at=now`; 실패 시 `consecutive_failures += 1`; **`consecutive_failures >= 5`이면 `is_active=false`**.
- 폴링 주기 **15분** (`*/15 * * * *`).
- **어댑터 패턴**: 새 소스 타입 추가 = 어댑터 하나 추가, 오케스트레이터/파이프라인 무변경.
- **TDD**: 각 태스크는 실패하는 테스트 → 최소 구현 → 통과 → 커밋. `normalize`와 중복제거를 최우선으로 테스트.
- **범위 밖(다음 계획)**: 푸시 팬아웃(FCM), `subscriptions`/`device_tokens` 테이블, Flutter 앱. 이 계획의 오케스트레이터는 "새 글 저장 + 헬스 갱신"까지만 하고, 새로 삽입된 항목을 반환값으로 노출해 이후 계획이 소비하도록 둔다.
- 색상/디자인 토큰은 무관 (이 계획은 순수 백엔드).

---

## File Structure

```
supabase/
  config.toml                         # supabase init 생성물
  migrations/
    0001_core_schema.sql              # categories, ips, sources, feed_items + 제약 + 인덱스 + RLS
    0002_seed_dev.sql                 # 개발용 시드 (category/ip/source 1건씩)
    0003_schedule_collect.sql         # pg_cron + pg_net로 collect 함수 15분 스케줄
  functions/
    collect/
      deno.json                       # import map
      types.ts                        # Source, RawItem, FeedItem, HealthUpdate, SourceAdapter
      hash.ts                         # external_id 폴백용 순수 해시
      health.ts                       # nextHealth() 순수 함수
      adapters/
        rss.ts                        # parseRss(), RssAdapter { fetch, normalize }
      db.ts                           # getActiveSources, insertFeedItems, applyHealth
      collector.ts                    # runCollector() 오케스트레이터
      index.ts                        # Deno.serve 엔트리
      fixtures/
        sample_rss.xml                # 테스트용 RSS 고정 샘플
      hash_test.ts
      health_test.ts
      adapters/rss_test.ts
      db_test.ts                      # 통합(로컬 supabase 필요)
      collector_test.ts              # 통합(로컬 supabase 필요)
```

**책임 분리 원칙:** 순수 로직(`hash`, `health`, `parseRss`, `normalize`)은 네트워크·DB 없이 테스트한다. DB 접근(`db.ts`)과 오케스트레이터(`collector.ts`)는 주입된 클라이언트로 통합 테스트한다. 엣지 엔트리(`index.ts`)는 얇게 유지한다.

---

## Task 1: 프로젝트 스캐폴딩 & 로컬 Supabase 기동

**Files:**
- Create: `supabase/config.toml` (CLI 생성)
- Create: `.gitignore`
- Create: `README.md` (최소)

**Interfaces:**
- Consumes: 없음 (최초 태스크)
- Produces: 동작하는 로컬 Supabase 스택(`supabase start`), Deno 설치 확인. 이후 모든 태스크가 이 환경에 의존.

- [ ] **Step 1: 도구 설치 확인**

Run:
```bash
supabase --version && deno --version
```
Expected: 두 버전이 출력됨. 없으면 설치 —
```bash
brew install supabase/tap/supabase
brew install deno
```

- [ ] **Step 2: Supabase 프로젝트 초기화**

Run (프로젝트 루트에서):
```bash
supabase init
```
Expected: `supabase/config.toml` 생성. 프롬프트가 나오면 기본값 수락.

- [ ] **Step 3: `.gitignore` 작성**

Create `.gitignore`:
```gitignore
# Supabase
supabase/.branches
supabase/.temp
.env
.env.local

# Deno
.deno/
```

- [ ] **Step 4: 로컬 스택 기동 및 확인**

Run:
```bash
supabase start
```
Expected: 로컬 스택이 뜨고 `API URL`, `service_role key` 등이 출력됨. **이 출력의 `service_role key`와 `API URL`(기본 `http://127.0.0.1:54321`)을 메모** — 통합 테스트(Task 7~9)에서 사용.

- [ ] **Step 5: 최소 README 작성 & 커밋**

Create `README.md`:
```markdown
# iPick Backend

팬덤 발매·굿즈 알림 수집 파이프라인 (Supabase + Deno Edge Functions).

## 개발
- `supabase start` — 로컬 스택 기동
- `supabase db reset` — 마이그레이션 재적용 + 시드
- `deno test supabase/functions/collect/` — 테스트
```

Run:
```bash
git add -A && git commit -m "chore: scaffold supabase project and local stack"
```

---

## Task 2: 핵심 스키마 마이그레이션

**Files:**
- Create: `supabase/migrations/0001_core_schema.sql`

**Interfaces:**
- Consumes: 로컬 Supabase (Task 1)
- Produces: 테이블 `categories`, `ips`, `sources`, `feed_items`. 컬럼/제약은 아래 SQL이 계약이다. 특히 `feed_items UNIQUE(source_id, external_id)`, `sources` 헬스 컬럼(`is_active`, `last_polled_at`, `last_success_at`, `consecutive_failures`)을 이후 태스크가 의존.

- [ ] **Step 1: 마이그레이션 파일 작성**

Create `supabase/migrations/0001_core_schema.sql`:
```sql
-- 확장
create extension if not exists "pgcrypto";

-- 대분류
create table categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default now()
);

-- 팬덤 대상 IP
create table ips (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references categories(id) on delete restrict,
  name text not null,
  slug text not null unique,
  description text,
  thumbnail_url text,
  created_at timestamptz not null default now()
);

-- 소스 타입
create type source_type as enum ('rss', 'youtube', 'website', 'x');

-- IP별 공식 소스 화이트리스트
create table sources (
  id uuid primary key default gen_random_uuid(),
  ip_id uuid not null references ips(id) on delete cascade,
  type source_type not null,
  url text not null,
  config jsonb,
  is_active boolean not null default true,
  last_polled_at timestamptz,
  last_success_at timestamptz,
  consecutive_failures int not null default 0,
  created_at timestamptz not null default now()
);
create index sources_active_idx on sources (is_active) where is_active;

-- 정규화된 소식
create table feed_items (
  id uuid primary key default gen_random_uuid(),
  ip_id uuid not null references ips(id) on delete cascade,
  source_id uuid not null references sources(id) on delete cascade,
  external_id text not null,
  title text not null,
  summary text,
  url text not null,
  image_url text,
  item_type text,
  buy_url text,
  published_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (source_id, external_id)          -- 중복제거의 핵심
);
create index feed_items_ip_published_idx on feed_items (ip_id, published_at desc);

-- RLS: 서비스롤(수집기)은 RLS 우회. 클라이언트 노출 대비 안전 기본값.
alter table categories enable row level security;
alter table ips enable row level security;
alter table sources enable row level security;
alter table feed_items enable row level security;

-- 공개 읽기: 카탈로그와 피드는 익명 조회 허용 (앱이 이후 소비)
create policy "categories readable" on categories for select using (true);
create policy "ips readable" on ips for select using (true);
create policy "feed_items readable" on feed_items for select using (true);
-- sources: 정책 없음 → 익명 접근 거부. 서비스롤만 접근.
```

- [ ] **Step 2: 마이그레이션 적용**

Run:
```bash
supabase db reset
```
Expected: 마이그레이션이 오류 없이 적용됨(시드 파일은 아직 없음).

- [ ] **Step 3: 스키마 확인**

Run:
```bash
supabase db reset && psql "$(supabase status -o env | grep DB_URL | cut -d= -f2- | tr -d '\"')" -c "\d feed_items"
```
Expected: `feed_items` 정의에 `unique (source_id, external_id)` 제약이 보임. (psql이 없으면 Supabase Studio `http://127.0.0.1:54323`의 Table editor에서 확인.)

- [ ] **Step 4: 커밋**

Run:
```bash
git add supabase/migrations/0001_core_schema.sql
git commit -m "feat: core schema (categories, ips, sources, feed_items) with dedup constraint and RLS"
```

---

## Task 3: 개발용 시드

**Files:**
- Create: `supabase/migrations/0002_seed_dev.sql`

**Interfaces:**
- Consumes: Task 2 스키마
- Produces: 알려진 `sources.id`가 있는 활성 RSS 소스 1건 (end-to-end 검증용). 시드 IP slug `demon-slayer`, 소스 URL은 안정적인 공개 RSS.

- [ ] **Step 1: 시드 파일 작성**

Create `supabase/migrations/0002_seed_dev.sql`:
```sql
-- 개발용 시드. 운영 배포 시엔 별도 관리(운영자 대시보드 입력).
insert into categories (id, name, slug) values
  ('11111111-1111-1111-1111-111111111111', '애니메', 'anime');

insert into ips (id, category_id, name, slug) values
  ('22222222-2222-2222-2222-222222222222',
   '11111111-1111-1111-1111-111111111111',
   '테스트 IP', 'demon-slayer');

-- 안정적인 공개 RSS를 스모크 테스트 소스로 사용 (키 불필요)
insert into sources (id, ip_id, type, url, is_active) values
  ('33333333-3333-3333-3333-333333333333',
   '22222222-2222-2222-2222-222222222222',
   'rss', 'https://www.reddit.com/r/anime/.rss', true);
```

- [ ] **Step 2: 적용 및 확인**

Run:
```bash
supabase db reset
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2- | tr -d '\"')" -c "select id, type, url, is_active from sources;"
```
Expected: 시드된 RSS 소스 1행이 보임.

- [ ] **Step 3: 커밋**

Run:
```bash
git add supabase/migrations/0002_seed_dev.sql
git commit -m "chore: dev seed with one active RSS source"
```

---

## Task 4: 타입 정의 & import map

**Files:**
- Create: `supabase/functions/collect/deno.json`
- Create: `supabase/functions/collect/types.ts`

**Interfaces:**
- Consumes: 없음
- Produces: 아래 타입들. 모든 후속 태스크가 이 시그니처를 사용한다.
  - `SourceType = "rss" | "youtube" | "website" | "x"`
  - `Source`, `RawItem`, `FeedItem`, `HealthUpdate`, `SourceAdapter`

- [ ] **Step 1: import map 작성**

Create `supabase/functions/collect/deno.json`:
```json
{
  "imports": {
    "@supabase/supabase-js": "jsr:@supabase/supabase-js@2",
    "rss": "jsr:@mikaelporttila/rss@1",
    "std/assert": "jsr:@std/assert@1"
  }
}
```

- [ ] **Step 2: 타입 파일 작성**

Create `supabase/functions/collect/types.ts`:
```typescript
export type SourceType = "rss" | "youtube" | "website" | "x";

/** DB의 sources 행 (수집에 필요한 필드) */
export interface Source {
  id: string;
  ip_id: string;
  type: SourceType;
  url: string;
  config: Record<string, unknown> | null;
  is_active: boolean;
  last_polled_at: string | null;
  last_success_at: string | null;
  consecutive_failures: number;
}

/** 소스에서 긁어온 원본 항목 (파싱 결과, 정규화 전) */
export interface RawItem {
  guid: string | null;
  link: string | null;
  title: string;
  summary: string | null;
  imageUrl: string | null;
  publishedAt: string | null; // ISO 8601 또는 null
}

/** DB feed_items에 삽입할 정규화 형태 */
export interface FeedItem {
  ip_id: string;
  source_id: string;
  external_id: string;
  title: string;
  summary: string | null;
  url: string;
  image_url: string | null;
  published_at: string; // ISO 8601
}

/** 소스 헬스 갱신 결과 */
export interface HealthUpdate {
  last_polled_at: string;
  last_success_at?: string;
  consecutive_failures: number;
  is_active: boolean;
}

/** 소스 종류별 어댑터. 새 타입 추가 = 이 인터페이스 구현 하나 추가. */
export interface SourceAdapter {
  /** 네트워크 접속 + 파싱 → 원본 항목들. httpGet 주입으로 테스트 가능. */
  fetch(source: Source, httpGet?: typeof globalThis.fetch): Promise<RawItem[]>;
  /** 순수 변환: 원본 → FeedItem (external_id 생성 포함) */
  normalize(raw: RawItem, source: Source): FeedItem;
}
```

- [ ] **Step 3: 타입 컴파일 확인**

Run:
```bash
deno check supabase/functions/collect/types.ts
```
Expected: 오류 없음.

- [ ] **Step 4: 커밋**

Run:
```bash
git add supabase/functions/collect/deno.json supabase/functions/collect/types.ts
git commit -m "feat: collector core types and import map"
```

---

## Task 5: external_id 폴백 해시 (순수)

**Files:**
- Create: `supabase/functions/collect/hash.ts`
- Test: `supabase/functions/collect/hash_test.ts`

**Interfaces:**
- Consumes: 없음
- Produces: `stableHash(input: string): string` — 결정적, 짧은 16진 문자열. guid·link가 없을 때 external_id 폴백에 사용.

- [ ] **Step 1: 실패하는 테스트 작성**

Create `supabase/functions/collect/hash_test.ts`:
```typescript
import { assertEquals, assertNotEquals } from "std/assert";
import { stableHash } from "./hash.ts";

Deno.test("stableHash는 같은 입력에 같은 값을 낸다", () => {
  assertEquals(stableHash("hello"), stableHash("hello"));
});

Deno.test("stableHash는 다른 입력에 다른 값을 낸다", () => {
  assertNotEquals(stableHash("hello"), stableHash("world"));
});

Deno.test("stableHash는 비어있지 않은 16진 문자열이다", () => {
  const h = stableHash("anything");
  assertEquals(/^[0-9a-f]+$/.test(h), true);
});
```

- [ ] **Step 2: 실패 확인**

Run:
```bash
deno test supabase/functions/collect/hash_test.ts
```
Expected: FAIL — `./hash.ts` 모듈/`stableHash` 없음.

- [ ] **Step 3: 최소 구현**

Create `supabase/functions/collect/hash.ts`:
```typescript
/** djb2 기반 결정적 해시 → 16진 문자열. 암호학적 용도 아님(중복키 폴백용). */
export function stableHash(input: string): string {
  let h = 5381;
  for (let i = 0; i < input.length; i++) {
    h = ((h << 5) + h + input.charCodeAt(i)) >>> 0; // unsigned 32-bit
  }
  return h.toString(16);
}
```

- [ ] **Step 4: 통과 확인**

Run:
```bash
deno test supabase/functions/collect/hash_test.ts
```
Expected: PASS (3 tests).

- [ ] **Step 5: 커밋**

Run:
```bash
git add supabase/functions/collect/hash.ts supabase/functions/collect/hash_test.ts
git commit -m "feat: stable hash for external_id fallback"
```

---

## Task 6: 소스 헬스 전이 (순수)

**Files:**
- Create: `supabase/functions/collect/health.ts`
- Test: `supabase/functions/collect/health_test.ts`

**Interfaces:**
- Consumes: `Source`, `HealthUpdate` (types.ts)
- Produces: `nextHealth(source: Source, outcome: "success" | "failure", now: string): HealthUpdate`
  - success → `consecutive_failures=0`, `last_success_at=now`, `is_active=true`, `last_polled_at=now`
  - failure → `consecutive_failures = prev+1`, `last_success_at` 유지(미포함), `is_active = (prev+1) < 5`, `last_polled_at=now`

- [ ] **Step 1: 실패하는 테스트 작성**

Create `supabase/functions/collect/health_test.ts`:
```typescript
import { assertEquals } from "std/assert";
import { nextHealth } from "./health.ts";
import type { Source } from "./types.ts";

const NOW = "2026-08-12T00:00:00.000Z";

function makeSource(overrides: Partial<Source> = {}): Source {
  return {
    id: "s1", ip_id: "ip1", type: "rss", url: "http://x", config: null,
    is_active: true, last_polled_at: null, last_success_at: null,
    consecutive_failures: 0, ...overrides,
  };
}

Deno.test("성공 시 실패 카운트 리셋 + last_success 갱신", () => {
  const h = nextHealth(makeSource({ consecutive_failures: 3 }), "success", NOW);
  assertEquals(h.consecutive_failures, 0);
  assertEquals(h.last_success_at, NOW);
  assertEquals(h.last_polled_at, NOW);
  assertEquals(h.is_active, true);
});

Deno.test("실패 시 카운트 증가, 5회 미만이면 활성 유지", () => {
  const h = nextHealth(makeSource({ consecutive_failures: 3 }), "failure", NOW);
  assertEquals(h.consecutive_failures, 4);
  assertEquals(h.is_active, true);
  assertEquals(h.last_success_at, undefined); // 유지(갱신 안 함)
});

Deno.test("실패로 5회 도달 시 자동 비활성화", () => {
  const h = nextHealth(makeSource({ consecutive_failures: 4 }), "failure", NOW);
  assertEquals(h.consecutive_failures, 5);
  assertEquals(h.is_active, false);
});
```

- [ ] **Step 2: 실패 확인**

Run:
```bash
deno test supabase/functions/collect/health_test.ts
```
Expected: FAIL — `nextHealth` 없음.

- [ ] **Step 3: 최소 구현**

Create `supabase/functions/collect/health.ts`:
```typescript
import type { Source, HealthUpdate } from "./types.ts";

const MAX_FAILURES = 5;

export function nextHealth(
  source: Source,
  outcome: "success" | "failure",
  now: string,
): HealthUpdate {
  if (outcome === "success") {
    return {
      last_polled_at: now,
      last_success_at: now,
      consecutive_failures: 0,
      is_active: true,
    };
  }
  const failures = source.consecutive_failures + 1;
  return {
    last_polled_at: now,
    consecutive_failures: failures,
    is_active: failures < MAX_FAILURES,
  };
}
```

- [ ] **Step 4: 통과 확인**

Run:
```bash
deno test supabase/functions/collect/health_test.ts
```
Expected: PASS (3 tests).

- [ ] **Step 5: 커밋**

Run:
```bash
git add supabase/functions/collect/health.ts supabase/functions/collect/health_test.ts
git commit -m "feat: source health transition (auto-disable at 5 failures)"
```

---

## Task 7: RSS 어댑터 — parse & normalize (순수) + fetch(주입)

**Files:**
- Create: `supabase/functions/collect/adapters/rss.ts`
- Create: `supabase/functions/collect/fixtures/sample_rss.xml`
- Test: `supabase/functions/collect/adapters/rss_test.ts`

**Interfaces:**
- Consumes: `Source`, `RawItem`, `FeedItem`, `SourceAdapter` (types.ts), `stableHash` (hash.ts)
- Produces:
  - `parseRss(xml: string): Promise<RawItem[]>` — 순수(문자열→항목)
  - `RssAdapter: SourceAdapter` — `fetch(source, httpGet)`는 `httpGet(url)` 후 `parseRss`; `normalize(raw, source)`는 external_id = `guid ?? link ?? stableHash(title+publishedAt)`

- [ ] **Step 1: 고정 샘플 RSS 작성**

Create `supabase/functions/collect/fixtures/sample_rss.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <link>https://example.com</link>
    <item>
      <title>신제품 아크릴 스탠드 발매</title>
      <link>https://example.com/goods/1</link>
      <guid>goods-1</guid>
      <description>한정 아크릴 스탠드 6종</description>
      <pubDate>Mon, 11 Aug 2026 09:00:00 GMT</pubDate>
    </item>
    <item>
      <title>예약 안내</title>
      <link>https://example.com/goods/2</link>
      <description>예약 시작</description>
      <pubDate>Mon, 11 Aug 2026 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
```

- [ ] **Step 2: 실패하는 테스트 작성**

Create `supabase/functions/collect/adapters/rss_test.ts`:
```typescript
import { assertEquals } from "std/assert";
import { parseRss, RssAdapter } from "./rss.ts";
import type { Source } from "../types.ts";

const source: Source = {
  id: "src-1", ip_id: "ip-1", type: "rss", url: "https://feed",
  config: null, is_active: true, last_polled_at: null,
  last_success_at: null, consecutive_failures: 0,
};

const xml = await Deno.readTextFile(
  new URL("../fixtures/sample_rss.xml", import.meta.url),
);

Deno.test("parseRss는 항목 수만큼 RawItem을 낸다", async () => {
  const items = await parseRss(xml);
  assertEquals(items.length, 2);
  assertEquals(items[0].title, "신제품 아크릴 스탠드 발매");
  assertEquals(items[0].guid, "goods-1");
  assertEquals(items[0].link, "https://example.com/goods/1");
});

Deno.test("normalize: guid가 있으면 external_id로 사용", () => {
  const raw = { guid: "goods-1", link: "https://x/1", title: "t", summary: null, imageUrl: null, publishedAt: "2026-08-11T09:00:00.000Z" };
  const fi = RssAdapter.normalize(raw, source);
  assertEquals(fi.external_id, "goods-1");
  assertEquals(fi.ip_id, "ip-1");
  assertEquals(fi.source_id, "src-1");
  assertEquals(fi.url, "https://x/1");
});

Deno.test("normalize: guid 없으면 link를 external_id로 사용", () => {
  const raw = { guid: null, link: "https://x/2", title: "t2", summary: null, imageUrl: null, publishedAt: null };
  const fi = RssAdapter.normalize(raw, source);
  assertEquals(fi.external_id, "https://x/2");
});

Deno.test("normalize: guid·link 모두 없으면 해시 폴백", () => {
  const raw = { guid: null, link: null, title: "제목", summary: null, imageUrl: null, publishedAt: "2026-08-11T09:00:00.000Z" };
  const fi = RssAdapter.normalize(raw, source);
  assertEquals(/^[0-9a-f]+$/.test(fi.external_id), true);
  assertEquals(fi.url, ""); // link 없으면 빈 문자열
});

Deno.test("fetch는 주입된 httpGet의 응답을 파싱한다", async () => {
  const fakeGet = ((_url: string) =>
    Promise.resolve(new Response(xml, { status: 200 }))) as unknown as typeof fetch;
  const items = await RssAdapter.fetch(source, fakeGet);
  assertEquals(items.length, 2);
});
```

- [ ] **Step 3: 실패 확인**

Run:
```bash
deno test --allow-read supabase/functions/collect/adapters/rss_test.ts
```
Expected: FAIL — `./rss.ts` 없음.

- [ ] **Step 4: 최소 구현**

Create `supabase/functions/collect/adapters/rss.ts`:
```typescript
import { parseFeed } from "rss";
import type { Source, RawItem, FeedItem, SourceAdapter } from "../types.ts";
import { stableHash } from "../hash.ts";

/** RSS/Atom XML 문자열 → RawItem[] (순수) */
export async function parseRss(xml: string): Promise<RawItem[]> {
  const feed = await parseFeed(xml);
  return (feed.entries ?? []).map((e): RawItem => {
    const link = e.links?.[0]?.href ?? null;
    const published = e.published ?? e.publishedRaw ?? null;
    return {
      guid: e.id ?? null,
      link,
      title: e.title?.value ?? "(제목 없음)",
      summary: e.description?.value ?? null,
      imageUrl: e.attachments?.[0]?.url ?? null,
      publishedAt: published ? new Date(published).toISOString() : null,
    };
  });
}

export const RssAdapter: SourceAdapter = {
  async fetch(source: Source, httpGet: typeof globalThis.fetch = globalThis.fetch) {
    const res = await httpGet(source.url, {
      headers: { "User-Agent": "iPick-collector/0.1" },
    });
    if (!res.ok) throw new Error(`RSS fetch ${res.status} for ${source.url}`);
    return parseRss(await res.text());
  },

  normalize(raw: RawItem, source: Source): FeedItem {
    const external_id =
      raw.guid ?? raw.link ?? stableHash(raw.title + (raw.publishedAt ?? ""));
    return {
      ip_id: source.ip_id,
      source_id: source.id,
      external_id,
      title: raw.title,
      summary: raw.summary,
      url: raw.link ?? "",
      image_url: raw.imageUrl,
      published_at: raw.publishedAt ?? new Date().toISOString(),
    };
  },
};
```

> 참고: `@mikaelporttila/rss`의 엔트리 필드명(`e.id`, `e.links`, `e.title.value` 등)은 라이브러리 버전에 따라 약간 다를 수 있다. Step 5에서 실패하면 `console.log(JSON.stringify(feed.entries[0]))`로 실제 형태를 확인해 매핑을 맞춘다.

- [ ] **Step 5: 통과 확인**

Run:
```bash
deno test --allow-read supabase/functions/collect/adapters/rss_test.ts
```
Expected: PASS (5 tests).

- [ ] **Step 6: 커밋**

Run:
```bash
git add supabase/functions/collect/adapters/rss.ts supabase/functions/collect/adapters/rss_test.ts supabase/functions/collect/fixtures/sample_rss.xml
git commit -m "feat: RSS adapter (parse, normalize with external_id, injectable fetch)"
```

---

## Task 8: DB 계층 — 활성 소스 조회 / 중복제거 삽입 / 헬스 반영 (통합)

**Files:**
- Create: `supabase/functions/collect/db.ts`
- Test: `supabase/functions/collect/db_test.ts`

**Interfaces:**
- Consumes: `Source`, `FeedItem`, `HealthUpdate` (types.ts). `@supabase/supabase-js`의 `SupabaseClient`.
- Produces:
  - `getActiveSources(supabase): Promise<Source[]>`
  - `insertFeedItems(supabase, items: FeedItem[]): Promise<number>` — `onConflict: "source_id,external_id"`, `ignoreDuplicates: true`, `.select()`로 **새로 삽입된 행 수** 반환
  - `applyHealth(supabase, sourceId: string, h: HealthUpdate): Promise<void>`

> 이 테스트는 **로컬 Supabase가 떠 있어야** 한다(`supabase start`). 환경변수 `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`를 Task 1 Step 4 출력값으로 export.

- [ ] **Step 1: 테스트용 환경변수 준비**

Run (값은 `supabase status`에서 확인):
```bash
export SUPABASE_URL="http://127.0.0.1:54321"
export SUPABASE_SERVICE_ROLE_KEY="$(supabase status -o env | grep SERVICE_ROLE_KEY | cut -d= -f2- | tr -d '\"')"
supabase db reset   # 시드된 소스 상태로 초기화
```

- [ ] **Step 2: 실패하는 테스트 작성**

Create `supabase/functions/collect/db_test.ts`:
```typescript
import { assertEquals } from "std/assert";
import { createClient } from "@supabase/supabase-js";
import { getActiveSources, insertFeedItems, applyHealth } from "./db.ts";
import type { FeedItem } from "./types.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const SEED_SOURCE = "33333333-3333-3333-3333-333333333333";
const SEED_IP = "22222222-2222-2222-2222-222222222222";

function item(external_id: string): FeedItem {
  return {
    ip_id: SEED_IP, source_id: SEED_SOURCE, external_id,
    title: "t", summary: null, url: "https://x/" + external_id,
    image_url: null, published_at: "2026-08-11T09:00:00.000Z",
  };
}

Deno.test("getActiveSources는 시드된 활성 RSS 소스를 포함한다", async () => {
  const sources = await getActiveSources(supabase);
  const seed = sources.find((s) => s.id === SEED_SOURCE);
  assertEquals(seed?.type, "rss");
  assertEquals(seed?.is_active, true);
});

Deno.test("insertFeedItems는 새 항목만 세고, 재삽입은 0", async () => {
  const first = await insertFeedItems(supabase, [item("dup-1"), item("dup-2")]);
  assertEquals(first, 2);
  const second = await insertFeedItems(supabase, [item("dup-1"), item("dup-2")]);
  assertEquals(second, 0); // UNIQUE(source_id, external_id)로 중복 무시
});

Deno.test("applyHealth는 소스 헬스를 갱신한다", async () => {
  await applyHealth(supabase, SEED_SOURCE, {
    last_polled_at: "2026-08-12T00:00:00.000Z",
    consecutive_failures: 2,
    is_active: true,
  });
  const sources = await getActiveSources(supabase);
  const seed = sources.find((s) => s.id === SEED_SOURCE);
  assertEquals(seed?.consecutive_failures, 2);
});
```

- [ ] **Step 3: 실패 확인**

Run:
```bash
deno test --allow-net --allow-env supabase/functions/collect/db_test.ts
```
Expected: FAIL — `./db.ts` 없음.

- [ ] **Step 4: 최소 구현**

Create `supabase/functions/collect/db.ts`:
```typescript
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Source, FeedItem, HealthUpdate } from "./types.ts";

const SOURCE_COLUMNS =
  "id, ip_id, type, url, config, is_active, last_polled_at, last_success_at, consecutive_failures";

export async function getActiveSources(
  supabase: SupabaseClient,
): Promise<Source[]> {
  const { data, error } = await supabase
    .from("sources")
    .select(SOURCE_COLUMNS)
    .eq("is_active", true);
  if (error) throw new Error(`getActiveSources: ${error.message}`);
  return (data ?? []) as Source[];
}

/** 새로 삽입된 행 수를 반환. 중복(UNIQUE 충돌)은 무시. */
export async function insertFeedItems(
  supabase: SupabaseClient,
  items: FeedItem[],
): Promise<number> {
  if (items.length === 0) return 0;
  const { data, error } = await supabase
    .from("feed_items")
    .upsert(items, { onConflict: "source_id,external_id", ignoreDuplicates: true })
    .select("id");
  if (error) throw new Error(`insertFeedItems: ${error.message}`);
  return data?.length ?? 0;
}

export async function applyHealth(
  supabase: SupabaseClient,
  sourceId: string,
  h: HealthUpdate,
): Promise<void> {
  const { error } = await supabase.from("sources").update(h).eq("id", sourceId);
  if (error) throw new Error(`applyHealth: ${error.message}`);
}
```

- [ ] **Step 5: 통과 확인**

Run:
```bash
supabase db reset
deno test --allow-net --allow-env supabase/functions/collect/db_test.ts
```
Expected: PASS (3 tests).

- [ ] **Step 6: 커밋**

Run:
```bash
git add supabase/functions/collect/db.ts supabase/functions/collect/db_test.ts
git commit -m "feat: db layer (active sources, dedup insert, health apply)"
```

---

## Task 9: 오케스트레이터 runCollector (통합)

**Files:**
- Create: `supabase/functions/collect/collector.ts`
- Test: `supabase/functions/collect/collector_test.ts`

**Interfaces:**
- Consumes: `getActiveSources`, `insertFeedItems`, `applyHealth` (db.ts); `nextHealth` (health.ts); `RssAdapter` (adapters/rss.ts); 타입들.
- Produces:
  - `type AdapterMap = Record<SourceType, SourceAdapter>`
  - `runCollector(supabase, adapters: AdapterMap, httpGet, now: string): Promise<CollectResult>`
  - `interface CollectResult { perSource: Array<{ sourceId: string; inserted: number; ok: boolean; error?: string }>; newItems: FeedItem[] }`
  - 동작: 활성 소스 순회 → 소스별 `try/catch` 격리 → 어댑터로 fetch+normalize → `insertFeedItems` → `nextHealth(success)` 반영. 예외 시 `nextHealth(failure)` 반영 + 결과에 error 기록. `newItems`에 이번에 삽입된 항목 누적(푸시 계획이 소비).

- [ ] **Step 1: 실패하는 테스트 작성**

Create `supabase/functions/collect/collector_test.ts`:
```typescript
import { assertEquals } from "std/assert";
import { createClient } from "@supabase/supabase-js";
import { runCollector, type AdapterMap } from "./collector.ts";
import { RssAdapter } from "./adapters/rss.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const NOW = "2026-08-12T00:00:00.000Z";
const xml = await Deno.readTextFile(
  new URL("./fixtures/sample_rss.xml", import.meta.url),
);
const adapters = { rss: RssAdapter } as unknown as AdapterMap;

Deno.test("정상 소스: 새 항목 삽입 + 성공 헬스", async () => {
  const okGet = ((_u: string) =>
    Promise.resolve(new Response(xml, { status: 200 }))) as unknown as typeof fetch;
  const res = await runCollector(supabase, adapters, okGet, NOW);
  const seed = res.perSource.find((p) => p.ok);
  assertEquals(seed?.inserted, 2);      // 샘플 RSS 항목 2개
  assertEquals(res.newItems.length >= 2, true);
});

Deno.test("실패 소스는 격리되고 실패 헬스로 기록된다", async () => {
  const badGet = ((_u: string) =>
    Promise.resolve(new Response("nope", { status: 500 }))) as unknown as typeof fetch;
  const res = await runCollector(supabase, adapters, badGet, NOW);
  assertEquals(res.perSource.every((p) => p.ok === false), true);
  assertEquals(res.perSource[0].error !== undefined, true);
});
```

- [ ] **Step 2: 실패 확인**

Run:
```bash
supabase db reset
deno test --allow-net --allow-env --allow-read supabase/functions/collect/collector_test.ts
```
Expected: FAIL — `./collector.ts` 없음.

- [ ] **Step 3: 최소 구현**

Create `supabase/functions/collect/collector.ts`:
```typescript
import type { SupabaseClient } from "@supabase/supabase-js";
import type { SourceType, SourceAdapter, FeedItem } from "./types.ts";
import { getActiveSources, insertFeedItems, applyHealth } from "./db.ts";
import { nextHealth } from "./health.ts";

export type AdapterMap = Record<SourceType, SourceAdapter>;

export interface CollectResult {
  perSource: Array<{ sourceId: string; inserted: number; ok: boolean; error?: string }>;
  newItems: FeedItem[];
}

export async function runCollector(
  supabase: SupabaseClient,
  adapters: AdapterMap,
  httpGet: typeof globalThis.fetch,
  now: string,
): Promise<CollectResult> {
  const sources = await getActiveSources(supabase);
  const result: CollectResult = { perSource: [], newItems: [] };

  for (const source of sources) {
    try {
      const adapter = adapters[source.type];
      if (!adapter) throw new Error(`no adapter for type ${source.type}`);

      const raw = await adapter.fetch(source, httpGet);
      const items = raw.map((r) => adapter.normalize(r, source));
      const inserted = await insertFeedItems(supabase, items);

      await applyHealth(supabase, source.id, nextHealth(source, "success", now));
      // 새로 삽입된 개수만큼 반영(간단화: inserted>0이면 items를 노출)
      if (inserted > 0) result.newItems.push(...items);
      result.perSource.push({ sourceId: source.id, inserted, ok: true });
      console.log(`[${source.id}/${source.type}] inserted ${inserted}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      await applyHealth(supabase, source.id, nextHealth(source, "failure", now));
      result.perSource.push({ sourceId: source.id, inserted: 0, ok: false, error: msg });
      console.error(`[${source.id}/${source.type}] FAILED: ${msg}`);
    }
  }
  return result;
}
```

- [ ] **Step 4: 통과 확인**

Run:
```bash
supabase db reset
deno test --allow-net --allow-env --allow-read supabase/functions/collect/collector_test.ts
```
Expected: PASS (2 tests).

- [ ] **Step 5: 커밋**

Run:
```bash
git add supabase/functions/collect/collector.ts supabase/functions/collect/collector_test.ts
git commit -m "feat: runCollector orchestrator with per-source isolation"
```

---

## Task 10: Edge Function 엔트리 + 로컬 end-to-end

**Files:**
- Create: `supabase/functions/collect/index.ts`

**Interfaces:**
- Consumes: `runCollector`, `AdapterMap` (collector.ts); `RssAdapter` (adapters/rss.ts); `createClient`.
- Produces: HTTP 엔드포인트. POST 시 수집 1사이클 실행 후 `CollectResult` JSON 반환. 환경변수 `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`(로컬 서브 함수 런타임이 자동 주입)를 사용.

- [ ] **Step 1: 엔트리 작성**

Create `supabase/functions/collect/index.ts`:
```typescript
import { createClient } from "@supabase/supabase-js";
import { runCollector, type AdapterMap } from "./collector.ts";
import { RssAdapter } from "./adapters/rss.ts";

const adapters = { rss: RssAdapter } as unknown as AdapterMap;

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  try {
    const result = await runCollector(
      supabase, adapters, globalThis.fetch, new Date().toISOString(),
    );
    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }
});
```

- [ ] **Step 2: 함수 로컬 서브 (별도 터미널)**

Run:
```bash
supabase functions serve collect --no-verify-jwt
```
Expected: `collect` 함수가 로컬에서 서브됨.

- [ ] **Step 3: end-to-end 호출 (실제 RSS)**

먼저 DB를 시드 상태로 리셋(다른 터미널):
```bash
supabase db reset
```
그다음 함수 호출:
```bash
curl -s -X POST http://127.0.0.1:54321/functions/v1/collect | jq
```
Expected: `perSource`에 시드 소스가 `ok:true`로 나오고 `inserted`가 1 이상(레딧 RSS의 실제 글 수). 재호출하면 같은 소스의 `inserted`가 0(중복제거 동작).

- [ ] **Step 4: DB에 저장 확인**

Run:
```bash
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2- | tr -d '\"')" -c "select count(*) from feed_items;"
```
Expected: 0보다 큰 수.

- [ ] **Step 5: 커밋**

Run:
```bash
git add supabase/functions/collect/index.ts
git commit -m "feat: collect edge function entry with end-to-end collection"
```

---

## Task 11: pg_cron 15분 스케줄 (배포 구성)

**Files:**
- Create: `supabase/migrations/0003_schedule_collect.sql`

**Interfaces:**
- Consumes: 배포된 `collect` 함수 URL, 서비스 롤 키(Vault 보관).
- Produces: 15분마다 `collect`를 호출하는 cron 잡.

> 로컬에서는 pg_cron→엣지 호출을 端到端 검증하기 어렵다(함수는 원격 URL 필요). 이 태스크는 **배포 구성**이며, 검증은 `cron.job` 등록 확인 + 배포 후 로그로 한다.

- [ ] **Step 1: Vault에 서비스 키 저장 (Supabase Studio 또는 SQL)**

Run (로컬/원격 DB에서, 실제 키로 치환):
```sql
select vault.create_secret('REPLACE_WITH_SERVICE_ROLE_KEY', 'collect_service_key');
```
Expected: 시크릿 생성. (Studio → Project Settings → Vault에서도 가능.)

- [ ] **Step 2: 스케줄 마이그레이션 작성**

Create `supabase/migrations/0003_schedule_collect.sql`:
```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- <PROJECT_REF>는 배포 프로젝트의 ref로 치환 (원격 배포 시).
-- 로컬에서는 이 잡이 로컬 함수 URL을 못 부르므로 실질 동작은 배포 후.
select cron.schedule(
  'collect-sources',
  '*/15 * * * *',
  $$
  select net.http_post(
    url := 'https://<PROJECT_REF>.functions.supabase.co/collect',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'collect_service_key')
    ),
    body := '{}'::jsonb
  );
  $$
);
```

- [ ] **Step 3: 잡 등록 확인**

Run:
```bash
supabase db reset
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2- | tr -d '\"')" -c "select jobname, schedule from cron.job;"
```
Expected: `collect-sources` / `*/15 * * * *` 행이 보임. (로컬에선 http_post 대상이 원격이라 실제 호출은 실패할 수 있음 — 등록 자체만 확인.)

- [ ] **Step 4: 커밋**

Run:
```bash
git add supabase/migrations/0003_schedule_collect.sql
git commit -m "feat: schedule collect every 15 minutes via pg_cron + pg_net"
```

- [ ] **Step 5: (배포 시) 원격 검증 메모**

배포 후: `supabase functions deploy collect` → `0003` 마이그레이션의 `<PROJECT_REF>`를 실제 값으로 치환해 적용 → 15분 뒤 `select * from cron.job_run_details order by start_time desc limit 5;`로 성공 확인, 함수 로그에서 `inserted N` 확인.

---

## 전체 검증 (완료 기준)

- [ ] `deno test --allow-net --allow-env --allow-read supabase/functions/collect/` 전체 통과
- [ ] `supabase db reset` 후 `curl -X POST .../functions/v1/collect` 1회차 `inserted>0`, 2회차 `inserted=0` (중복제거 확인)
- [ ] 존재하지 않는/오류 소스를 시드에 추가해 호출 시, 그 소스만 `ok:false`이고 나머지는 정상 (격리 확인)
- [ ] 오류 소스를 5회 호출 후 `select is_active from sources where id=...`가 `false` (자동 비활성화 확인)
- [ ] `cron.job`에 `collect-sources` 등록됨

---

## Self-Review Notes (작성자 확인)

- **스펙 커버리지**: 데이터모델(§6 4개 테이블+중복제약+헬스컬럼) ✔, 어댑터 패턴(§7) ✔, fetch/normalize 분리 ✔, 소스별 격리 ✔, 5회 자동 비활성화 ✔, 중복제거 DB 강제 ✔, 15분 cron ✔, TDD normalize·중복제거 최우선 ✔. 범위 밖(푸시·subscriptions·device_tokens·Flutter)은 의도적으로 다음 계획으로 분리.
- **타입 일관성**: `Source`/`RawItem`/`FeedItem`/`HealthUpdate`/`SourceAdapter`는 types.ts에서 1회 정의, 이후 태스크가 동일 시그니처 사용. `insertFeedItems`는 삽입 건수(number) 반환으로 통일.
- **가정/리스크**: `@mikaelporttila/rss` 엔트리 필드명은 버전에 따라 조정 필요할 수 있음(Task 7 참고 메모). pg_cron→엣지 端到端은 배포 후에만 실검증 가능.

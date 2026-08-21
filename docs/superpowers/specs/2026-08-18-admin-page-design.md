# iPick 관리자 페이지 (카테고리/IP/소스 관리) — 설계 문서

- 작성일: 2026-08-18
- 상태: 설계 승인됨 (구현은 사용자가 직접 진행 — 가이드 문서로 전달)
- 분류: 아키텍처(Architectural) — 새 서브시스템(특권 쓰기 경로 신설)

## 1. 배경 & 목적

운영자가 IP별 공식 소스(화이트리스트)를 Supabase Studio 테이블 에디터로 직접 관리해봤으나
불편했다(카테고리→IP→소스로 이어지는 외래키 관계를 raw 테이블 뷰에서 손으로 맞춰야 함).
또한 배포 검증용 임시 소스가 실제로 "카테고리와 무관한 데이터"로 오인되는 일이 있었다 —
소스 관리를 SQL 없이 할 수 있는 화면이 있었다면 더 쉽게 확인·정리했을 것이다.

이 문서는 Flutter 앱 안에 숨겨진 관리자 화면을 추가하는 설계를 다룬다.

## 2. 범위 (Scope)

### 포함
- 카테고리 / IP / 소스 추가·수정·삭제 (핵심 — 지금 SQL로 하던 작업)
- 소스 헬스 확인 (`last_success_at`, `consecutive_failures`, `is_active`)
- 수집된 `feed_items` 미리보기 (읽기 전용)
- 관리자 인증 (Supabase Auth + `admins` 테이블 기반 RLS)

### 제외
- 수동 수집 트리거 버튼 (범위에서 제외하기로 결정)
- 여러 관리자 계정을 위한 역할/권한 세분화 (지금은 솔로 운영 — `admins` 테이블 구조만
  나중에 확장 가능하게 남겨둠)
- 별도 웹 도구/배포 (Flutter 앱 안에 통합하기로 결정)

## 3. 접근 방식

기존 iPick Flutter 앱(Riverpod + supabase_flutter) 안에 **숨겨진** 관리자 화면을 추가한다.
별도 웹 도구를 만드는 대안도 검토했으나, 코드베이스 하나로 관리되고 배포가 단순하다는
이유로 앱 내 통합을 선택했다(사용자 확정).

## 4. 아키텍처 & 인증 모델

가장 중요한 결정: 현재 `sources` 테이블은 익명/일반 로그인 유저가 전혀 쓸 수 없고
`service_role`만 가능하다. 관리 화면이 쓰기를 하려면 이 경계를 넘어야 한다.

**채택안: 진짜 Supabase Auth 계정(관리자 전용) + DB단 RLS로 그 계정만 허용.**

```
Flutter 앱 (숨겨진 진입점: MY 탭 아바타 7번 탭)
        │
        ▼
   AdminLoginScreen (Supabase Auth 이메일/비번)
        │  로그인 성공 → admins 자가확인 쿼리
        ▼
   AdminHomeScreen (카테고리/IP/소스 CRUD, 소스 헬스, feed_items 미리보기)
        │  supabase_flutter로 평소처럼 쿼리
        ▼
   Postgres RLS: "이 요청의 auth.uid()가 admins 테이블에 있는가?"
        │  있으면 통과, 없으면 거부 (앱 코드가 아니라 DB가 막음)
        ▼
   categories / ips / sources 쓰기 허용
```

**기각한 대안**: 앱에 고정 비밀번호/시크릿을 박아넣고 Edge Function이 service_role로
대신 써주는 방식. 앱 바이너리에 박힌 고정 시크릿은 디컴파일로 추출 가능하고, 유출돼도
앱 업데이트 없인 무효화할 수 없다 — 채택하지 않는다.

**보안 원칙**: 숨김 진입점은 UX일 뿐 보안 경계가 아니다. 실제 방어선은 항상 **DB의
RLS**다. 세션은 로그아웃·만료가 가능하고, `admins` 테이블에 없는 계정으로 로그인해도
RLS가 데이터 접근을 막는다(일반 앱 사용자가 실수로 진입해도 안전).

## 5. 데이터 모델 & RLS 정책

### `admins` (새 테이블)
```sql
create table admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table admins enable row level security;

-- 본인 uid가 admins에 있는지 "자기 자신만" 확인 가능. 이게 없으면 다른 테이블의
-- 정책이 이 테이블을 서브쿼리로 참조할 때 항상 빈 결과가 나와 관리자도 막힌다
-- (RLS의 흔한 함정).
create policy "self check" on admins
  for select using (auth.uid() = user_id);
```

### `categories` / `ips` / `sources`에 관리자 쓰기 정책 추가
```sql
create policy "admins manage categories" on categories
  for all
  using (exists (select 1 from admins where user_id = auth.uid()))
  with check (exists (select 1 from admins where user_id = auth.uid()));

create policy "admins manage ips" on ips
  for all
  using (exists (select 1 from admins where user_id = auth.uid()))
  with check (exists (select 1 from admins where user_id = auth.uid()));

create policy "admins manage sources" on sources
  for all
  using (exists (select 1 from admins where user_id = auth.uid()))
  with check (exists (select 1 from admins where user_id = auth.uid()));
```
`sources`는 지금 정책이 전혀 없어서(익명 완전 차단) 이게 **처음 생기는 읽기/쓰기 경로**다.

### GRANT (RLS와 별개로 필요)
Supabase는 마이그레이션 적용 후 기본 GRANT를 회수한다(백엔드 수집기 배포 때 실제로
겪은 문제 — `docs/superpowers/plans/2026-08-12-backend-collector-foundation.md` 참고).
RLS 정책이 있어도 테이블 GRANT가 없으면 여전히 막힌다:
```sql
grant insert, update, delete on categories, ips, sources to authenticated;
grant select on sources to authenticated;   -- 지금 authenticated엔 select도 없음
grant select on admins to authenticated;    -- 자가확인 서브쿼리 실행에 필요
```

### `feed_items` 미리보기
이미 `for select using (true)`로 공개 읽기가 열려 있어 **변경 불필요** — 관리 화면이
기존 anon 읽기를 그대로 재사용한다.

### 관리자 계정 생성 (최초 1회, 수동)
Supabase Auth는 "회원가입"으로 관리자를 만들지 않는다. 대시보드(Authentication → Users
→ Add user)에서 관리자 전용 이메일/비번 계정을 만들고, 그 유저의 uid를 `admins`에
수동 INSERT한다(이것도 service_role/대시보드로만 가능 — 통상적인 "최초 관리자
부트스트랩" 패턴).

## 6. 화면 구조 (Flutter)

**숨김 진입점**: 기존 MY 탭(`../../../lib/ui/features/profile/view/profile_screen.dart`)의
프로필 아이콘을 **7번 탭**하면 진입한다(안드로이드 "빌드번호 7번 탭"과 같은 익숙한
패턴). 평소엔 어떤 메뉴에도 노출되지 않는다.

```
MY 탭 아바타 7번 탭
        ▼
AdminLoginScreen (세션 있으면 스킵)
   - Supabase Auth 이메일/비번 로그인
   - 로그인 성공 → admins 자가확인 쿼리
   - admins에 없으면 "관리자 권한 없음" 표시 후 로그아웃
        ▼
AdminHomeScreen (탭바 4개)
   ├─ 카테고리 탭: 목록 + 추가 폼
   ├─ IP 탭: 목록(카테고리별) + 추가 폼(카테고리 선택)
   ├─ 소스 탭: 목록(IP별, 헬스 정보 표시) + 추가 폼(IP 선택 → 타입 → URL)
   └─ 피드 미리보기 탭: feed_items 최근 N개 읽기 전용 리스트
```

### 파일 구조
```
lib/domain/models/
  admin_category.dart   # {id, name, slug}
  admin_ip.dart          # {id, name, slug, categoryId}
  admin_source.dart      # {id, ipId, type, url, isActive, lastSuccessAt, consecutiveFailures}
lib/data/repositories/
  admin_repository.dart  # signIn/checkIsAdmin/signOut + 카테고리·IP·소스 CRUD + feed_items 조회
lib/ui/features/admin/
  model/admin_state.dart
  view_model/admin_view_model.dart   # 로그인 상태 + 카탈로그(카테고리/IP/소스) 상태
  views/admin_login_screen.dart
  views/admin_home_screen.dart       # 탭바 셸
  views/admin_category_tab.dart
  views/admin_ip_tab.dart
  views/admin_source_tab.dart
  views/admin_feed_preview_tab.dart
```

기존 `feed/` 기능(`lib/ui/features/feed/`)과 동일한 패턴(모델/뷰모델/뷰 분리, Riverpod
`Notifier`)을 따른다. 카테고리·IP·소스는 서로 참조하는 데이터라 하나의 `AdminViewModel`
(카탈로그 전체 상태)로 묶고, 피드 미리보기는 읽기 전용이라 가벼운 별도 provider로 둔다.

기존 도메인 모델 `Ip`(`lib/domain/models/ip.dart`)는 소비자용 UI 표시 모델(구독 여부,
목업 썸네일 등)이라 관리자 CRUD와 목적이 다르다 — 재사용하지 않고 `admin_*` 접두사로
새로 만든다(각 모델이 하나의 명확한 책임만 갖도록).

## 7. 구현 담당

이 설계의 구현은 **사용자가 직접** 진행한다(`docs/design/flutter-logic-guide.md`와 같은
방식). 이 스펙 문서 승인 후, writing-plans(에이전트 실행용 계획)가 아니라
**`docs/design/admin-page-guide.md`**(구현 가이드 문서)를 작성해 전달한다.

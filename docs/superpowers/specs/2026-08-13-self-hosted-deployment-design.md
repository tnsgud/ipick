# iPick 백엔드 Self-Hosted 배포 — 설계 문서

- 작성일: 2026-08-13
- 상태: 설계 승인됨 (구현 계획 전 단계)
- 분류: 아키텍처(Architectural) — 새 배포 서브시스템

## 1. 배경 & 목적

지금까지 백엔드(Supabase + Edge Function 수집기)는 로컬 개발 스택(`supabase start`)과
Supabase Cloud를 전제로 설계됐다. 회사에 사용하지 않는 서버가 있어, 비용 절감을 위해
백엔드를 **회사 서버에 self-hosted Supabase로 이전**한다.

이 문서는 그 배포 인프라의 설계를 다룬다. 애플리케이션 스키마(마이그레이션 SQL)와
Edge Function(`collect`) 코드 자체는 이미 완성돼 있으며 변경하지 않는다 — 이 문서는
**그것들을 어디서 어떻게 돌릴지**만 다룬다.

> 참고: 원래 브레인스토밍(§4 접근 방식, `docs/superpowers/specs/2026-08-06-...design.md`)은
> "매니지드 서비스로 인프라 운영 부담을 최소화"하는 걸 전제로 했다. Self-hosting은 이
> 전제를 뒤집는다 — 패치·백업·가동시간 책임을 이제 직접 진다. 비용 절감이 그 트레이드오프를
> 감수할 만큼 가치 있다는 판단하에 진행한다.

## 2. 범위 (Scope)

### 포함
- 회사 서버에 공식 Supabase self-hosting docker-compose 스택 구성
- 회사 공용 nginx 프록시를 통한 TLS(https) 경로 확보
- 시크릿(.env) 관리 방식
- 기존 마이그레이션(`0001`~`0004`)·Edge Function(`collect`) 배포 워크플로
- Postgres 백업 & 롤백 절차
- 배포 검증(cutover) 체크리스트

### 제외 (다음 단계 또는 별도 결정)
- 마이그레이션 SQL·Edge Function 코드 자체의 변경 (이미 완료된 별도 산출물)
- 실제 서버 프로비저닝(회사 서버는 이미 존재) — 초기 상태만 전제로 함
- Flutter 앱의 인증/구독/FCM 로직 (별도 문서: `docs/design/flutter-logic-guide.md`)
- 정식 모니터링/알림 스택 구축 (헬스체크 핑 등 저비용 보완만 권고, §7)
- FCM 팬아웃(다음 백엔드 계획) — 이 배포가 그 기반이 될 뿐

## 3. 확정된 환경 정보

| 항목 | 값 | 비고 |
|---|---|---|
| 서버 사양 | 28 vCPU / 64GB RAM / 100GB 여유 디스크 | 리소스 여유 충분, 트리밍 불필요 |
| OS/Docker | Docker 설치됨, `dozzle-agent` 컨테이너 실행 중 | `docker compose`(v2 플러그인) 설치는 데몬 재시작 없이 안전 |
| 네트워크 노출 | **공인 IP, 인터넷 어디서든 접근 가능** | 방화벽으로 직접 노출을 제한할 것 (§4) |
| TLS 종료 지점 | **별도의 회사 공용 nginx 프록시 서버**(이 박스와 다른 서버) | 도메인은 nginx 서버 쪽 IP로 연결 |
| 도메인 | 새로 구입 예정 | 서브도메인 하나(예: `api.<도메인>`)를 nginx에 등록 |
| nginx 설정 접근권한 | **미확정** — 직접 추가 가능한지 불명 | §8 외부 의존성 참고 |
| 로그 관측 | Dozzle(agent) 이미 있음 | 컨테이너가 어떻게 뜨든(docker-compose 포함) 자동으로 보임. 별도 로깅 설정 불필요 |

## 4. 아키텍처 & 네트워크 경계

```
                         인터넷 (폰 앱)
                              │
                              │ https://api.<도메인>
                              ▼
                  ┌─────────────────────────┐
                  │  회사 공용 nginx 프록시    │  ← 별도 서버. TLS 종료는 여기서.
                  │  (도메인·인증서 관리 담당)  │
                  └────────────┬────────────┘
                               │ proxy_pass (사내망, http도 무방)
                               │ → <28코어박스 내부IP>:8000
                               ▼
        ┌──────────────────────────────────────────────┐
        │  28코어 / 64GB 박스 (docker compose)            │
        │                                                │
        │   ┌────────┐   ┌──────┐   ┌───────────┐ ┌────────┐│
        │   │  Kong   │──▶│ Auth │   │ PostgREST │ │ Edge   ││
        │   │(게이트웨이)│   │(GoTrue)│  │           │ │Function││
        │   └────────┘   └──────┘   └───────────┘ └────────┘│
        │        │                        │            ▲    │
        │        └───────────┬────────────┘            │    │
        │                    ▼                          │    │
        │               ┌─────────┐   pg_cron ──────────┘    │
        │               │Postgres │   (내부 docker 네트워크로  │
        │               │ (+cron) │    직접 호출)             │
        │               └─────────┘                          │
        │                                                    │
        │  방화벽: 8000(Kong)은 nginx서버 IP만 허용.            │
        │  5432(Postgres)·Studio 등은 그 외 전혀 열리지 않음.    │
        └──────────────────────────────────────────────────┘
```

### 핵심 결정
1. **TLS 종료는 회사 nginx가 담당.** 박스에 별도 리버스 프록시(Caddy 등)를 두지 않는다 —
   인증서 발급·갱신 부담이 사라진다. 도메인은 nginx 서버의 IP로 A레코드를 건다.
2. **박스는 nginx 서버의 IP에서만 Kong 포트(8000)를 받도록 방화벽을 잠근다.** Postgres(5432),
   Studio 등 그 외 포트는 인터넷은 물론 nginx 서버에도 노출하지 않는다. 박스 자체가 공인
   IP를 가졌음에도 불구하고, 방화벽 없이는 인터넷 전체에 그대로 노출된다는 점을 명심한다
   (§7 검증에서 반드시 확인).
3. **공식 Supabase self-hosting docker-compose 스택을 그대로** 사용한다(Postgres, Kong,
   Auth, PostgREST, Edge Functions, Studio 등). 리소스가 넉넉하고 Kong 하나만 외부에
   노출되므로, 서비스를 잘라내는 것보다 공식 구성을 유지하는 게 유지보수 측면에서 낫다.
4. **pg_cron은 내부 docker 네트워크 주소로 함수를 호출한다.** 기존 `0003_schedule_collect.sql`의
   `<PROJECT_REF>.functions.supabase.co`(클라우드 전용, 로컬에서 해석 불가) 자리를 내부
   서비스 주소로 교체한다 — 로컬 dev에서 겪었던 "cron 등록은 되는데 안 도는" 문제가
   여기서는 발생하지 않는다.

## 5. 시크릿 · 설정 관리

**원칙: 시크릿은 그 박스 안에만 존재하고, git에는 절대 들어가지 않는다.**

박스 위 `.env` 파일(공식 compose 템플릿 형식)로 관리한다:

| 항목 | 용도 |
|---|---|
| `POSTGRES_PASSWORD` | DB 비밀번호 (새로 생성한 강력한 랜덤값) |
| `JWT_SECRET` | 아래 두 키를 서명하는 시드 (강력한 랜덤값) |
| `ANON_KEY`(publishable) | **Flutter 앱에 넣는 값.** 공개돼도 안전하도록 설계됨 — 실제 방어선은 RLS |
| `SERVICE_ROLE_KEY`(secret) | **Edge Function(collect)만** 사용. 앱에는 절대 넣지 않음 |
| `DASHBOARD_USERNAME/PASSWORD` | Studio 관리자 UI 로그인 (외부 비노출, SSH 터널로만 접근) |
| `SITE_URL` / `API_EXTERNAL_URL` | `https://api.<도메인>` — Kong/Auth가 링크 생성에 사용 |

- `ANON_KEY`/`SERVICE_ROLE_KEY`는 랜덤 문자열이 아니라 `JWT_SECRET`으로 서명한 JWT다
  (role 클레임만 다름 — 로컬 dev에서 `supabase status`로 봤던 것과 같은 구조). 공식
  self-hosting 가이드의 생성 스크립트로 만든다.
- **Edge Function 코드 변경 불필요** — `index.ts`는 이미 `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')`
  로 읽으므로, compose의 `functions` 서비스 환경변수에 값만 들어가면 그대로 동작한다.
- `.env` 유실 = 전체 키 재발급 + 앱 재배포이므로, 안전한 곳(비밀번호 관리자 등)에
  **암호화 백업**을 둔다. Slack·git 등에 붙여넣지 않는다.

## 6. 마이그레이션 & Edge Function 배포 워크플로

박스 위에 저장소 2개가 나란히 존재한다:

```
28코어 박스
├── supabase-docker/        # 공식 supabase/supabase 저장소의 docker/ 폴더
│   ├── docker-compose.yml  # 공식 그대로 (건드릴 일 거의 없음)
│   └── volumes/functions/
│       └── collect ────────symlink──▶ ~/ipick/supabase/functions/collect
│
└── ipick/                  # 우리 저장소 (git pull로 갱신)
    └── supabase/
        ├── migrations/*.sql
        └── functions/collect/
```

### 최초 배포
1. 박스에 SSH 접속 → 공식 `supabase/supabase` 저장소, `ipick` 저장소 각각 `git clone`.
2. `supabase-docker/.env`를 §5의 시크릿으로 채움 → `docker compose up -d`.
3. `functions/collect`를 위 그림처럼 symlink로 연결 (`git pull` 한 번으로 함수 코드도 갱신됨).
4. 박스에 Supabase CLI 설치 → **박스 안에서** 마이그레이션 적용:
   ```bash
   supabase db push --db-url postgresql://postgres:$POSTGRES_PASSWORD@localhost:5432/postgres
   ```
   Postgres 포트가 외부에 열려 있지 않으므로(§4), 이 명령은 반드시 박스 위에서 실행한다.

### ⚠️ 금기사항
- **프로덕션에서 `supabase db reset` 절대 금지** — DB를 통째로 지우고 재생성한다. 항상
  `supabase db push`(또는 `migration up`)만 쓴다.
- `supabase/seed.sql`은 로컬 전용이다(프로덕션 오염을 막기 위해 마이그레이션에서 분리해둔
  것). **프로덕션에서 seed를 실행하지 않는다.** 배포 후 첫 실제 IP/소스는 운영자가 Studio
  (SSH 터널) 또는 psql로 직접 입력한다.

### 이후 업데이트 (day-2)
```bash
cd ~/ipick && git pull
supabase db push --db-url postgresql://postgres:$POSTGRES_PASSWORD@localhost:5432/postgres
docker compose -f ~/supabase-docker/docker-compose.yml restart functions
```
이 3줄을 `deploy.sh`로 스크립트화한다(반복 실수 방지, 구현 계획의 태스크로 포함).

## 7. 백업 & 롤백

Self-hosting으로 인해 이제 직접 책임지는 부분이다. MVP 단계에 맞게 과하지 않게 잡는다.

| 대상 | 이미 안전한가 |
|---|---|
| 마이그레이션 SQL, Edge Function 코드 | ✅ git(GitHub)에 있음 — 별도 백업 불필요 |
| `.env`(시크릿) | ❌ 박스에만 존재 — 유실 시 키 전체 재발급 필요 |
| Postgres 데이터 | ❌ 유일한 사본 — 진짜 백업 대상 |

### 백업 방식
- 매일 1회 cron으로 `pg_dump` → 로컬 파일, 7일치 로테이션.
- **박스 안에만 있는 백업은 백업이 아니다.** `rsync`/`scp`로 박스 밖(다른 서버·개인 컴퓨터
  등 접근 가능한 곳)으로 매일 복사한다.
- `.env`는 변경될 때만 암호화 백업 갱신.
- PITR(시점 복구)·WAL 아카이빙은 지금 단계엔 과함(YAGNI) — 일 단위 `pg_dump`로 충분하고,
  데이터 가치가 커지면 그때 업그레이드한다.

### 롤백 시나리오
1. **마이그레이션이 잘못 나갔을 때**: 되돌리기가 아니라 앞으로 고치는 새 마이그레이션을
   추가한다(forward-only, 로컬 dev와 동일한 방식). 데이터까지 꼬였으면 최근 `pg_dump`로 복구.
2. **서버 자체가 죽었을 때**: 다른 박스에 스택 재설치 → 백업한 `.env` 복원 → 최근
   `pg_dump`로 DB 복구 → nginx의 proxy_pass를 새 박스 IP로 변경. 구체적 절차는 구현
   계획에서 `RUNBOOK.md`로 문서화한다.

### 보완 (선택)
백업 cron이 조용히 실패하면 모를 수 있다 — 로그가 Dozzle에 남거나(이미 있음), 저렴한
"죽었는지 감시" 서비스(예: healthchecks.io 무료 티어)에 핑을 걸어두는 걸 권장하되 필수는
아니다.

## 8. 외부 의존성 / 확인 필요 사항

이 설계는 다음 두 가지가 **아직 미확정**임을 전제로 한다. 구현 계획에는 이를 확인/요청하는
스텝으로 명시한다:

1. **회사 nginx 설정에 직접 접근 가능한지** — 가능하면 셀프서브로 진행, 불가능하면 담당자에게
   "이 서브도메인을 이 내부IP:8000으로 proxy_pass 해달라"고 요청하는 게 배포의 한 스텝이 된다.
2. dozzle-agent의 포트(기본 7007)와 Supabase 스택이 노출하려는 포트(Kong 8000/8443,
   Postgres 5432, Studio 3000 등)가 겹치지 않는지 배포 전 `docker ps`/`ss -tlnp`로 확인.

## 9. 검증(Cutover) 체크리스트

배포 직후 이 순서로 확인한다.

**1) 내부 동작 확인 (박스 위 SSH에서)**
```bash
docker compose ps                                   # 전부 healthy/running
curl -X POST http://localhost:8000/functions/v1/collect \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY"       # collect 함수 수동 트리거
```

**2) cron이 실제로 도는지**
```sql
select * from cron.job_run_details order by start_time desc limit 5;  -- 성공 기록
select count(*) from feed_items;                                       -- 주기적 증가
```

**3) 외부(진짜 인터넷)에서 앱이 겪을 경로 확인**
회사망이 아닌 곳(개인 노트북·폰 LTE 등)에서:
```bash
curl https://api.<도메인>/rest/v1/categories -H "apikey: $ANON_KEY"
```

**4) ⚠️ 방화벽이 실제로 잠겼는지 (필수, 생략 금지)**
회사망 밖에서:
```bash
curl -m 5 http://<28코어박스_공인IP>:8000    # 타임아웃/거부가 나와야 정상
curl -m 5 <박스IP>:5432                      # 이것도 막혀 있어야 정상
```
둘 다 응답 없어야 정상. **하나라도 열려 있으면 배포 완료로 간주하지 않는다.**

**5) 앱 전환**
Flutter의 `Supabase.initialize(url:, publishableKey:)`를 로컬 값(`127.0.0.1:54321`)에서
`https://api.<도메인>` + 새 anon key로 바꾼다. 로컬 dev 스택은 유지하고(평소 개발용),
이 박스는 스테이징/프로덕션 역할로 분리한다. 하드코딩 대신 `--dart-define` 등으로 환경을
분리하는 걸 권장하되, 이 구현은 `docs/design/flutter-logic-guide.md`에 제안만 남기고
앱 로직 담당자가 진행한다.

## 10. 구현 순서 제안

1. 회사 nginx 접근권한 확인/요청 (§8-1) — 병행 가능, 블로킹 최소화
2. 박스에 Docker Compose 플러그인 설치 + 포트 충돌 확인 (§8-2)
3. 도메인 구입 + nginx 서버 IP로 A레코드
4. 공식 `supabase/supabase` docker-compose 클론 + `.env` 생성(§5) + `docker compose up -d`
5. nginx에 서브도메인 → 박스:8000 proxy_pass 등록 (직접 또는 요청)
6. 방화벽 규칙 적용 (Kong 포트만 nginx IP 허용, 나머지 차단)
7. `ipick` 저장소 클론 + Supabase CLI 설치 + `supabase db push`로 마이그레이션 적용
8. `functions/collect` symlink 연결 + `0003_schedule_collect.sql`의 URL을 내부 주소로 교체 적용
9. `pg_dump` 백업 cron + 박스 밖 복사 설정 (§7)
10. §9 검증 체크리스트 전항목 통과 확인
11. Flutter 앱을 새 URL/키로 전환

## 11. 향후 확장

- 정식 모니터링/알림 스택 (헬스체크 서비스 연동)
- PITR 등 강화된 백업 전략 (데이터 가치 증가 시)
- Storage(굿즈 이미지)·Realtime(실시간 피드) 활성화 — 이미 스택에 포함돼 있어 켜기만 하면 됨
- FCM 팬아웃 배포 (별도 계획)

# iPick Self-Hosted 배포 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **⚠️ 실행 전 필독:** 이 계획의 Task 2·4~10은 **회사 서버(SSH)·회사 공용 nginx·구매한 도메인**을
> 다룬다. 로컬 코드 계획(TDD 서브에이전트가 안전하게 로컬에서 반복 실행)과 달리, 이 태스크들은
> 실제 인프라를 바꾸며 되돌리기 어려운 조작(방화벽, 공유 nginx 설정, 프로덕션 DB)을 포함한다.
> Task 1(레포 스캐폴딩)만 로컬 작업이라 서브에이전트로 안전하게 실행 가능하다. Task 2 이후는
> 사람이 직접 실행하거나(계획을 런북으로 사용), SSH 접근을 명시적으로 부여받은 뒤 사람이
> 매 스텝 결과를 확인하며 진행하는 걸 권장한다.

**Goal:** iPick 백엔드(Supabase + `collect` Edge Function)를 회사 서버에 self-hosted로 배포하여, 로컬 dev와 별개로 Flutter 앱이 실제로 붙을 수 있는 프로덕션/스테이징 백엔드를 확보한다.

**Architecture:** 공식 `supabase/supabase` docker-compose 스택을 회사 서버(28코어/64GB, 공인 IP)에 그대로 띄우고, TLS 종료는 별도의 회사 공용 nginx 프록시가 담당한다. 이 박스는 방화벽으로 Kong(8000) 포트만 그 nginx 서버 IP에 한정 노출하고 나머지는 전부 막는다. 마이그레이션·Edge Function 코드는 기존 `ipick` 저장소 그대로 재사용(Supabase CLI `--db-url` + symlink)하며, pg_cron은 내부 docker 네트워크로 함수를 직접 호출한다.

**Tech Stack:** Docker + `docker compose`(v2 플러그인), 공식 `supabase/supabase` self-hosting 템플릿, Supabase CLI, 기존 Deno Edge Function(변경 없음), bash(deploy/backup/firewall 스크립트), `pg_dump` + `rsync`, ufw(또는 서버의 방화벽 도구).

**Spec:** `docs/superpowers/specs/2026-08-13-self-hosted-deployment-design.md`

## Global Constraints

- 서버 사양: 28 vCPU / 64GB RAM / 100GB 여유 디스크. Docker 설치됨, `dozzle-agent` 컨테이너 실행 중(포트 7007) — 포트 충돌 여부 배포 전 확인.
- 네트워크: 이 박스는 **공인 IP로 인터넷 어디서든 접근 가능** — 방화벽 없이는 완전 노출 상태. TLS 종료는 **별도의 회사 공용 nginx 프록시 서버**가 담당(이 박스 위가 아님).
- **방화벽: Kong(8000)은 nginx 서버 IP에서만 허용, 그 외(Postgres 5432, Studio 등)는 전혀 노출하지 않는다.** 이걸 확인 없이 배포 완료로 치지 않는다.
- **프로덕션에서 `supabase db reset` 절대 금지.** 항상 `supabase db push`(`migration up`)만 사용.
- `supabase/seed.sql`은 로컬 전용 — 프로덕션에 절대 적용하지 않는다.
- 시크릿(`.env`)은 그 박스 안에만 존재하고 git에 절대 커밋하지 않는다. `SERVICE_ROLE_KEY`(secret)는 Edge Function만 사용, 앱에는 `ANON_KEY`(publishable)만 넣는다.
- 백업: 박스 안에만 있는 백업은 백업이 아니다 — 반드시 박스 밖으로 복사한다.
- 도메인 구매는 금전 거래이므로 에이전트가 대신 실행하지 않는다(사람이 직접). SSH가 필요한 태스크도 접근권한을 부여받지 않은 에이전트가 임의로 실행하지 않는다.
- 로컬 dev Supabase 스택은 계속 유지한다 — 이 배포는 그것을 대체하지 않고 별도 환경(스테이징/프로덕션)으로 추가된다.

---

## File Structure

```
deploy/
  .env.example       # backup.sh용 설정 템플릿 (실제 값 없음, 예시만)
  deploy.sh           # day-2 업데이트 스크립트 (git pull → 마이그레이션 → 함수 재시작)
  backup.sh           # pg_dump → 로컬 로테이션 → 박스 밖 rsync 복사
  firewall.sh         # ufw 규칙 적용 (Kong만 nginx서버 IP에 한정 노출)
  RUNBOOK.md          # 최초 배포 절차 + 장애복구 절차 (사람이 따라 하는 문서)
supabase/migrations/
  0003_schedule_collect.sql   # Task 8에서 URL을 내부 주소로 교체(수정)
.gitignore            # deploy/.env 추가(수정)
```

**책임 분리:** `deploy/` 스크립트들은 **모두 이 저장소(`ipick`)에 커밋되는 코드**이며, Task 1에서 전부 작성·검증한다(서버 접근 불필요, `bash -n` 문법 검사로 로컬 검증). Task 2 이후는 이 스크립트들을 **실제 서버에 배치·실행**하는 절차이며, RUNBOOK.md가 그 절차의 사람이 읽는 사본이다.

---

## Task 1: 배포 스크립트 & 런북 스캐폴딩 (로컬, 서버 접근 불필요)

**Files:**
- Create: `deploy/.env.example`
- Create: `deploy/deploy.sh`
- Create: `deploy/backup.sh`
- Create: `deploy/firewall.sh`
- Create: `deploy/RUNBOOK.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: 없음 (최초 태스크, 로컬 전용)
- Produces: 이후 모든 서버 작업(Task 4~9)이 참조하는 스크립트·런북. `deploy.sh`는 `$SUPABASE_DOCKER_DIR/.env`(공식 스택의 `.env`, 기본값 `$HOME/supabase-docker/.env`)의 `POSTGRES_PASSWORD`를 읽는다. `backup.sh`는 `deploy/.env`(이 태스크가 템플릿만 만듦, 실값은 서버에서 채움)의 `POSTGRES_PASSWORD`/`BACKUP_DIR`/`BACKUP_RETENTION_DAYS`/`BACKUP_REMOTE`를 읽는다. `firewall.sh`는 환경변수 `NGINX_SERVER_IP`를 요구한다.

- [ ] **Step 1: `.gitignore`에 시크릿 파일 추가**

Edit `.gitignore`, add:
```gitignore
# Self-hosted deploy secrets (server-only, never commit)
deploy/.env
```

- [ ] **Step 2: `deploy/.env.example` 작성**

Create `deploy/.env.example`:
```bash
# deploy/.env.example
# 서버에서 deploy/.env 로 복사하고 실제 값을 채운다. deploy/.env는 git에 커밋하지 않는다
# (설계 문서 §5 원칙과 동일 — 시크릿은 서버 안에만 존재).

# supabase-docker/.env 의 POSTGRES_PASSWORD 와 동일한 값이어야 한다.
POSTGRES_PASSWORD=

# pg_dump 결과를 임시로 쌓아두는 로컬 디렉토리
BACKUP_DIR=/var/backups/ipick

# 로컬에 며칠치 덤프를 남길지 (그 이후 것은 자동 삭제)
BACKUP_RETENTION_DAYS=7

# 박스 밖으로 복사할 rsync 목적지. 예: user@otherhost:/backups/ipick
# 비워두면 박스 밖 복사를 건너뛴다 (권장하지 않음 — 설계 문서 §7 참고).
BACKUP_REMOTE=
```

- [ ] **Step 3: `deploy/deploy.sh` 작성 (day-2 업데이트)**

Create `deploy/deploy.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# iPick self-hosted 백엔드 day-2 업데이트 스크립트.
# 서버 위, ipick 저장소 체크아웃 안에서 실행한다:
#   ./deploy/deploy.sh
# 설계 문서: docs/superpowers/specs/2026-08-13-self-hosted-deployment-design.md §6

IPICK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPABASE_DOCKER_DIR="${SUPABASE_DOCKER_DIR:-$HOME/supabase-docker}"
ENV_FILE="$SUPABASE_DOCKER_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE 없음. SUPABASE_DOCKER_DIR를 지정하거나 설계 문서 §5대로 .env를 먼저 만드세요." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

echo "==> git pull (ipick)"
git -C "$IPICK_DIR" pull

echo "==> 마이그레이션 적용"
supabase db push --db-url "postgresql://postgres:${POSTGRES_PASSWORD}@localhost:5432/postgres"

echo "==> Edge Function 재시작 (코드 갱신 반영)"
docker compose -f "$SUPABASE_DOCKER_DIR/docker-compose.yml" restart functions

echo "==> 완료"
```

- [ ] **Step 4: `deploy/backup.sh` 작성 (일 단위 백업)**

Create `deploy/backup.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# iPick self-hosted 백엔드 Postgres 백업 (매일 cron으로 실행).
# 설계 문서: docs/superpowers/specs/2026-08-13-self-hosted-deployment-design.md §7
# 필요 env: deploy/.env.example 참고 (deploy/.env로 복사 후 값 채움)

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$DEPLOY_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE 없음. deploy/.env.example을 deploy/.env로 복사하고 값을 채우세요." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

BACKUP_DIR="${BACKUP_DIR:-/var/backups/ipick}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DUMP_FILE="$BACKUP_DIR/ipick-$TIMESTAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "==> DB 덤프 생성"
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h localhost -U postgres -d postgres | gzip > "$DUMP_FILE"

echo "==> ${BACKUP_RETENTION_DAYS}일 지난 로컬 덤프 정리"
find "$BACKUP_DIR" -name 'ipick-*.sql.gz' -mtime "+${BACKUP_RETENTION_DAYS}" -delete

if [ -n "${BACKUP_REMOTE:-}" ]; then
  echo "==> 박스 밖으로 복사: $BACKUP_REMOTE"
  rsync -az "$DUMP_FILE" "$BACKUP_REMOTE/"
else
  echo "WARNING: BACKUP_REMOTE 미설정 — 덤프가 이 박스 안에만 있습니다. 진짜 백업이 아닙니다." >&2
fi

echo "==> 백업 완료: $DUMP_FILE"
```

- [ ] **Step 5: `deploy/firewall.sh` 작성**

Create `deploy/firewall.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# 이 박스의 노출 포트를 설계 문서 §4대로 제한한다.
# Kong(8000)은 회사 공용 nginx 프록시 서버의 IP에서만 허용. 그 외는 전부 막는다.
# sudo로 실행. ufw 기준 — 서버가 다른 방화벽 도구를 쓰면 이 규칙을 그에 맞게 옮긴다.
#
# 사용법: sudo NGINX_SERVER_IP=1.2.3.4 ./deploy/firewall.sh

: "${NGINX_SERVER_IP:?NGINX_SERVER_IP에 회사 공용 nginx 프록시 서버의 IP를 지정하세요}"

echo "==> 기본 정책: 인바운드 전체 거부, 아웃바운드 전체 허용"
ufw default deny incoming
ufw default allow outgoing

echo "==> SSH(22) 허용 — 없으면 자기 자신도 접속 못 함"
ufw allow 22/tcp

echo "==> Kong(8000)은 nginx 서버($NGINX_SERVER_IP)에서만 허용"
ufw allow from "$NGINX_SERVER_IP" to any port 8000 proto tcp

echo "==> ufw 활성화"
ufw --force enable

echo "==> 현재 상태"
ufw status verbose
```

- [ ] **Step 6: `deploy/RUNBOOK.md` 작성**

Create `deploy/RUNBOOK.md`:
```markdown
# iPick Self-Hosted 배포 런북

설계 근거: `docs/superpowers/specs/2026-08-13-self-hosted-deployment-design.md`

## 최초 배포 순서

이 계획(`docs/superpowers/plans/2026-08-13-self-hosted-deployment.md`)의 Task 2~10을
순서대로 따른다. 요약:

1. 서버 사전 점검 (OS/패키지관리자 확인, `docker compose` 플러그인 설치, dozzle-agent
   포트(7007)와 충돌 없는지 확인)
2. 도메인 구매 + nginx 서버 IP로 A레코드 등록 (사람이 직접)
3. 공식 `supabase/supabase` docker-compose 스택 클론 + `.env` 생성 + `docker compose up -d`
4. 회사 nginx에 서브도메인 → 이 박스:8000 proxy_pass 등록 (직접 또는 요청)
5. `sudo NGINX_SERVER_IP=<nginx서버IP> ./deploy/firewall.sh`
6. `ipick` 저장소 클론 + Supabase CLI 설치 + `supabase db push`로 마이그레이션 적용 +
   `functions/collect` symlink 연결
7. `0003_schedule_collect.sql`의 URL을 내부 주소로 교체 후 재적용, cron 등록/실행 확인
8. `deploy/.env` 채우고 `deploy/backup.sh`를 cron에 등록, 1회 수동 실행으로 검증
9. 전체 cutover 체크리스트(설계 문서 §9) 통과 확인
10. Flutter 앱을 새 URL/키로 전환

## 장애 복구 (서버가 죽었을 때)

1. 새 박스(또는 복구된 박스)에 Docker + `docker compose` 플러그인 설치.
2. 공식 `supabase/supabase` 저장소 클론, 암호화 백업해둔 `.env` 복원.
3. `docker compose up -d`.
4. 최근 백업 복원:
   ```bash
   gunzip -c /path/to/latest/ipick-YYYYMMDD-HHMMSS.sql.gz | \
     PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U postgres -d postgres
   ```
5. `ipick` 저장소 클론, `functions/collect` symlink 재연결.
6. `deploy/firewall.sh` 재적용.
7. 회사 nginx의 proxy_pass 대상을 새 박스 IP로 변경 (직접 또는 요청).
8. 설계 문서 §9 체크리스트 재검증.

## 마이그레이션이 잘못 나갔을 때

되돌리지 않는다 — 문제를 고치는 **새 마이그레이션**을 추가해 `supabase db push`로 적용한다
(로컬 dev와 동일한 forward-only 방식). 데이터까지 꼬였으면 위 "장애 복구" §4의 복원 절차를
따른다.

## 절대 하지 말 것

- 프로덕션에서 `supabase db reset` — DB가 통째로 사라진다.
- `supabase/seed.sql`을 프로덕션에 적용 — 로컬 전용이다.
- `deploy/.env` 또는 `supabase-docker/.env`를 git에 커밋.
```

- [ ] **Step 7: 문법 검증**

Run:
```bash
bash -n deploy/deploy.sh && bash -n deploy/backup.sh && bash -n deploy/firewall.sh
chmod +x deploy/deploy.sh deploy/backup.sh deploy/firewall.sh
```
Expected: 문법 오류 없음(아무 출력 없이 종료), `chmod` 후 세 파일 모두 실행권한 부여됨.

- [ ] **Step 8: 커밋**

Run:
```bash
git add deploy/ .gitignore
git commit -m "feat: add self-hosted deploy/backup/firewall scripts and runbook"
```

---

## Task 2: 서버 사전 점검 (SSH 필요)

**Files:** 없음 (서버 상태 확인만)

**Interfaces:**
- Consumes: 없음
- Produces: 확인된 OS/패키지관리자, 설치된 `docker compose` 플러그인, 포트 충돌 없음 확인. Task 4 이후가 이 상태를 전제로 진행.

- [ ] **Step 1: OS/패키지관리자 확인**

Run (서버 SSH):
```bash
cat /etc/os-release
```
Expected: 배포판 이름 확인(예: Ubuntu). 이후 스텝의 패키지 설치 명령을 그 배포판에 맞게 조정한다(아래는 Debian/Ubuntu `apt` 기준 — 다르면 해당 배포판의 동등 명령으로 대체).

- [ ] **Step 2: `docker compose` v2 플러그인 설치 확인/설치**

Run:
```bash
docker compose version
```
Expected: 버전 출력. 없으면(예: Ubuntu):
```bash
sudo apt-get update && sudo apt-get install -y docker-compose-plugin
docker compose version
```
Expected: 설치 후 버전 출력. **주의**: 이 설치는 CLI 플러그인 바이너리 추가일 뿐이라 Docker 데몬을
재시작하지 않는다 — 기존에 돌던 `dozzle-agent`를 포함한 컨테이너들이 끊기지 않는다.

- [ ] **Step 3: 기존 컨테이너 확인 (dozzle-agent 포함)**

Run:
```bash
docker ps --format '{{.Names}}\t{{.Ports}}'
```
Expected: `dozzle-agent`가 목록에 있고 계속 `Up` 상태. 포트 매핑을 메모해둔다(보통 `7007`).

- [ ] **Step 4: 포트 충돌 확인**

Run:
```bash
ss -tlnp 2>/dev/null | grep -E ':(7007|8000|8443|5432|3000|4000)\b' || echo "충돌 없음"
```
Expected: `dozzle-agent`의 포트(예: 7007)만 보이고, Supabase가 쓰려는 포트(8000/8443/5432/3000/4000)는
아직 아무것도 안 걸려 있어야 한다("충돌 없음" 또는 dozzle 포트만 출력). 겹치는 게 있으면 Task 4에서
docker-compose의 해당 포트 매핑을 다른 값으로 바꿔야 한다 — 이 계획을 진행하기 전에 먼저 해결한다.

---

## Task 3: 도메인 구매 + DNS 연결 (사람이 직접 — 에이전트가 실행하지 않음)

**Files:** 없음

**Interfaces:**
- Consumes: nginx 서버의 공인 IP (회사에 확인)
- Produces: `$DOMAIN` (예: `api.example.com`) — Task 5, 8, 10, 11이 이 값을 사용.

- [ ] **Step 1: 도메인 구매**

저렴한 도메인(연 1만원 안팎)을 신뢰할 수 있는 등록기관(예: Namecheap, 가비아 등)에서 구매한다.
**이 스텝은 금전 거래이므로 사람이 직접 진행한다.**

- [ ] **Step 2: 서브도메인 → nginx 서버 IP로 A레코드 등록**

구매한 도메인의 DNS 관리 화면에서:
```
Type: A
Host: api  (결과: api.<도메인>)
Value: <nginx 프록시 서버의 공인 IP>
TTL: 자동/기본값
```

- [ ] **Step 3: 전파 확인**

Run (본인 컴퓨터에서):
```bash
dig +short api.<도메인>
```
Expected: nginx 서버의 IP가 출력됨(전파에 최대 수십 분 걸릴 수 있음 — 안 나오면 잠시 후 재시도).

---

## Task 4: 공식 Supabase self-hosting 스택 기동 (SSH 필요)

**Files:** 없음 (서버 위 별도 디렉토리, 이 저장소 밖)

**Interfaces:**
- Consumes: Task 2의 Docker Compose 설치 완료.
- Produces: `~/supabase-docker/.env`(시크릿), `docker compose up -d`로 뜬 전체 스택(Postgres/Kong/Auth/PostgREST/Edge Functions/Studio 등). Task 1의 `deploy.sh`가 이 `.env`의 `POSTGRES_PASSWORD`를 읽는다. Task 7·8·9가 이 스택 위에서 진행.

- [ ] **Step 1: 공식 저장소 클론**

Run (서버 SSH):
```bash
git clone --depth 1 https://github.com/supabase/supabase ~/supabase-src
cp -r ~/supabase-src/docker ~/supabase-docker
cd ~/supabase-docker
```

- [ ] **Step 2: `.env` 생성 및 시크릿 채우기**

Run:
```bash
cp .env.example .env
```
`.env`를 열어 아래 값을 채운다(설계 문서 §5):
- `POSTGRES_PASSWORD`: 강력한 랜덤 문자열로 교체 (예: `openssl rand -base64 32`)
- `JWT_SECRET`: 강력한 랜덤 문자열로 교체 (예: `openssl rand -base64 48`, 32자 이상)
- `ANON_KEY`, `SERVICE_ROLE_KEY`: 위 `JWT_SECRET`으로 서명한 JWT로 교체 — 공식
  self-hosting 문서(`https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys`)의
  안내대로 생성한다(role 클레임이 각각 `anon`/`service_role`).
- `DASHBOARD_USERNAME`, `DASHBOARD_PASSWORD`: Studio 로그인용, 임의로 설정.
- `SITE_URL`, `API_EXTERNAL_URL`: `https://api.<도메인>` (Task 3의 `$DOMAIN`)로 설정.

- [ ] **Step 2 검증: 시크릿이 실제로 서명됐는지 확인**

Run:
```bash
grep -E '^(ANON_KEY|SERVICE_ROLE_KEY)=' .env | cut -d= -f2 | while read -r k; do
  echo "$k" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null; echo
done
```
Expected: 첫 줄에 `"role":"anon"`, 둘째 줄에 `"role":"service_role"`이 보임(로컬 dev 때와
같은 검증 방식). `.env.example`의 예시 키가 그대로 남아있으면 여기서 걸러진다.

- [ ] **Step 3: 스택 기동**

Run:
```bash
docker compose up -d
docker compose ps
```
Expected: 모든 서비스가 `running`/`healthy` 상태. `functions` 서비스 이름을 메모해둔다(Task 8에서
내부 호출 주소로 씀 — 공식 템플릿 기준 서비스명 `functions`, 포트 `9000`이지만 실제 `docker compose ps`
출력으로 재확인).

- [ ] **Step 4: 로컬(박스 내부)에서 API 응답 확인**

Run:
```bash
curl -s http://localhost:8000/rest/v1/ -H "apikey: $(grep ^ANON_KEY= .env | cut -d= -f2)"
```
Expected: PostgREST의 OpenAPI 스키마(JSON)가 응답으로 옴 — Kong→PostgREST 경로가 내부적으로
살아있다는 뜻.

---

## Task 5: 회사 nginx에 서브도메인 연결 (경로 A: 직접 설정 / 경로 B: 요청)

**Files:** 없음 (이 저장소 밖 — 회사 nginx 서버 위)

**Interfaces:**
- Consumes: Task 3의 `$DOMAIN`, Task 4에서 뜬 박스 내부 IP:8000.
- Produces: `https://api.<도메인>` → 박스:8000으로 라우팅되는 nginx 설정. Task 10의 외부 검증이 이걸 전제로 한다.

### 경로 A: nginx 설정에 직접 접근 가능한 경우

- [ ] **Step 1: server block 추가**

nginx 서버 위에서, 다른 vhost 설정 옆에 새 파일을 만든다(예: `/etc/nginx/sites-available/ipick-api`):
```nginx
server {
    listen 443 ssl;
    server_name api.<도메인>;

    # 이 nginx가 이미 인증서를 관리하는 방식(예: 회사 공용 인증서, 또는 certbot)을 따른다.
    # 신규 도메인이면 별도로 인증서 발급이 필요할 수 있다 — 이 부분은 그 nginx의 기존
    # 운영 방식에 맞춘다.

    location / {
        proxy_pass http://<박스_내부IP>:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

- [ ] **Step 2: 활성화 및 재로드**

Run:
```bash
sudo ln -s /etc/nginx/sites-available/ipick-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```
Expected: `nginx -t`가 `syntax is ok` / `test is successful` 출력.

### 경로 B: 직접 설정할 수 없어 요청이 필요한 경우

- [ ] **Step 1: 요청 메시지 작성 (담당자/IT에 전달)**

아래 내용을 그대로 전달한다:

> iPick 서비스용으로 서브도메인 `api.<도메인>`을 내부 박스 `<박스_내부IP>:8000`으로
> proxy_pass 해주실 수 있을까요? 필요한 nginx 설정은 다음과 같습니다:
>
> ```nginx
> server {
>     listen 443 ssl;
>     server_name api.<도메인>;
>     location / {
>         proxy_pass http://<박스_내부IP>:8000;
>         proxy_set_header Host $host;
>         proxy_set_header X-Real-IP $remote_addr;
>         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
>         proxy_set_header X-Forwarded-Proto $scheme;
>     }
> }
> ```
> TLS 인증서는 기존에 쓰시는 방식(회사 공용 인증서/certbot 등) 그대로 적용해주시면 됩니다.
> 감사합니다!

- [ ] **Step 2: 반영 확인**

요청 처리 후:
```bash
curl -s https://api.<도메인>/rest/v1/ -H "apikey: <ANON_KEY>"
```
Expected: Task 4 Step 4와 동일한 PostgREST OpenAPI 스키마 응답. 여기서 처음으로 **외부 도메인
경로 전체**(nginx→박스)가 검증된다.

---

## Task 6: 방화벽 적용 (SSH 필요, 박스 위)

**Files:**
- Uses: `deploy/firewall.sh` (Task 1에서 작성)

**Interfaces:**
- Consumes: Task 1의 `firewall.sh`, nginx 서버의 IP(Task 5에서 확인/확정).
- Produces: 박스가 Kong(8000)만 nginx 서버 IP에 노출, 나머지 전부 차단된 상태. Task 10의 외부 검증 Step 4가 이걸 확인한다.

- [ ] **Step 1: `ipick` 저장소를 박스에 클론 (아직 안 했다면)**

Run:
```bash
git clone https://github.com/tnsgud/ipick ~/ipick
```

- [ ] **Step 2: 방화벽 적용**

Run:
```bash
sudo NGINX_SERVER_IP=<nginx서버_공인IP> ~/ipick/deploy/firewall.sh
```
Expected: `ufw status verbose` 출력에 `8000/tcp ALLOW FROM <nginx서버IP>`, `22/tcp ALLOW`,
기본 정책 `deny (incoming), allow (outgoing)`이 보임.

- [ ] **Step 3: 박스 내부에서 여전히 정상 동작하는지 확인**

Run (박스 위):
```bash
curl -s http://localhost:8000/rest/v1/ -H "apikey: <ANON_KEY>"
```
Expected: Task 4 Step 4와 동일하게 정상 응답(방화벽은 외부 인바운드만 막으므로 localhost 접근엔
영향 없음).

**⚠️ Step 4는 반드시 Task 10에서 회사망 밖(외부)에서 재확인한다** — SSH 세션 자체가 회사 내부망을
거칠 수 있어 여기서는 방화벽이 진짜 잠겼는지 확실히 검증되지 않는다.

---

## Task 7: 마이그레이션 & Edge Function 배포 (SSH 필요, 박스 위)

**Files:**
- Uses: `~/ipick/supabase/migrations/*.sql`, `~/ipick/supabase/functions/collect/`

**Interfaces:**
- Consumes: Task 4의 기동된 Postgres(`localhost:5432`), Task 6에서 클론된 `~/ipick`.
- Produces: `categories/ips/sources/feed_items/subscriptions` 테이블이 프로덕션 DB에 존재. `~/supabase-docker/volumes/functions/collect`가 코드에 연결됨. Task 8이 이 상태를 전제로 cron을 배선한다.

- [ ] **Step 1: Supabase CLI 설치**

Run:
```bash
curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz \
  -o /tmp/supabase.tar.gz
sudo tar -xzf /tmp/supabase.tar.gz -C /usr/local/bin supabase
supabase --version
```
Expected: 버전 출력. (아키텍처가 amd64가 아니면 릴리스 페이지에서 맞는 tarball로 교체.)

- [ ] **Step 2: 마이그레이션 적용**

Run:
```bash
source ~/supabase-docker/.env
supabase db push --db-url "postgresql://postgres:${POSTGRES_PASSWORD}@localhost:5432/postgres" \
  --workdir ~/ipick
```
Expected: `0001_core_schema.sql`, `0003_schedule_collect.sql`, `0004_subscriptions.sql`이
순서대로 적용됨(0002는 로컬 전용 seed로 이미 분리돼 있어 대상에서 빠짐 — 정상).
**`supabase db reset`은 여기서 절대 실행하지 않는다.**

- [ ] **Step 3: 테이블 존재 확인**

Run:
```bash
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U postgres -d postgres \
  -c "\dt public.*"
```
Expected: `categories`, `ips`, `sources`, `feed_items`, `subscriptions` 전부 보임.

- [ ] **Step 4: Edge Function 코드 연결 (symlink)**

Run:
```bash
mkdir -p ~/supabase-docker/volumes/functions
ln -s ~/ipick/supabase/functions/collect ~/supabase-docker/volumes/functions/collect
docker compose -f ~/supabase-docker/docker-compose.yml restart functions
```

- [ ] **Step 5: 함수 수동 트리거로 동작 확인**

Run:
```bash
curl -s -X POST http://localhost:8000/functions/v1/collect \
  -H "Authorization: Bearer $(grep ^SERVICE_ROLE_KEY= ~/supabase-docker/.env | cut -d= -f2)"
```
Expected: `CollectResult` 형태의 JSON 응답(`perSource`, `newItems` 필드 포함). 이 시점엔
아직 프로덕션에 실제 소스가 없으므로 `perSource`가 빈 배열이어도 정상(오류만 없으면 됨) —
실제 소스는 다음 Step에서 넣는다.

- [ ] **Step 6: 첫 실제 소스 1건 수동 등록 (seed.sql 대신)**

Run:
```bash
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U postgres -d postgres <<'SQL'
insert into categories (name, slug) values ('애니메', 'anime')
  on conflict (slug) do nothing;
insert into ips (category_id, name, slug)
  select id, '테스트 IP', 'demon-slayer' from categories where slug='anime'
  on conflict (slug) do nothing;
insert into sources (ip_id, type, url, is_active)
  select id, 'rss', 'https://www.reddit.com/r/anime/.rss', true from ips where slug='demon-slayer'
  on conflict do nothing;
SQL
```
(실제 운영 시엔 이 스텝을 진짜 추적하고 싶은 IP/소스로 교체한다 — 이건 스모크 테스트용
placeholder 데이터가 아니라, seed.sql이 프로덕션에 안 돌아가므로 필요한 최소 1건이다.)

- [ ] **Step 7: 재트리거로 수집 확인**

Run:
```bash
curl -s -X POST http://localhost:8000/functions/v1/collect \
  -H "Authorization: Bearer $(grep ^SERVICE_ROLE_KEY= ~/supabase-docker/.env | cut -d= -f2)"
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U postgres -d postgres \
  -c "select count(*) from feed_items;"
```
Expected: `perSource`에 방금 등록한 소스가 `ok:true`로 나오고, `feed_items` 카운트가 0보다 큼.

---

## Task 8: pg_cron을 내부 주소로 배선 (SSH 필요, 박스 위)

**Files:**
- Modify: `~/ipick/supabase/migrations/0003_schedule_collect.sql` (박스 위 체크아웃에서 수정 후 재적용 — 저장소 원본은 이 계획의 Task 8b에서 별도로 커밋)

**Interfaces:**
- Consumes: Task 4에서 확인한 `functions` 서비스 이름/포트, Task 7의 적용된 마이그레이션.
- Produces: 15분마다 `collect` 함수를 실제로 성공 호출하는 cron job. Task 10의 검증이 이걸 확인한다.

- [ ] **Step 1: vault 시크릿 생성 (실제 SERVICE_ROLE_KEY)**

Run:
```bash
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U postgres -d postgres <<SQL
select vault.create_secret(
  '$(grep ^SERVICE_ROLE_KEY= ~/supabase-docker/.env | cut -d= -f2)',
  'collect_service_key'
);
SQL
```
Expected: 생성된 secret의 uuid가 출력됨. 이미 있으면 에러 대신
`select vault.update_secret((select id from vault.secrets where name='collect_service_key'), '<새 값>');`로 교체.

- [ ] **Step 2: URL을 내부 주소로 교체**

`~/ipick/supabase/migrations/0003_schedule_collect.sql`을 열어 다음 줄을:
```sql
    url := 'https://<PROJECT_REF>.functions.supabase.co/collect',
```
다음으로 교체한다(Task 4 Step 3에서 확인한 실제 서비스명/포트 사용 — 공식 템플릿 기준
`functions`/`9000`이지만, 다르면 그 값으로):
```sql
    url := 'http://functions:9000/collect',
```

- [ ] **Step 2b: 상단의 클라우드 전용 경고 주석을 self-hosted 기준으로 교체**

같은 파일 상단의 `⚠️ DEPLOY-TIME TEMPLATE ⚠️` 주석 블록은 "Supabase Cloud에 배포할 때
`<PROJECT_REF>`를 실제 값으로 바꿔라"는 내용인데, 이제 self-hosted 내부 주소를 쓰므로
그 지시가 더 이상 맞지 않는다. 이 블록 전체를 아래로 교체한다:
```sql
-- ============================================================================
-- SELF-HOSTED: 이 URL은 self-hosted docker-compose의 내부 서비스 주소를 가리킨다
-- (docs/superpowers/specs/2026-08-13-self-hosted-deployment-design.md §4, §6).
-- `functions`/`9000`은 공식 supabase/supabase 템플릿의 기본 서비스명/포트다 — 다른
-- self-hosted 환경으로 옮길 때는 그 환경의 실제 서비스명/포트로 다시 맞춰야 한다.
-- 로컬 `supabase start` dev 환경에서는 이 잡이 등록만 되고 실제로 host를 못 찾아 매번
-- 실패한다(예상된 동작 — 로컬에서는 함수를 `supabase functions serve`로 직접 테스트한다).
-- ============================================================================
```

- [ ] **Step 3: 재적용**

Run:
```bash
source ~/supabase-docker/.env
supabase db push --db-url "postgresql://postgres:${POSTGRES_PASSWORD}@localhost:5432/postgres" \
  --workdir ~/ipick
```
Expected: 오류 없이 적용(같은 마이그레이션 파일을 수정 후 재적용하는 것이므로 CLI가
변경분을 반영 — 만약 CLI가 "already applied"로 스킵하면, 대신 `psql`로 해당 `cron.schedule`
호출부만 직접 재실행해 `cron.job`을 갱신한다).

- [ ] **Step 4: cron 등록·실행 확인**

Run:
```bash
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U postgres -d postgres -c \
  "select jobname, schedule from cron.job;"
```
Expected: `collect-sources` / `*/15 * * * *` 행 존재.

15분 이상 기다린 뒤:
```bash
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U postgres -d postgres -c \
  "select status, return_message, start_time from cron.job_run_details order by start_time desc limit 5;"
```
Expected: `status`가 `succeeded`인 행이 보임(`failed`면 `return_message`로 원인 확인 —
대개 Step 2의 URL이 실제 서비스명/포트와 다른 경우).

- [ ] **Step 5: 저장소 원본에 URL 변경 커밋 (로컬 dev 머신 또는 박스 위 `~/ipick`에서)**

Run:
```bash
cd ~/ipick   # 또는 로컬 개발 머신의 체크아웃
git add supabase/migrations/0003_schedule_collect.sql
git commit -m "fix: point collect cron job at internal self-hosted functions address"
git push
```

---

## Task 9: 백업 cron 등록 (SSH 필요, 박스 위)

**Files:**
- Uses: `deploy/backup.sh` (Task 1)

**Interfaces:**
- Consumes: `deploy/.env`(이 태스크에서 실값 채움), Task 4의 `POSTGRES_PASSWORD`.
- Produces: 매일 도는 백업 + 박스 밖 사본. Task 10 검증 항목은 아니지만 배포 완료의 필수 조건.

- [ ] **Step 1: `deploy/.env` 생성**

Run:
```bash
cd ~/ipick
cp deploy/.env.example deploy/.env
```
`deploy/.env`를 열어 `POSTGRES_PASSWORD`(supabase-docker/.env와 동일 값), `BACKUP_REMOTE`
(박스 밖 rsync 목적지 — 접근 가능한 다른 서버나 본인 컴퓨터)를 채운다.

- [ ] **Step 2: 수동 1회 실행으로 검증**

Run:
```bash
~/ipick/deploy/backup.sh
```
Expected: `백업 완료: /var/backups/ipick/ipick-<타임스탬프>.sql.gz` 출력, `BACKUP_REMOTE`
목적지에도 같은 파일이 도착해 있음(목적지에서 `ls`로 확인).

- [ ] **Step 3: crontab 등록 (매일 새벽 3시)**

Run:
```bash
(crontab -l 2>/dev/null; echo "0 3 * * * $HOME/ipick/deploy/backup.sh >> /var/log/ipick-backup.log 2>&1") | crontab -
crontab -l
```
Expected: 등록된 crontab 목록에 방금 추가한 줄이 보임.

---

## Task 10: 전체 Cutover 검증 (SSH + 회사망 밖 접근 필요)

**Files:** 없음 (검증만)

**Interfaces:**
- Consumes: Task 4~9의 전체 결과.
- Produces: 배포 완료 확정. 실패 시 해당 Task로 돌아가 재작업.

- [ ] **Step 1: 내부 동작 재확인 (박스 위)**

Run:
```bash
docker compose -f ~/supabase-docker/docker-compose.yml ps
```
Expected: 전체 서비스 `running`/`healthy`.

- [ ] **Step 2: cron이 실제로 도는지 (Task 8 Step 4 재확인)**

Run:
```bash
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U postgres -d postgres -c \
  "select count(*) from feed_items;"
```
15분 뒤 다시 실행해 카운트가 그대로거나(새 글 없으면 정상) 늘어났는지 확인(둘 다 정상 —
핵심은 `cron.job_run_details`에 `failed`가 새로 안 쌓이는 것).

- [ ] **Step 3: 외부(진짜 인터넷)에서 API 경로 확인**

Run (회사망이 아닌 곳 — 본인 노트북의 테더링/타 와이파이 등):
```bash
curl -s https://api.<도메인>/rest/v1/categories -H "apikey: <ANON_KEY>"
```
Expected: `categories` 테이블 데이터(JSON)가 응답. 실패하면 Task 5(nginx)로 돌아간다.

- [ ] **Step 4: ⚠️ 방화벽이 실제로 잠겼는지 (필수, 생략 금지)**

Run (회사망이 아닌 곳에서):
```bash
curl -m 5 http://<박스_공인IP>:8000    # 타임아웃/거부가 나와야 정상
curl -m 5 <박스_공인IP>:5432           # 이것도 막혀 있어야 정상
```
Expected: 둘 다 응답 없이 타임아웃. **하나라도 응답이 오면 Task 6으로 돌아가 방화벽 규칙을
다시 확인한다 — 이 스텝을 통과하기 전엔 배포 완료로 간주하지 않는다.**

- [ ] **Step 5: 백업 확인**

Task 9에서 등록한 crontab이 다음 새벽 3시에 실제로 돈 뒤, `BACKUP_REMOTE` 목적지에 새 파일이
쌓이는지 하루 뒤 확인(즉시 검증 불가 — 배포 완료의 후속 확인 항목으로 기록).

---

## Task 11: Flutter 앱 cutover (로컬, 앱 코드 — 최소 변경)

**Files:**
- Modify: `lib/main.dart:10-13` (현재 `Supabase.initialize(url: 'http://127.0.0.1:54321', publishableKey: '...')` 부분)

**Interfaces:**
- Consumes: Task 3의 `$DOMAIN`, Task 4에서 생성한 `ANON_KEY`.
- Produces: 앱이 로컬 대신 self-hosted 백엔드를 바라봄.

> 이 태스크는 앱 로직 담당(사용자 본인) 영역과 겹친다. 최소 변경만 아래에 명시하고,
> 환경별 분리(`--dart-define` 등)는 `docs/design/flutter-logic-guide.md`의 권고를 참고해
> 원하는 방식으로 확장해도 된다 — 여기서는 배포를 "완결"시키는 최소 diff만 다룬다.

- [ ] **Step 1: URL/키 교체**

`lib/main.dart`에서:
```dart
await Supabase.initialize(
  url: 'http://127.0.0.1:54321',
  publishableKey: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
);
```
를 다음으로 교체(`<도메인>`과 `<ANON_KEY>`는 Task 3·4의 실제 값):
```dart
await Supabase.initialize(
  url: 'https://api.<도메인>',
  publishableKey: '<ANON_KEY>',
);
```

- [ ] **Step 2: 동작 확인**

Run:
```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter analyze
```
Expected: 오류 없음. 이후 시뮬레이터에서 피드 화면이 self-hosted 백엔드의 `categories`/`feed_items`
데이터를 실제로 불러오는지 눈으로 확인한다(Task 10에서 등록한 실제 소스 데이터가 보여야 함).

- [ ] **Step 3: 커밋**

Run:
```bash
git add lib/main.dart
git commit -m "feat: point Flutter app at self-hosted Supabase backend"
```

---

## 전체 검증 (완료 기준)

- [ ] Task 1의 세 스크립트가 `bash -n` 통과 + 커밋됨
- [ ] `docker compose ps` 전체 healthy
- [ ] 외부(회사망 밖)에서 `https://api.<도메인>/rest/v1/...` 정상 응답
- [ ] 외부에서 박스 공인 IP:8000, :5432 둘 다 타임아웃(방화벽 검증)
- [ ] `cron.job_run_details`에 `succeeded` 기록 존재, `feed_items` 실제 데이터 존재
- [ ] `deploy/backup.sh` crontab 등록 + 수동 실행 1회 성공 + 박스 밖 사본 확인
- [ ] Flutter 앱이 새 URL/키로 전환되어 실제 데이터를 렌더링

---

## Self-Review Notes (작성자 확인)

- **스펙 커버리지**: 설계 문서 §4(네트워크 경계) → Task 4·6, §5(시크릿) → Task 1·4, §6(마이그레이션/배포) → Task 1·7·8, §7(백업/롤백) → Task 1·9·RUNBOOK, §8(외부 의존성) → Task 5(경로 A/B), §9(검증) → Task 10, §10(구현순서) → Task 1~11 1:1 대응. 전부 태스크로 커버됨.
- **타입/값 일관성**: `.env`의 `POSTGRES_PASSWORD`/`SERVICE_ROLE_KEY`/`ANON_KEY` 이름을 전 태스크에서 동일하게 사용. `functions`/`9000` 내부 주소는 Task 4에서 "확인 필요" 로 명시하고 Task 8에서 실제값으로 교체하도록 일관되게 연결.
- **안전 경계**: 도메인 구매(Task 3), SSH가 필요한 모든 서버 작업(Task 2, 4~10)을 헤더에서 명확히 "사람 실행/명시적 접근권한 필요"로 구분. `db reset` 금지, `.env` 커밋 금지를 Global Constraints와 RUNBOOK 양쪽에 중복 명시(실수 방지 목적의 의도된 중복).
- **가정/리스크**: 공식 템플릿의 Edge Functions 서비스명/포트(`functions`/`9000`)는 실제 `docker compose ps`로 재확인 필요(Task 4·8에 명시). nginx 접근권한 미확정은 경로 A/B 둘 다 완전히 명시해 대응.

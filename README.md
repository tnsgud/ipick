# IPick 좋아하는 IP의 모든 소식을 한곳에서.

팬덤 발매·굿즈 알림 수집 파이프라인 (Supabase + Deno Edge Functions).

## 개발
- `supabase start` — 로컬 스택 기동
- `supabase db reset` — 마이그레이션 재적용 + 시드
- `eval "$(supabase status -o env)"` 후 `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` export — 통합테스트 준비
- `deno test --allow-net --allow-env --allow-read supabase/functions/collect/` — 테스트

## 인증 키 주의
통합테스트·수집기는 반드시 `SERVICE_ROLE_KEY`(role=service_role)를 사용한다. anon/publishable 키는 RLS에 막혀 "permission denied"가 난다.

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

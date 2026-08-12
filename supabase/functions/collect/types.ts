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
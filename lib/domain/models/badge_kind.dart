/// 피드 항목의 상태 라벨. iPick의 핵심 — "지금 뭘 해야 하나"를 한눈에 전달한다.
///
/// 실제 데이터에서는 `feed_items.item_type` + 발매/예약 상태를 규칙으로 매핑해
/// 정하게 된다(로직 문서 §피드 참고). 여기서는 디자인용 열거만 둔다.
enum BadgeKind {
  release, // 발매 / NEW
  reserving, // 예약중
  limited, // 한정
  closingSoon, // 임박
  soldOut, // 품절/마감
  news, // 소식
}

---
id: ipick
name: iPick
country: KR
category: fandom / commerce-alerts
status: draft
primary_color: "#39C5BB"
note: "팬덤 발매·굿즈 알림 + 구매 연결 앱을 위한 디자인 시스템 초안. Toss DESIGN.md(OMD) 포맷 참고. Primary는 틸 #39C5BB로 확정."
ds:
  name: iPick DS (draft)
  type: proposal
  description: "실측 검증 전 제안 단계. 값은 구현하며 조정 가능."
tokens:
  source: proposed
  drafted: "2026-08-12"
  colors:
    primary: "#39C5BB"          # 브랜드 틸 (채움: 버튼·인디케이터·강조 배경)
    primary-hover: "#1FAEA4"    # hover
    primary-pressed: "#159A90"  # pressed
    primary-ink: "#12897E"      # 흰 배경 위 텍스트/아이콘용 진한 틸 (워드마크·활성 탭·칩 텍스트). 밝은 틸의 낮은 대비 보완.
    on-primary: "#063D38"       # primary 채움 위 텍스트 (진한 틸; 흰색은 대비 부족해 사용 안 함)
    canvas: "#FFFFFF"           # 기본 배경
    foreground: "#14201E"       # 최강 텍스트 (살짝 틸 기미)
    body: "#465350"             # 본문 텍스트
    muted: "#869390"            # 보조 텍스트
    surface: "#F2F6F5"          # 카드 뒤·입력창 배경 (틸 기미 뉴트럴)
    border: "#E0EAE8"           # 구분선/외곽선
    weak-background: "#E2F6F3"  # 틸 틴트 배경 (약한 CTA·뱃지·선택 칩)
    weak-foreground: "#12897E"  # 틸 틴트 위 텍스트 (= primary-ink)
    success: "#1FA971"          # 구매 가능/성공
    warning: "#F5A524"          # 예약 임박/주의
    danger: "#E5484D"           # 품절/오류/파괴적
    info: "#3B5BDB"             # 예약중 등 정보 (브랜드 틸과 구분되도록 인디고 쪽으로 조정)
    highlight: "#8B5CF6"        # 한정판 강조 (보라 악센트)
  typography:
    family: { sans: "Pretendard" }   # 오픈소스(OFL), 한글·기호 지원. 시스템 폰트 폴백.
    h1: { size: 24, weight: 700, lineHeight: "32px" }
    h2: { size: 20, weight: 700, lineHeight: "28px" }
    h3: { size: 18, weight: 600, lineHeight: "26px" }
    h4: { size: 16, weight: 600, lineHeight: "24px" }
    body: { size: 15, weight: 400, lineHeight: "22px" }
    body-small: { size: 13, weight: 400, lineHeight: "19px" }
    caption: { size: 12, weight: 500, lineHeight: "16px" }
  spacing: { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32 }
  rounded: { sm: 8, md: 12, lg: 16, card: 16, button: 12, pill: 999 }
  elevation:
    e1: "0 1px 2px rgba(20, 32, 30, 0.06)"
    e2: "0 4px 12px rgba(20, 32, 30, 0.08)"
    e3: "0 8px 24px rgba(20, 32, 30, 0.12)"
  components:
    button-primary: { bg: "#39C5BB", fg: "#063D38", radius: "12px", height: "52px", padding: "0 20px", font: "16px / 600", states: "default, hover(#1FAEA4), pressed(#159A90), loading, disabled, focus", note: "밝은 틸이라 텍스트는 진한 틸(#063D38). 흰 텍스트 금지." }
    button-weak: { bg: "#E2F6F3", fg: "#12897E", radius: "12px", height: "52px", padding: "0 20px", font: "16px / 600" }
    button-secondary: { bg: "#F2F6F5", fg: "#14201E", border: "1px solid #E0EAE8", radius: "12px", height: "52px" }
    chip: { bg: "#FFFFFF", fg: "#465350", border: "1px solid #E0EAE8", selected-bg: "#E2F6F3", selected-fg: "#12897E", radius: "999px", height: "34px", padding: "0 14px", font: "13px / 500" }
    card: { bg: "#FFFFFF", border: "1px solid #E0EAE8", radius: "16px", padding: "12px", shadow: "e1", use: "피드 소식/굿즈 카드" }
    badge: { radius: "999px", padding: "2px 8px", font: "12px / 600", variants: "발매/NEW, 예약중, 한정, 임박, 품절/마감" }
    input: { bg: "#F2F6F5", fg: "#14201E", border: "1px solid #E0EAE8", focus-border: "#39C5BB", radius: "12px", height: "48px", padding: "0 14px", font: "15px / 400" }
    tabs: { active-fg: "#12897E", inactive-fg: "#869390", indicator: "#39C5BB" }
---

## 1. Visual Theme & Atmosphere

iPick은 흩어진 팬덤 소식 중에서도 **"놓치면 손해인 발매·한정·예약 굿즈"**를 한곳에
모아 빠르게 알려주고 바로 구매로 연결하는 앱이다. 톤은 두 가지를 동시에 잡는다:
청량하고 산뜻한 **틸 브랜드감**과, 결제·예약으로 이어지는 만큼 **신뢰감 있는 차분한
뉴트럴**. 틸은 브랜드 정체성과 액션(구독·구매·알림 켜기)에만 기능적으로 쓰고,
나머지 화면은 콘텐츠(굿즈 이미지)가 주인공이 되도록 비운다.

**핵심 특징**
- Primary 틸 `#39C5BB` — 액션과 브랜드에만 집중 사용
- 밝은 틸이라 **채움 위 텍스트는 진한 틸**, 흰 배경 위 텍스트는 별도 진한 틸(`primary-ink`)
- 콘텐츠 카드 중심 레이아웃 (굿즈 썸네일이 주역)
- 상태 뱃지(발매/예약/한정/임박/품절)로 "지금 뭘 해야 하나"를 즉시 전달
- Pretendard 기반의 또렷한 한글 타이포그래피

## 2. Color Palette & Roles

### 브랜드 · 액션
- **Primary** (`#39C5BB`): 기본 액션(구독, 알림 켜기, 구매하기)의 **채움색**과 브랜드 색.
- **Primary Hover** (`#1FAEA4`) / **Pressed** (`#159A90`): 상호작용 강조.
- **Primary Ink** (`#12897E`): **흰 배경 위** 브랜드 텍스트·아이콘(워드마크, 활성 탭,
  선택 칩·뱃지 텍스트). 밝은 틸이 흰 배경에서 흐려지는 문제를 보완하는 필수 역할.
- **On Primary** (`#063D38`): **틸 채움 위** 텍스트. 흰색은 대비가 부족해 쓰지 않는다.
- **Weak Background** (`#E2F6F3`) / **Weak Foreground** (`#12897E`): 약한 틸 CTA·뱃지·선택 칩.

### 뉴트럴 (틸 기미)
- **Canvas** (`#FFFFFF`): 기본 배경.
- **Foreground** (`#14201E`): 최강 텍스트(제목).
- **Body** (`#465350`): 본문.
- **Muted** (`#869390`): 보조/메타 텍스트.
- **Surface** (`#F2F6F5`): 카드 뒤·입력창 배경.
- **Border** (`#E0EAE8`): 구분선/외곽선.

### 시맨틱 (상태)
- **Success** (`#1FA971`): 구매 가능.
- **Info** (`#3B5BDB`): 예약중. *브랜드 틸과 색이 겹치지 않도록 인디고 쪽으로 조정함.*
- **Warning** (`#F5A524`): 예약 임박/마감 주의.
- **Danger** (`#E5484D`): 품절/마감/오류.
- **Highlight** (`#8B5CF6`): 한정판 강조(보라 악센트, 절제해서 사용).

> 접근성 메모: 틸은 밝은 색이라 **흰 텍스트 대비가 부족**하다. 그래서 (1) 틸 채움 위
> 텍스트는 진한 틸 `on-primary`(#063D38), (2) 흰 배경 위 브랜드 텍스트는 `primary-ink`
> (#12897E)를 쓴다. 더 강한 대비·프리미엄 인상이 필요하면 채움색을 딥틸(#0B857B, 흰
> 텍스트 가능)로 내리는 옵션을 부분적으로 쓸 수 있다. 구현 시 실제 대비값 검증 필요.

## 3. Typography Rules

### Font Family
- **기본 UI 패밀리**: `Pretendard` (오픈소스 OFL — 재배포 가능, 한글·숫자·기호 지원).
  시스템 폰트(-apple-system / Roboto) 폴백.
- 굿즈명·일본어/영문 원문 표기가 섞이므로 다국어 글리프 커버리지를 우선.

### 타입 스케일 (모바일 앱 기준)

| 역할 | 크기 | 굵기 | 행간 | 용도 |
|---|---:|---:|---:|---|
| H1 | 24px | 700 | 32px | 화면 타이틀 |
| H2 | 20px | 700 | 28px | 섹션 헤더 |
| H3 | 18px | 600 | 26px | 카드 제목(굿즈명) |
| H4 | 16px | 600 | 24px | 소제목/버튼 |
| Body | 15px | 400 | 22px | 본문/설명 |
| Body Small | 13px | 400 | 19px | 메타(출처·시간) |
| Caption | 12px | 500 | 16px | 뱃지·라벨 |

## 4. Component Stylings

### Button — Primary
- 배경 `#39C5BB` / 텍스트 `#063D38`(진한 틸, **흰색 금지**)
- Radius 12px, Height 52px, Padding 0 20px, Font 16px/600 Pretendard
- States: default, hover(`#1FAEA4`), pressed(`#159A90`), loading(폭 유지), disabled(투명도↓), keyboard focus
- 용도: 화면당 1개의 핵심 액션(구매하기, 알림 켜기)

### Button — Weak / Secondary
- **Weak**: 배경 `#E2F6F3` / 텍스트 `#12897E` — 보조 틸 액션(구독하기)
- **Secondary**: 배경 `#F2F6F5` / 텍스트 `#14201E` / 1px `#E0EAE8` 테두리 — 중립 액션

### Chip (구독·필터)
- 기본: 흰 배경 / `#465350` / 1px `#E0EAE8`, Radius 999px(pill), Height 34px
- 선택됨: 배경 `#E2F6F3` / 텍스트 `#12897E`
- 용도: IP 구독 토글, 카테고리 필터(전체/발매/소식)

### Card (피드 소식 · 굿즈)
- 배경 `#FFFFFF`, 1px `#E0EAE8`, Radius 16px, Padding 12px, Shadow `e1`
- 구성: 썸네일(좌 또는 상단) · 굿즈명(H3) · 출처+시간(Body Small) · 상태 뱃지 · `구매/예약` 버튼
- 용도: 통합 피드의 기본 단위. 이미지가 주역이 되도록 텍스트는 절제.

### Badge (상태 라벨) — 이 앱의 핵심
- Radius 999px, Padding 2px 8px, Font 12px/600. **설명용이며 클릭 액션 아님.**

| 뱃지 | 배경 / 텍스트 | 의미 |
|---|---|---|
| 발매 / NEW | `#E2F6F3` / `#12897E` | 신제품 발매 (브랜드 틸) |
| 예약중 | `#E8F1FF` / `#3B5BDB` | 예약 진행 (info) |
| 한정 | `#F1EAFE` / `#6D3BE0` | 한정판 (highlight) |
| 임박 | `#FFF3E0` / `#C77A00` | 예약/재고 마감 임박 (warning) |
| 품절/마감 | `#EEF0F0` / `#64706D` | 종료 (muted) |

### Input (검색)
- 배경 `#F2F6F5`, 1px `#E0EAE8`, focus 시 테두리 `#39C5BB`
- Radius 12px, Height 48px, Padding 0 14px, Font 15px/400
- States: default, focus, error(`#E5484D`), disabled

### Tabs
- 활성 텍스트 `#12897E`(primary-ink) / 인디케이터 `#39C5BB` / 비활성 `#869390`
- 용도: 피드 상단 필터(전체 / 발매·굿즈 / 소식)

## 5. Layout Principles

- **Spacing**: 4 · 8 · 12 · 16 · 24 · 32 (컴팩트 8pt 계열)
- **Grid**: 모바일 세로 1열 카드 리스트 기본. 굿즈 갤러리 뷰는 2열 그리드 옵션.
- **Radius**: 소형 8px, 카드/버튼 12~16px, 칩/뱃지 pill(999px)
- 콘텐츠 최우선 — 여백으로 카드 간 리듬을 만들고 장식은 최소화.

## 6. Depth & Elevation

부드러운 3단계 그림자만 사용한다. 카드는 `e1`(거의 평면), 떠 있는 요소(바텀시트·
플로팅 버튼)는 `e2`, 다이얼로그는 `e3`. 과한 그림자 대신 색 레이어(surface)와 테두리로
계층을 표현한다.

## 7. Do's and Don'ts

### Do
- 틸은 **액션·브랜드·상태 강조**에만. 넓은 면적 배경은 뉴트럴/흰색.
- 틸 채움 위 텍스트는 진한 틸(`on-primary`), 흰 배경 위 브랜드 텍스트는 `primary-ink`.
- 상태 뱃지로 "발매/예약/한정/임박/품절"을 항상 명확히.
- 굿즈 이미지를 화면의 주인공으로. 텍스트는 보조.
- 버튼 loading/disabled/pressed/focus 상태 유지.

### Don't
- **틸 채움 버튼에 흰 텍스트 금지** (대비 부족) — 진한 틸 텍스트 사용.
- 밝은 틸(`#39C5BB`)을 흰 배경 위 본문 텍스트 색으로 쓰지 않기 — `primary-ink` 사용.
- 틸을 배경 전체에 깔아 눈을 피로하게 만들지 않기.
- 뱃지를 버튼처럼 보이게 해 클릭을 유도하지 않기.
- 시맨틱 색(success/danger 등)을 장식용으로 남용하지 않기.
- 예약중(info)을 브랜드 틸과 헷갈리게 쓰지 않기 — info는 인디고 계열로 분리해 둠.

## 8. Motion & Easing (초안)

- 기본 전환 150–200ms, ease-out. 리스트 진입·뱃지 등장은 짧고 가볍게.
- `구매/예약` 성공 시 마이크로 피드백(체크·햅틱) 권장.
- reduced-motion 설정 존중. 정확한 커브·시간은 구현 시 확정.

## 9. 상태 요약 (State Contracts)

| 컴포넌트 | 상태 |
|---|---|
| Button | default, hover, pressed, loading, disabled, focus |
| Input | default, focus, error, disabled |
| Chip | default, selected, disabled |
| Card | default, pressed(탭), 이미지 로딩/실패 플레이스홀더 |
| Badge | 시맨틱 변형만 (비상호작용) |

---

## Included Components (초안 범위)

- Button (primary / weak / secondary)
- Chip (구독·필터)
- Card (피드/굿즈)
- Badge (상태 라벨)
- Input (검색)
- Tabs
- Dialog / Bottom Sheet

> 상태: **draft** — Primary 틸 `#39C5BB` 확정. 나머지 값은 실측·구현 과정에서 조정될 수
> 있으며, 확정 시 `status: verified`로 갱신하고 근거를 남긴다.

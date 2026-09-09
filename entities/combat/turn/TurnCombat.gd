extends Object
class_name TurnCombat

# 턴제 전투의 **어휘 단일 출처** (#450).
#
# 원소·물리 타입·역할·버킷·타격 범위·격파 상태이상은 여기서만 정의한다.
# 다른 모듈(TimelineSystem, DamagePipeline, UI, .tres 저작)은 전부 이 열거형을 참조한다.
# 값을 다른 파일에 다시 적으면 원소 하나를 늘릴 때 손볼 자리가 여러 곳이 된다.
#
# 설계 정본: docs/turn-combat-design.md (PROJECT LUMEN §4.4, §4.5, §4.6, §4.10.10)
#
# **열거형의 정수값을 바꾸지 않는다.** `.tres`에 정수로 굳으므로, 값을 바꾸면
# 저작된 캐릭터·스킬·적의 원소가 조용히 다른 원소로 변한다. 새 항목은 **뒤에 추가**한다.

# ===== 진영 (Side) =====
enum Side {
	ALLY,    # 아군 (랭크 A1~A4)
	ENEMY,   # 적   (랭크 E1~E5)
}

# ===== 원소 (Element) — 7종 =====
#
# 격파 시 부여되는 상태이상이 **7개 전부 다르다**. 데미지형과 CC형을 섞는 것이 설계 의도다
# (전부 도트뎀으로 만들면 "약점 맞추기"가 단순 최적화가 되고 전략 선택이 되지 않는다).
enum Element {
	IMPACT,     # 충격 — 격파 시 열상(최대HP 비례 도트)
	PYRO,       # 화염 — 격파 시 연소(공격력 비례 도트, 중첩)
	CRYO,       # 한기 — 격파 시 동결(1턴 완전 행동 불가)
	VOLT,       # 전격 — 격파 시 감전(도트 + 적 스킬 사용 시 추가 피해)
	GALE,       # 풍압 — 격파 시 균열(중첩형 도트)
	CORROSION,  # 침식 — 격파 시 속박(행동 지연 + 받는 피해 누적, 해제 시 폭발)
	LUMEN,      # 광휘 — 격파 시 각인(속도 감소 + 행동 지연 + 받는 피해 증가)
}

# ===== 물리 타입 (Physical type) — 3종 =====
#
# 원소와 **독립된 두 번째 상성 축**이다. 총 약점 축 = 7 + 3 = 10개.
enum PhysicalType {
	SLASH,   # 참격 — 균형형
	PIERCE,  # 관통 — 후열 타격 우수, 다단 히트 (인성치 피해 x0.85)
	BLUNT,   # 강타 — 인성치 피해 우수 (x1.3), 밀치기
}

# ===== 역할 (Battle class) — 8종 =====
#
# 아이콘 하나로 역할을 소통하는 것이 목적이다. 각 역할은 `필수 보유 계약`이 있다
# (docs/turn-combat-design.md §역할 계약). 기존 `CharacterData.Role`(탱커/원거리/버퍼)은
# 실시간 전투와 시너지 계산이 쓰는 별개 축이므로 **대체하지 않고 나란히 둔다.**
enum BattleClass {
	BREAKER,    # 파괴자 — 광역 딜 + 자체 생존
	HUNTER,     # 추격자 — 단일 폭딜
	SCHOLAR,    # 현자   — 전체 딜
	CONDUCTOR,  # 조율자 — 버프
	BLIGHTER,   # 잠식자 — 디버프
	WARDEN,     # 수호자 — 방어
	MENDER,     # 치유자 — 회복
	SUMMONER,   # 소환사 — 소환
}

# ===== 데미지 버킷 (Damage bucket) =====
#
# **같은 버킷 안은 가산, 버킷끼리는 곱연산.** 시너지 설계의 전부가 여기서 나온다.
# 같은 버킷에 +50%를 3개 몰면 x2.5, 서로 다른 버킷에 나누면 x3.375 (35% 차이).
enum Bucket {
	BASE,           # 기본 데미지 — 공격력%, 고정 공격력, 스킬 배율
	DMG_BONUS,      # A: 피해증가%, 원소 피해
	DEFENSE,        # B: 방어력 감소 / 무시
	RESISTANCE,     # C: 원소 저항 관통
	VULNERABILITY,  # D: 받는 피해 증가 (취약)
	CRIT,           # E: 치명타 확률 / 치명타 피해
	BREAK_BONUS,    # F: 격파 특화 / 격파 상태 보너스
	HEAT,           # G: 열기 보정
}

# ===== 행동 종류 (Action kind) =====
enum ActionKind {
	BASIC,      # 일반공격 — 턴 소모, RP +1, 오의 +20
	SKILL,      # 전투 스킬 — 턴 소모, RP -1, 오의 +30
	ULTIMATE,   # 오의 — **턴 미소모**, 에너지 소모, 오의 +5
	TRAIT,      # 특성(추가공격) — 조건부 자동 발동, 오의 +10
	PREP,       # 준비(비술) — 전투 진입 전 사용
}

# ===== 타격 범위 (Targeting) =====
#
# 확산(BLAST)은 3D 거리가 아니라 **랭크 배열 인덱스 ±1**로 판정한다.
enum Targeting {
	SINGLE,        # 단일 — 대상 1명
	BLAST,         # 확산 — 대상 + 좌우 인접 1명씩(인접은 감소 배율)
	ALL_ENEMIES,   # 전체 — 적 전원
	BOUNCE,        # 튕김 — 무작위 대상에 N회 분산
	LINE,          # 관통 — 대상 랭크에서 뒤쪽으로 순차 타격
	SELF,          # 자신
	ALLY_SINGLE,   # 아군 1명
	ALLY_ALL,      # 아군 전체
}

# ===== 적 등급 (Enemy tier) =====
enum EnemyTier {
	MINION,  # 잡몹 — 자물쇠 1~2, 페이즈 없음
	ELITE,   # 정예 — 자물쇠 3~4
	BOSS,    # 보스 — 자물쇠 4~6, 페이즈 2~3, 격파 저항
}

# ===== 격파 상태이상 (Break status) =====
enum BreakStatus {
	BLEED,     # 열상 — 적 최대HP 2%/턴, 3턴
	BURN,      # 연소 — 공격력 60%/턴, 3턴, 3중첩
	FREEZE,    # 동결 — 1턴 완전 행동 불가, 해제 시 피해
	SHOCK,     # 감전 — 공격력 50%/턴 + 적이 스킬 사용 시 추가 피해
	FRACTURE,  # 균열 — 중첩형 도트(최대 5중첩), 격파마다 +2
	BIND,      # 속박 — 행동 지연 30% + 받는 피해 누적, 해제 시 폭발
	SIGIL,     # 각인 — 속도 -20%, 행동 지연 20%, 받는 피해 +12%
}

# ===== 기준 스탯 (Scaling stat) =====
#
# 스킬 배율이 무엇에 곱해지는가. 값은 전부 `PlayerStats`에서 파생한다.
enum Scaling {
	ATTACK,   # 공격력 (get_physical_attack)
	DEFENSE,  # 방어력 (get_physical_defense)
	MAX_HP,   # 최대 HP (get_max_hp)
	MAGIC,    # 마법 공격력 (get_magic_attack)
}

# ===== 정보 표시 단계 (Info detail) =====
#
# 문서 §4.8.2 의 난이도 옵션. 적 정보를 얼마나 공개하는가.
enum InfoDetail {
	VERBOSE,   # 상세 — 수치 전부
	STANDARD,  # 표준 — 아이콘만
	CHALLENGE, # 도전 — 정보 최소
}


# ===== 원소별 상수 =====

# 격파 데미지 원소 배율 (문서 §4.4.1).
#
# **트레이드오프**: 격파 데미지가 낮은 원소(침식·광휘)는 상태이상이 강력하다.
# 이 원칙을 깨면 원소가 곧 티어표가 된다.
const BREAK_MULTIPLIER := {
	Element.IMPACT: 2.0,
	Element.PYRO: 2.0,
	Element.GALE: 1.5,
	Element.CRYO: 1.0,
	Element.VOLT: 1.0,
	Element.CORROSION: 0.5,
	Element.LUMEN: 0.5,
}

# 원소 -> 격파 시 부여되는 상태이상.
const BREAK_STATUS := {
	Element.IMPACT: BreakStatus.BLEED,
	Element.PYRO: BreakStatus.BURN,
	Element.CRYO: BreakStatus.FREEZE,
	Element.VOLT: BreakStatus.SHOCK,
	Element.GALE: BreakStatus.FRACTURE,
	Element.CORROSION: BreakStatus.BIND,
	Element.LUMEN: BreakStatus.SIGIL,
}

# 원소 색상 (문서 §4.10.10).
#
# **전 게임에서 이 색을 다른 용도로 쓰지 않는다.** 색이 곧 라벨이기 때문이다.
# 색맹 대응: 색만으로 구분하지 않고 항상 `ELEMENT_GLYPH`의 고유 형태를 병기한다.
const ELEMENT_COLOR := {
	Element.IMPACT: Color("E8E8E8"),
	Element.PYRO: Color("FF6B35"),
	Element.CRYO: Color("4FC3F7"),
	Element.VOLT: Color("B388FF"),
	Element.GALE: Color("66D9A6"),
	Element.CORROSION: Color("7C4DFF"),
	Element.LUMEN: Color("FFD54F"),
}

# 원소별 **고유 형태** 문양. 색맹 모드에서 색이 빠져도 이것만으로 구분된다.
# 도형 프로토타입(Phase 0)에서는 이 문자를 그대로 그린다.
const ELEMENT_GLYPH := {
	Element.IMPACT: "◇",
	Element.PYRO: "▲",
	Element.CRYO: "❄",
	Element.VOLT: "⚡",
	Element.GALE: "≋",
	Element.CORROSION: "⬢",
	Element.LUMEN: "✦",
}

const PHYSICAL_GLYPH := {
	PhysicalType.SLASH: "/",
	PhysicalType.PIERCE: "↑",
	PhysicalType.BLUNT: "■",
}

# 물리 타입별 인성치 피해 배율 (문서 §4.15).
# 강타는 인성치를 잘 깎고, 관통은 덜 깎는 대신 다단 히트로 자물쇠를 여러 개 해제한다.
const PHYSICAL_TOUGHNESS_MULTIPLIER := {
	PhysicalType.SLASH: 1.0,
	PhysicalType.PIERCE: 0.85,
	PhysicalType.BLUNT: 1.3,
}

# UI 계열 색 (문서 §4.10.10).
const COLOR_BUFF := Color("4FC3F7")
const COLOR_DEBUFF := Color("FF4757")
const COLOR_NEUTRAL := Color("B0BEC5")
const COLOR_WARN := Color("FFA726")
const COLOR_DANGER := Color("E53935")
const COLOR_HEAL := Color("66BB6A")

# 전투 화면 색 (문서 §4.9.3).
const COLOR_ALLY_HP := Color("4FE0E8")     # 아군 HP — 시안
const COLOR_ENEMY_HP := Color("E0473B")    # 적 HP — 적색
const COLOR_TOUGHNESS := Color("F0F4FA")   # 인성치 — 백색 계열
const COLOR_ULT_READY := Color("3BE07A")   # 오의 준비 — 녹색 발광
const COLOR_PANEL := Color(0.039, 0.055, 0.094, 0.72)  # rgba(10,14,24,0.72)
const COLOR_PANEL_LINE := Color(1, 1, 1, 0.55)

# UI 기울기. 텍스트는 반대로 되돌려 읽을 수 있게 한다 (문서 §4.9.3).
const UI_SKEW_DEGREES := -12.0

# ===== 랭크 (Rank) =====
#
# 랭크는 **1부터** 센다. A1/E1 이 최전방이다.
const ALLY_RANK_COUNT := 4
const ENEMY_RANK_COUNT := 5
const ALL_ALLY_RANKS: Array[int] = [1, 2, 3, 4]
const ALL_ENEMY_RANKS: Array[int] = [1, 2, 3, 4, 5]


# ===== 표시 이름 (Display names) =====

const ELEMENT_NAME := {
	Element.IMPACT: "충격",
	Element.PYRO: "화염",
	Element.CRYO: "한기",
	Element.VOLT: "전격",
	Element.GALE: "풍압",
	Element.CORROSION: "침식",
	Element.LUMEN: "광휘",
}

const PHYSICAL_NAME := {
	PhysicalType.SLASH: "참격",
	PhysicalType.PIERCE: "관통",
	PhysicalType.BLUNT: "강타",
}

const CLASS_NAME := {
	BattleClass.BREAKER: "파괴자",
	BattleClass.HUNTER: "추격자",
	BattleClass.SCHOLAR: "현자",
	BattleClass.CONDUCTOR: "조율자",
	BattleClass.BLIGHTER: "잠식자",
	BattleClass.WARDEN: "수호자",
	BattleClass.MENDER: "치유자",
	BattleClass.SUMMONER: "소환사",
}

const BREAK_STATUS_NAME := {
	BreakStatus.BLEED: "열상",
	BreakStatus.BURN: "연소",
	BreakStatus.FREEZE: "동결",
	BreakStatus.SHOCK: "감전",
	BreakStatus.FRACTURE: "균열",
	BreakStatus.BIND: "속박",
	BreakStatus.SIGIL: "각인",
}

const ACTION_KIND_NAME := {
	ActionKind.BASIC: "일반공격",
	ActionKind.SKILL: "전투 스킬",
	ActionKind.ULTIMATE: "오의",
	ActionKind.TRAIT: "특성",
	ActionKind.PREP: "준비",
}

const TARGETING_NAME := {
	Targeting.SINGLE: "단일",
	Targeting.BLAST: "확산",
	Targeting.ALL_ENEMIES: "전체",
	Targeting.BOUNCE: "튕김",
	Targeting.LINE: "관통",
	Targeting.SELF: "자신",
	Targeting.ALLY_SINGLE: "아군 단일",
	Targeting.ALLY_ALL: "아군 전체",
}


# ===== 조회 헬퍼 (Lookups) =====
#
# `Dictionary.get()` 을 직접 쓰지 않고 이 함수를 쓴다 — 잘못된 정수가 들어와도
# 화면이 빈 문자열/검정색이 되지 않고 눈에 띄는 폴백이 나온다.

static func element_name(element: int) -> String:
	return ELEMENT_NAME.get(element, "?원소")

static func element_color(element: int) -> Color:
	return ELEMENT_COLOR.get(element, COLOR_NEUTRAL)

static func element_glyph(element: int) -> String:
	return ELEMENT_GLYPH.get(element, "?")

static func element_break_multiplier(element: int) -> float:
	return float(BREAK_MULTIPLIER.get(element, 1.0))

static func element_break_status(element: int) -> int:
	return int(BREAK_STATUS.get(element, BreakStatus.BLEED))

static func physical_name(physical: int) -> String:
	return PHYSICAL_NAME.get(physical, "?타입")

static func physical_glyph(physical: int) -> String:
	return PHYSICAL_GLYPH.get(physical, "?")

static func physical_toughness_multiplier(physical: int) -> float:
	return float(PHYSICAL_TOUGHNESS_MULTIPLIER.get(physical, 1.0))

static func class_name_of(battle_class: int) -> String:
	return CLASS_NAME.get(battle_class, "?역할")

static func break_status_name(status: int) -> String:
	return BREAK_STATUS_NAME.get(status, "?상태")

static func action_kind_name(kind: int) -> String:
	return ACTION_KIND_NAME.get(kind, "?행동")

static func targeting_name(targeting: int) -> String:
	return TARGETING_NAME.get(targeting, "?범위")

# 그 진영의 랭크 개수. 확산·관통 판정이 배열 밖으로 나가지 않게 한다.
static func rank_count(side: int) -> int:
	return ENEMY_RANK_COUNT if side == Side.ENEMY else ALLY_RANK_COUNT

# 전열(랭크 1~2)인가. 어그로 가중치와 근접 스킬 조건이 쓴다.
static func is_front_rank(rank: int) -> bool:
	return rank <= 2

# 자물쇠 한 칸의 요구 조건을 표시 문자로 만든다.
# 원소 자물쇠와 물리 자물쇠를 한 열에 섞어 표시하므로 형태로 구분되어야 한다.
static func lock_glyph(is_element: bool, value: int) -> String:
	return element_glyph(value) if is_element else physical_glyph(value)

static func lock_color(is_element: bool, value: int) -> Color:
	return element_color(value) if is_element else COLOR_NEUTRAL

static func lock_name(is_element: bool, value: int) -> String:
	return element_name(value) if is_element else physical_name(value)

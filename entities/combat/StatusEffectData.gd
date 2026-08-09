extends Resource
class_name StatusEffectData

# 버프/디버프(상태 효과)의 단일 정의 출처 (data definition only).
# 실제 적용/해제/틱 처리는 이번 범위 밖이며, 후속 이슈의 StatusEffectSystem이 이 데이터를 소비한다.
# (SkillData가 정의만 담고 발동 로직을 후속으로 넘긴 것과 같은 방식.)
#
# 대상(target): 캐릭터와 적 모두.
#   Player.stats 와 EnemyBase.stats 가 둘 다 PlayerStats이므로, PlayerStats를 타겟 채널로 삼으면
#   캐릭터·적 공통 적용이 성립한다. 적 전용 스텟을 따로 정의하지 않는다.
#
# 수치 출처: 전투 튜닝 수치는 data/combat/combat_tuning.tres(CombatTuning)가 유일한 출처이며
#   CombatConfig.tuning으로 접근한다.
#   payload 값이 비어 있으면(0) 그 값으로 폴백해 수치를 중복 정의하지 않는다.
#
# 참고: docs/combat-screen-design.md, autoload/CombatConfig.gd, SYSTEM_CONVENTIONS.md

# ===== 종류 (Kind) =====
# 상태 효과가 무엇을 하는지의 분류. 종류에 따라 아래 payload 중 해당 섹션을 사용한다.
enum Kind {
	STAT_MOD,   # 스텟 변경 (공격력/방어력/이속/공속 등)
	CONTROL,    # 행동 제약 (기절/속박/침묵 등 CC)
	PERIODIC,   # 지속 피해/회복 (DoT/HoT)
	GAUGE,      # 카운터/게이지 누적 (버퍼 표식 등)
}

# 기본값 STAT_MOD: 누락 시 안전하게 로드되도록 첫 값을 기본으로 둔다.
@export var kind: Kind = Kind.STAT_MOD

# ===== 중첩 규칙 (Stacking) =====
# 같은 효과가 중복 적용될 때의 처리. 효과별로 지정한다.
enum Stacking {
	REFRESH,          # 지속시간만 갱신 (세기는 그대로)
	STACK_INTENSITY,  # 세기 누적 (max_stacks까지)
	IGNORE,           # 이미 걸려 있으면 무시
}

@export var stacking: Stacking = Stacking.REFRESH
@export var max_stacks: int = 1   # STACK_INTENSITY에서만 의미가 있다. 최소 1.

# ===== 식별 (Identity) =====
@export var effect_id: StringName = &""   # 고유 식별자 (예: &"mark")
@export var display_name: String = ""      # 화면 표시 이름
@export_multiline var description: String = ""

# 버프/디버프 구분. UI 표시나 "디버프만 해제" 같은 규칙에서 참고한다.
@export var is_debuff: bool = false

# ===== 지속시간 (Duration) =====
# 0 이하 = 무한. 수동 해제하거나, GAUGE라면 임계치에 도달할 때까지 유지된다.
@export var duration: float = 0.0

# ===== STAT_MOD payload =====
# 가산(flat)과 배율(percent)을 함께 지원한다. PlayerStats의 "버프 채널"에 합산되며,
# 장비 채널(equip_*)과 독립적이라 서로 덮어쓰지 않는다.
#
# 키는 PlayerStats.set_buff_bonuses()가 받는 이름을 쓴다:
#   가산: physical_attack, magic_attack, physical_defense, magic_defense, max_hp
#   배율: physical_attack, magic_attack, physical_defense, magic_defense, attack_speed, move_speed
# 배율은 0.2 = +20%, -0.2 = -20% 로 해석한다(0 = 변화 없음).
@export var stat_flat: Dictionary = {}
@export var stat_percent: Dictionary = {}

# ===== CONTROL payload =====
# 무엇을 막는지. 기절이라면 이동·평타·스킬을 모두 막는 식으로 조합한다.
@export var blocks_movement: bool = false
@export var blocks_attack: bool = false
@export var blocks_skill: bool = false

# ===== PERIODIC payload =====
@export var tick_interval: float = 1.0   # 틱 간격(초). 0 이하는 적용 시 1.0으로 간주한다.
@export var tick_damage: int = 0         # 틱당 피해 (양수)
@export var tick_heal: int = 0           # 틱당 회복 (양수)

# ===== GAUGE payload =====
# 평타 등으로 누적되어 임계치에서 터지는 상태(버퍼 표식이 이 종류).
# 0이면 CombatConfig 값으로 폴백한다 (수치 중복 정의 금지).
@export var gauge_threshold: int = 0        # 0 = CombatConfig.MARK_THRESHOLD 사용
@export var gauge_gain_per_hit: int = 0     # 0 = CombatConfig.MARK_GAIN_PER_HIT 사용

# 임계치 도달 시 터지며 적용할 후속 효과 id (예: 표식 -> 기절).
# 비어 있으면 후속 효과 없이 소멸한다.
@export var on_threshold_effect_id: StringName = &""


# ===== 조회 헬퍼 (Accessors) =====
# CombatConfig 폴백을 적용한 실제 값을 반환한다.
# 후속 StatusEffectSystem은 아래 헬퍼를 통해 값을 읽는다(원시 필드 직접 사용 지양).

# 게이지 임계치. 0이면 CombatConfig의 튜닝 값이 출처.
func get_gauge_threshold() -> int:
	if gauge_threshold > 0:
		return gauge_threshold
	return CombatConfig.tuning.mark_threshold

# 평타 1회당 게이지 증가량. 0이면 CombatConfig의 튜닝 값이 출처.
func get_gauge_gain_per_hit() -> int:
	if gauge_gain_per_hit > 0:
		return gauge_gain_per_hit
	return CombatConfig.tuning.mark_gain_per_hit

# 유효 틱 간격. 0 이하는 1.0으로 보정한다.
func get_tick_interval() -> float:
	if tick_interval <= 0.0:
		return 1.0
	return tick_interval

# 중첩 상한. STACK_INTENSITY가 아니면 1, 그 외엔 최소 1을 보장한다.
func get_max_stacks() -> int:
	if stacking != Stacking.STACK_INTENSITY:
		return 1
	return max(max_stacks, 1)

# 지속시간이 무한인지 (0 이하 = 무한).
func is_permanent() -> bool:
	return duration <= 0.0

# 종류의 화면 표시용 한글 이름.
func get_kind_name() -> String:
	match kind:
		Kind.STAT_MOD:
			return "스텟 변경"
		Kind.CONTROL:
			return "행동 제약"
		Kind.PERIODIC:
			return "지속 피해/회복"
		Kind.GAUGE:
			return "게이지 누적"
		_:
			return "알 수 없음"


# ===== 무결성 점검 (Validation) =====
# 문제 메시지 배열을 반환한다. 비어 있으면 유효.
# CharacterData/EquipmentData의 validate()와 같은 규약.
func validate() -> Array[String]:
	var problems: Array[String] = []

	if String(effect_id).is_empty():
		problems.append("effect_id가 비어 있습니다.")
	if display_name.is_empty():
		problems.append("display_name이 비어 있습니다.")

	if stacking == Stacking.STACK_INTENSITY and max_stacks < 1:
		problems.append("STACK_INTENSITY인데 max_stacks가 1보다 작습니다.")

	match kind:
		Kind.CONTROL:
			if not (blocks_movement or blocks_attack or blocks_skill):
				problems.append("CONTROL인데 막는 행동이 하나도 없습니다.")
		Kind.PERIODIC:
			if tick_damage <= 0 and tick_heal <= 0:
				problems.append("PERIODIC인데 tick_damage/tick_heal이 모두 0입니다.")
		Kind.STAT_MOD:
			if stat_flat.is_empty() and stat_percent.is_empty():
				problems.append("STAT_MOD인데 stat_flat/stat_percent가 모두 비어 있습니다.")

	return problems

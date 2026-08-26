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
	EMPOWER,    # 전투 행동 부여 (흡혈/처형 등) — 스텟이 아니라 "할 수 있는 일"이 바뀐다
	TAUNT,      # 강제 대상 지정 — 걸린 동안 효과를 건 주체만 공격한다
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

# ===== 동반 효과 (Companion effect) =====
#
# 이 효과가 걸릴 때 **같은 대상에게 같은 주체로** 함께 걸리는 효과 id(#328).
#
# 왜 필요한가: 한 효과의 `kind` 는 하나다. 그런데 스킬 하나가 만드는 상태는 종류가
# 섞여 있다 — 하랑 E 는 공속(STAT_MOD) + 흡혈(EMPOWER) + 자기 지속 피해(PERIODIC)를
# 한꺼번에 건다. `kind` 를 여러 개 갖게 하면 payload 검사와 조회(`_sync_stat_mods`,
# `get_granted_lifesteal`, `_apply_periodic`)가 전부 "이 효과가 그 종류이기도 한가"를
# 묻게 되어, 종류로 갈라 둔 구조가 사라진다.
#
# 그래서 **효과는 종류마다 하나로 유지하고, 함께 걸리는 관계만 데이터로 적는다.**
# 스킬 쪽에 효과 목록을 두지 않은 이유도 같다 — "이 셋은 늘 같이 걸린다"는 것은
# 스킬의 성질이 아니라 효과 자신의 성질이라, 다른 스킬이 같은 상태를 걸 때도 따라와야 한다.
#
# 연쇄된다: A -> B -> C 로 이어도 된다. 순환은 StatusEffectSystem 이 끊는다.
# 해제는 연쇄되지 않는다 — 각자의 duration 으로 만료된다. 그래서 함께 걸리는 효과들은
# 보통 같은 duration 을 갖는다.
@export var also_apply_effect_id: StringName = &""

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

## 틱당 피해 = **대상의 최대 체력 x 이 비율**. tick_damage 에 더해진다(#328).
##
## 절대값(tick_damage)과 따로 둔 이유: 이 채널은 "그릇의 몇 퍼센트"가 계약이다.
## 하랑 E 의 자기 피해는 "7초 동안 최대 체력의 49%"가 스펙이라, 스텟 스케일이 바뀌어도
## 그 비율이 유지되어야 한다. 절대값으로 적으면 체력이 커질 때마다 같이 고쳐야 한다.
##
## 보호막(SkillData.shield_base)·아군 회복(ally_heal)이 **절대값**인 것과 반대 방향인데,
## 그쪽은 "시전자가 주는 것"이라 받는 사람의 그릇과 무관해야 하고, 이쪽은 애초에
## **자기 그릇을 대가로 내는 것**이라 비율이 맞다.
@export var tick_max_hp_percent: float = 0.0

## 이 틱 피해가 방어력을 무시하는가(#328).
##
## 기본은 false 다 — 피해 공식의 단일 출처(PlayerStats.apply_defense)를 우회하지 않는 것이
## 이 프로젝트의 규약이고, 적의 현재 체력 비례 피해(SkillData.current_hp_damage_percent)도
## 방어를 그대로 받는다.
##
## 예외를 둔 이유: **자기 자신에게 내는 대가**는 방어력에 깎이면 스펙이 무너진다.
## 방어 공식이 raw^2/(raw+def) 라 raw 가 작을 때 특히 크게 깎인다 — 하랑(체력 900,
## 물방 ~230)의 7% = 63 은 63^2/(63+230) = 14 로, 스펙의 22% 밖에 들어가지 않는다.
## 그러면 "체력을 태워 화력을 얻는다"는 거래 자체가 방어력 스텟에 따라 흔들린다.
##
## 보호막은 그대로 받아 낸다 — 이 값이 무시하는 것은 방어력뿐이다.
@export var tick_ignores_defense: bool = false

# ===== EMPOWER payload =====
#
# "무엇을 할 수 있게 되는가"를 부여한다(#276). 스텟(STAT_MOD)과 나눈 이유:
# 흡혈과 처형은 숫자가 아니라 **행동 규칙**이다. PlayerStats 에 채널이 없고, 있어서도 안 된다
# — 스텟은 값이고 이쪽은 분기다.
#
# 부여받은 쪽(Player)이 매 판정마다 이 효과가 걸려 있는지 물어본다.
# 효과가 스스로 무언가를 하지 않는다 — 지속시간이 끝나면 조회가 0/false 로 돌아갈 뿐이다.

## 이 효과가 걸린 동안, 대상이 **준 모든 피해** 중 회복되는 비율. 0 이면 흡혈을 주지 않는다.
##
## **평타만이 아니다.** 스킬·광역 패시브로 준 피해까지 전부 포함한다 — 원거리 3단계 시너지의
## 피흡(CombatTuning.lifesteal_percent, 평타 한정)과 **별개 채널**이라 둘 다 켜지면 함께 걸린다.
@export var grants_lifesteal_percent: float = 0.0

## 이 효과가 걸린 동안, 대상이 **평타로 처형**할 수 있는가.
##
## 켜져 있으면 버퍼 1단계 시너지가 꺼져 있어도, 대상에게 디버프가 없어도 처형이 나간다.
## 체력 임계치(CombatTuning.execute_hp_percent)는 그대로 지킨다 — 그것은 처형의 정의이지
## 조건이 아니다.
@export var grants_execute: bool = false

# ===== TAUNT payload =====
#
# **payload 가 없다.** 도발이 필요한 정보는 "누가 걸었는가" 하나이고, 그것은 이미
# StatusEffectSystem 이 효과 인스턴스마다 들고 있다(get_source). 여기 대상 필드를 두면
# 같은 값이 두 곳에 있게 된다.
#
# 걸린 동안 대상은 **효과를 건 주체만** 공격한다. 판정은 소비하는 쪽(EnemyBase._resolve_target)이
# 하고, 이 효과는 "그런 상태이다"만 표시한다 — CONTROL 이 무엇을 막는지만 적고 실제 차단은
# Player/EnemyBase 가 하는 것과 같은 규약이다.
#
# **탐지 범위를 무시한다.** 도발이 사거리 안에서만 듣는다면 이미 오고 있던 적에게는
# 아무 일도 하지 않는 것과 같다. 도발의 값어치는 멀리 있는 적을 끌어오는 것이다.
#
# 공속 변화 같은 수치는 여기 담지 않는다 — 그것은 STAT_MOD 의 일이고,
# 함께 걸어야 하면 also_apply_effect_id 로 잇는다.

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
		Kind.EMPOWER:
			return "행동 부여"
		Kind.TAUNT:
			return "강제 대상 지정"
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
			if tick_damage <= 0 and tick_heal <= 0 and tick_max_hp_percent <= 0.0:
				problems.append("PERIODIC인데 tick_damage/tick_heal/tick_max_hp_percent가 모두 0입니다.")
		Kind.STAT_MOD:
			if stat_flat.is_empty() and stat_percent.is_empty():
				problems.append("STAT_MOD인데 stat_flat/stat_percent가 모두 비어 있습니다.")
		Kind.EMPOWER:
			if grants_lifesteal_percent <= 0.0 and not grants_execute:
				problems.append("EMPOWER인데 부여하는 행동이 하나도 없습니다.")

	if grants_lifesteal_percent < 0.0:
		problems.append("grants_lifesteal_percent는 0 이상이어야 합니다.")

	if tick_max_hp_percent < 0.0:
		problems.append("tick_max_hp_percent는 0 이상이어야 합니다.")

	# 행동 부여는 시간이 끝나면 사라져야 한다. 영구 부여는 스킬이 아니라 패시브의 일이다.
	if kind == Kind.EMPOWER and is_permanent():
		problems.append("EMPOWER는 duration이 있어야 합니다(영구 부여는 상태 효과가 아니라 패시브다).")

	# 도발도 같은 이유로 시간이 있어야 한다. 영구 도발은 적 AI 를 영구히 한 대상에 묶는 것이라
	# 상태 효과가 아니라 적 정의(EnemyData)의 일이 된다.
	if kind == Kind.TAUNT and is_permanent():
		problems.append("TAUNT는 duration이 있어야 합니다(영구 도발은 상태 효과가 아니다).")

	# 자기 자신을 동반 효과로 두면 StatusEffectSystem 이 순환을 끊어 조용히 무시한다.
	# 저작 실수를 데이터 단계에서 잡는다.
	if also_apply_effect_id != &"" and also_apply_effect_id == effect_id:
		problems.append("also_apply_effect_id가 자기 자신(effect_id)입니다.")

	return problems

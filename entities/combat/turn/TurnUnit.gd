extends RefCounted
class_name TurnUnit

# 턴제 전투에 참여하는 **런타임 유닛 하나** (#450).
#
# 정의(`CharacterData` / `EnemyData`)와 런타임 상태를 잇는 자리다. 정의는 저작 데이터이므로
# 전투 중에 바뀌면 안 되고, 상태(HP·게이지·인성치·버프)는 전투마다 새로 만들어야 한다.
#
# **스텟은 여기서 계산하지 않는다.** `PlayerStats`가 소유하고, 이 클래스는 정의의
# `stats`를 **복제해** 들고 있다가 읽기만 한다(SYSTEM_CONVENTIONS §2 단일 출처).
# 복제가 필요한 이유: 버프 채널(`buff_*`)에 값을 쓰는데, 원본을 쓰면 저작된 `.tres`가
# 전투 중에 오염되어 다음 전투가 버프 걸린 상태로 시작한다.

# ===== 식별 (Identity) =====

## 전투 내 고유 식별자. 같은 적이 여러 마리 나오므로 정의 id로는 부족하다.
var unit_id: StringName = &""

var side: int = TurnCombat.Side.ALLY

## 랭크. 아군 1~4 / 적 1~5. 1이 최전방이다. 소유는 `RankSystem`이지만
## 조회가 잦아 여기에도 둔다 — 값을 바꾸는 것은 `RankSystem`만 한다.
var rank: int = 1

var display_name: String = ""

## 레벨. 방어 계수의 분모(`150 + 8 x 공격자레벨`)와 격파 데미지 기준값이 쓴다.
var level: int = 20

# ===== 정의 출처 (Definition) =====
#
# 둘 중 하나만 채워진다. 어느 쪽이든 스텟은 `stats`에서 읽는다.
var character: CharacterData = null
var enemy: EnemyData = null

## 정의의 스텟을 복제한 인스턴스. 버프/장비 채널이 여기에 쓰인다.
var stats: PlayerStats = null

# ===== 전투 상성 (Affinity) =====
var element: int = TurnCombat.Element.IMPACT
var physical_type: int = TurnCombat.PhysicalType.SLASH
var battle_class: int = TurnCombat.BattleClass.BREAKER

## 약점 원소 목록. 이 원소의 공격만 인성치를 깎는다.
var weak_elements: Array[int] = []
## 약점 물리 타입 목록.
var weak_physical: Array[int] = []

## 원소 저항. `Element` -> 비율(0.2 = 20% 감소). 없는 원소는 0이다.
## 버킷 C가 읽고, 저항 관통이 이 값을 뚫는다.
var element_resistances: Dictionary = {}

# ===== 생명 (Life) =====
var current_hp: int = 0

# ===== 자원 (Resources) =====
## 오의 게이지. 최대치는 `stats.get_energy_max()`.
var energy: int = 0

# ===== 인성치 (Toughness) =====
var max_toughness: int = 0
var toughness: int = 0
## 격파 상태인가.
var is_broken: bool = false
## 격파로 인해 행동하지 못하는 남은 턴 수.
var break_stun_left: int = 0
## 격파가 풀리기까지 남은 턴 수(인성치 회복 대기).
var break_recover_left: int = 0
## 격파 저항(0.0~1.0). 보스가 갖는다. 행동 불가 턴과 회복 속도를 줄인다.
var break_resistance: float = 0.0

# ===== 예고 (Intent) =====
var intent: TurnIntent = null

# ===== 상태 효과 (Statuses) =====
var statuses: Array[TurnStatus] = []

# ===== 행동 (Action bookkeeping) =====
## 이번 턴에 쓴 추가 턴 횟수. 하드캡(기본 2)에 쓴다.
var extra_turns_used: int = 0
## **연속으로** 받은 행동 앞당김 횟수. 2회차부터 효율이 절반이 된다(무한 루프 방지).
var advance_streak: int = 0
## 배턴 중첩. 양도받을 때마다 공격력이 오르고(최대 3회) 자기 턴이 끝나면 사라진다.
var baton_stacks: int = 0
## 디버프 부여가 이 유닛에게 연속으로 실패한 횟수. Pity 보정의 카운터다.
var debuff_failures: int = 0

## 살아 있는가. HP 0이 되면 false. 시체를 타임라인에서 즉시 빼기보다 플래그로 두는 이유:
## 처치 시 발동하는 특성·오의 게이지 획득이 그 순간의 참조를 필요로 한다.
var alive: bool = true

## 소환체인가. 소환체는 타임라인에 별도 유닛으로 참여하지만 파티 슬롯을 차지하지 않는다.
var is_summon: bool = false
## 소환한 주인의 `unit_id`.
var summoner_id: StringName = &""


# ===== 생성 (Construction) =====
#
# `_init`에 인자를 두지 않고 정적 팩토리를 쓴다 — 아군과 적이 채워야 하는 필드가
# 다르고, 어느 쪽인지 인자 순서로 구분하면 호출부에서 실수가 조용히 지나간다.

static func from_character(data: CharacterData, unit_rank: int, id_suffix: String = "",
		unit_level: int = 20) -> TurnUnit:
	var unit := TurnUnit.new()
	unit.character = data
	unit.side = TurnCombat.Side.ALLY
	unit.rank = unit_rank
	unit.display_name = data.display_name
	unit.unit_id = StringName(String(data.character_id) + id_suffix)
	unit.level = unit_level
	unit.element = data.element
	unit.physical_type = data.physical_type
	unit.battle_class = data.battle_class

	# 정의의 스텟을 복제한다. deep 복제여야 한다 — 얕은 복제는 같은 인스턴스를 공유해
	# 버프가 저작 데이터로 새어 들어간다.
	unit.stats = data.get_stats().duplicate(true) as PlayerStats
	unit.current_hp = unit.stats.get_max_hp()
	unit.energy = 0

	# 아군에게는 인성치가 없다. 인성치·자물쇠는 적을 격파하는 축이고, 아군에게도 주면
	# 두 진영이 같은 퍼즐을 서로 풀어야 해서 턴당 판단이 두 배가 된다(설계 범위 밖).
	unit.max_toughness = 0
	unit.toughness = 0

	return unit


static func from_enemy(data: EnemyData, unit_rank: int, id_suffix: String = "") -> TurnUnit:
	var unit := TurnUnit.new()
	unit.enemy = data
	unit.side = TurnCombat.Side.ENEMY
	unit.rank = unit_rank
	unit.display_name = data.display_name
	unit.unit_id = StringName(String(data.enemy_id) + id_suffix)
	unit.level = data.turn_level
	unit.element = data.turn_element
	unit.physical_type = data.turn_physical_type
	unit.battle_class = TurnCombat.BattleClass.BREAKER

	unit.stats = data.get_stats().duplicate(true) as PlayerStats
	# 턴제 스텟을 복제본에 심는다. 원본에 쓰면 전투를 반복할 때마다 값이 다시 덮이고,
	# 실시간 전투가 읽는 저작 데이터가 오염된다.
	_apply_turn_baseline(unit.stats, data)

	unit.current_hp = unit.stats.get_max_hp()
	unit.energy = 0

	unit.max_toughness = data.get_effective_toughness()
	unit.toughness = unit.max_toughness
	unit.break_resistance = data.break_resistance

	# `Array[TurnCombat.Element]` -> `Array[int]`. 타입이 달라 그대로 대입할 수 없다.
	for e in data.weak_elements:
		unit.weak_elements.append(int(e))
	for p in data.weak_physical:
		unit.weak_physical.append(int(p))
	unit.element_resistances = data.element_resistances.duplicate()

	return unit


# 턴제 기준 스텟을 스텟 복제본에 심는다.
#
# **왜 실시간 스텟에 배수를 곱하지 않는가**: 실시간 HP 는 연속 DPS 기준으로 잡혀 있어
# 턴제에서는 수백 턴이 된다(자세한 이유는 `TurnCombatTuning` 의 "적 기준 스탯" 주석).
# 그래서 레벨·등급에서 파생한 값을 쓴다.
#
# `strength`/`defense` 를 직접 쓰지 않고 **역산**하는 이유: 파생 규칙(근력 -> 공격력,
# 근력+방어력 -> 방어력)의 소유자는 `PlayerStats` 이고 계수는 `CombatTuning` 이다.
# 여기서 공격력을 직접 대입하면 그 규칙을 우회하는 두 번째 경로가 생긴다. 원하는
# 파생값이 나오는 기초 스텟을 계산해 넣으면 규칙은 하나로 남는다.
static func _apply_turn_baseline(target: PlayerStats, data: EnemyData) -> void:
	var coefficients := PlayerStats.get_tuning()

	target.hp = data.get_turn_hp()

	# 공격력 = 근력 x strength_to_phys_atk
	var want_attack := float(data.get_turn_attack())
	target.strength = maxi(int(round(want_attack / maxf(coefficients.strength_to_phys_atk, 0.01))), 1)

	# 방어력 = 근력 x strength_to_phys_def + 방어력 x defense_to_phys_def
	var want_defense := float(data.get_turn_defense())
	var from_strength := float(target.strength) * coefficients.strength_to_phys_def
	target.defense = maxi(int(round((want_defense - from_strength)
		/ maxf(coefficients.defense_to_phys_def, 0.01))), 0)

	# 성장 배수는 적에게 걸리지 않는다 — 삼각근 Lv.은 플레이어의 진행도다.
	target.growth_multiplier = 1.0


# ===== 스텟 조회 (Stat accessors) =====
#
# 전부 `stats`에 위임한다. 값을 여기에 복제하지 않는다.

func get_max_hp() -> int:
	return stats.get_max_hp()

func get_attack() -> int:
	return stats.get_physical_attack()

func get_magic_attack() -> int:
	return stats.get_magic_attack()

func get_defense() -> int:
	return stats.get_physical_defense()

func get_speed() -> int:
	return stats.get_speed()

func get_action_value() -> float:
	return stats.get_action_value()

func get_energy_max() -> int:
	return stats.get_energy_max()


# 기준 스탯 하나를 뽑는다. 스킬 효과의 `scaling`이 가리키는 값이다.
func get_scaling_value(scaling: int) -> int:
	match scaling:
		TurnCombat.Scaling.DEFENSE:
			return get_defense()
		TurnCombat.Scaling.MAX_HP:
			return get_max_hp()
		TurnCombat.Scaling.MAGIC:
			return get_magic_attack()
		_:
			return get_attack()


func get_hp_ratio() -> float:
	var max_hp := get_max_hp()
	if max_hp <= 0:
		return 0.0
	return clampf(float(current_hp) / float(max_hp), 0.0, 1.0)


func get_energy_ratio() -> float:
	var max_energy := get_energy_max()
	if max_energy <= 0:
		return 0.0
	return clampf(float(energy) / float(max_energy), 0.0, 1.0)


func get_toughness_ratio() -> float:
	if max_toughness <= 0:
		return 0.0
	return clampf(float(toughness) / float(max_toughness), 0.0, 1.0)


func is_ally() -> bool:
	return side == TurnCombat.Side.ALLY


func is_enemy() -> bool:
	return side == TurnCombat.Side.ENEMY


# ===== 약점 (Weakness) =====

# 이 공격이 약점을 찌르는가. **약점 공격만 인성치를 깎는다** — 비약점 공격은 HP만 깎는다.
#
# 두 축을 OR로 묶은 이유: 원소 약점과 물리 약점은 독립된 열쇠다. "한기가 약점"인 적에게
# 한기 강타를 넣으면 원소 쪽으로 약점이 성립하고, 강타가 약점이 아니어도 인성치는 깎인다.
func is_weak_to(attack_element: int, attack_physical: int) -> bool:
	return weak_elements.has(attack_element) or weak_physical.has(attack_physical)


# 이 원소에 대한 저항. 저작되지 않은 원소는 저항 0이다.
func get_element_resistance(attack_element: int) -> float:
	return clampf(float(element_resistances.get(attack_element, 0.0)), 0.0, 1.0)


# 약점 목록을 표시 문자열로. 적 정보 클러스터가 바 우측에 인라인으로 붙인다.
func format_weaknesses() -> String:
	var parts: Array[String] = []
	for e in weak_elements:
		parts.append(TurnCombat.element_glyph(e))
	for p in weak_physical:
		parts.append(TurnCombat.physical_glyph(p))
	return " ".join(parts)


# ===== 행동 가능 여부 (Can act) =====

# 이 유닛이 지금 행동할 수 있는가.
#
# 막는 것: 사망 / 격파 기절 / STUN 상태(동결 등).
func can_act() -> bool:
	if not alive:
		return false
	if break_stun_left > 0:
		return false
	if has_status_kind(TurnStatus.Kind.STUN):
		return false
	return true


# 행동을 못 하는 이유. UI와 전투 로그가 쓴다.
func blocked_reason() -> String:
	if not alive:
		return "전투 불능"
	if break_stun_left > 0:
		return "격파 (%d턴)" % break_stun_left
	for status in statuses:
		if status.kind == TurnStatus.Kind.STUN:
			return status.get_display_name()
	return ""


# 위치 이동에 면역인가 (고정/Anchor).
func is_anchored() -> bool:
	return has_status_kind(TurnStatus.Kind.ANCHOR)


func is_taunting() -> bool:
	return has_status_kind(TurnStatus.Kind.TAUNT)


# ===== 상태 효과 조회 (Status accessors) =====

func find_status(id: StringName) -> TurnStatus:
	for status in statuses:
		if status.id == id:
			return status
	return null


func has_status(id: StringName) -> bool:
	return find_status(id) != null


func has_status_kind(kind: int) -> bool:
	for status in statuses:
		if status.kind == kind:
			return true
	return false


# 격파 상태이상 하나를 찾는다. 원소별 격파가 건 것과 스킬이 건 것이 같은 목록에 있다.
#
# `kind` 로 거르지 않는 이유: 격파 상태이상은 종류가 갈린다 — 동결은 `STUN`, 연소는 `DOT`,
# 각인은 스탯 변화다. `DOT` 만 보면 동결이 조회되지 않아 "한기 격파가 걸리지 않은 것처럼"
# 보인다. **격파 상태이상의 정체성은 `break_status` 하나다.**
func find_break_status(break_status: int) -> TurnStatus:
	for status in statuses:
		if status.break_status == break_status and _is_break_status(status):
			return status
	return null


# 이 상태가 격파 상태이상인가. 버프/보호막의 기본값(`break_status = BLEED`)을 열상으로
# 오인하지 않기 위해 종류를 함께 본다.
func _is_break_status(status: TurnStatus) -> bool:
	return status.kind == TurnStatus.Kind.DOT or status.kind == TurnStatus.Kind.STUN


func get_break_status_stacks(break_status: int) -> int:
	var status := find_break_status(break_status)
	return status.stacks if status != null else 0


# 걸린 디버프 개수. "상태이상 3개 이상이면 추가 피해" 같은 조건이 쓴다.
func count_debuffs() -> int:
	var count := 0
	for status in statuses:
		if status.kind == TurnStatus.Kind.DEBUFF or status.kind == TurnStatus.Kind.DOT:
			count += 1
	return count


# 현재 보호막 총량. 여러 보호막이 겹치면 합산한다.
func get_shield_total() -> int:
	var total := 0
	for status in statuses:
		if status.kind == TurnStatus.Kind.SHIELD:
			total += status.shield_amount
	return total


# ===== 요약 (Summary) =====

# 디버그와 전투 로그가 읽는 한 줄. 헤드리스 테스트의 실패 메시지에도 쓴다.
func describe() -> String:
	var side_tag := "A" if is_ally() else "E"
	var text := "%s%d %s HP %d/%d" \
		% [side_tag, rank, display_name, current_hp, get_max_hp()]
	if max_toughness > 0:
		text += " 인성치 %d/%d" % [toughness, max_toughness]
	if is_broken:
		text += " [격파 %d턴]" % break_stun_left
	if get_energy_max() > 0:
		text += " 오의 %d/%d" % [energy, get_energy_max()]
	return text

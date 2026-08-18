extends RefCounted
class_name BalanceReference

# 하이브리드 C 밸런스 기준 (#157 장비 티어를 자로 삼는다).
#
# 흐름: 각 티어의 "권장(기대) 플레이어 전투력"을 산출하고, 그 기준으로 적 baseline을 낸다.
#       적 실제 스탯 = enemy_baseline(tier) × 개체 배수(EnemyData.hp/attack/defense_multiplier).
#
# 표준 적 = 서아(seoa)를 티어1 ×1.0으로 캘리브레이션한 상수다.
# 장비가 성장하면(상위 티어) 권장 전투력이 오르고, 적 baseline도 같은 비율로 따라 오른다.

const STANDARD_TIER := 1
const STANDARD_HP := 1200
const STANDARD_STRENGTH := 65
const STANDARD_DEFENSE := 120


# 티어 T의 권장 플레이어 로드아웃: 기본 PlayerStats + 티어 T 장비 풀세트.
# 풀세트 = 방어구 3부위 + 물리 무기(도끼). 거울/마법무기는 적 스탯 산출에서 제외한다
# (거울=여신강화 전용, 마법무기=평타 미소비).
static func expected_loadout(tier: int) -> PlayerStats:
	var s := PlayerStats.new()
	var bonus := _tier_equipment_bonus(tier)
	s.set_equipment_bonuses(
		bonus["physical_attack"], bonus["magic_attack"],
		bonus["physical_defense"], bonus["magic_defense"], bonus["hp"])
	return s


# 티어 T 권장 로드아웃의 유효 전투 지표(설계/문서/툴용).
static func expected_power(tier: int) -> Dictionary:
	var s := expected_loadout(tier)
	return {
		"effective_hp": s.get_max_hp(),
		"physical_attack": s.get_physical_attack(),
		"physical_defense": s.get_physical_defense(),
	}


# 적 baseline 원시 스탯(티어 T). 표준(티어1) 상수를 티어 배율로 스케일한다.
static func enemy_baseline(tier: int) -> Dictionary:
	return {
		"hp": int(round(STANDARD_HP * _tier_scale(tier, "effective_hp"))),
		"strength": int(round(STANDARD_STRENGTH * _tier_scale(tier, "physical_attack"))),
		"defense": int(round(STANDARD_DEFENSE * _tier_scale(tier, "physical_defense"))),
	}


# 표준(티어1) 대비 티어 T의 지표 배율.
static func _tier_scale(tier: int, key: String) -> float:
	var base := expected_power(STANDARD_TIER)
	var b: float = float(base[key])
	if b <= 0.0:
		return 1.0
	return float(expected_power(tier)[key]) / b


# EquipmentDatabase autoload을 런타임에 트리에서 가져온다.
# (정적 컨텍스트에서 autoload 전역 식별자를 컴파일 타임에 참조하면 로드 순서에 취약하므로 노드로 조회한다.)
static func _equipment_db() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EquipmentDatabase")
	return null

# 티어 T 장비 풀세트(방어구 3부위 + 물리무기)의 보너스 합. EquipmentDatabase에서 조회.
# DB가 아직 없으면(로드 순서) 0을 반환한다. 티어1 배율은 어차피 1.0이라 표준값이 그대로 나온다.
static func _tier_equipment_bonus(tier: int) -> Dictionary:
	var totals := {
		"physical_attack": 0, "magic_attack": 0,
		"physical_defense": 0, "magic_defense": 0, "hp": 0,
	}
	var db := _equipment_db()
	if db == null:
		return totals
	for id in db.get_all_ids():
		var d: EquipmentData = db.get_equipment(id)
		if d == null or d.tier != tier:
			continue
		if d.slot == EquipmentData.Slot.MIRROR:
			continue
		# 무기는 물리(도끼)만 권장 로드아웃에 포함한다.
		if d.slot == EquipmentData.Slot.WEAPON and d.attack_type != EquipmentData.AttackType.PHYSICAL:
			continue
		totals["physical_attack"] += d.physical_attack_bonus
		totals["magic_attack"] += d.magic_attack_bonus
		totals["physical_defense"] += d.physical_defense_bonus
		totals["magic_defense"] += d.magic_defense_bonus
		totals["hp"] += d.hp_bonus
	return totals

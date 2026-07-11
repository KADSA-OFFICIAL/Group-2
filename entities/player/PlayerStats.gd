extends Resource
class_name PlayerStats

# 플레이어 캐릭터 스텟 시스템
# 기초 스텟(HP, 근력, 방어력, 지능, 신앙심)을 보관하고
# 세부(파생) 스텟을 규칙에 따라 계산해 제공한다.
#
# 파생 규칙:
#   - 근력   -> 물리 공격력, 물리/마법 방어력에 기여
#   - 신앙심 -> 마법 공격력, 여신의 스킬 강화
#   - 방어력 -> 물리/마법 방어력 (근력 + 방어력 스텟 + 장비를 합산)
#   - 지능   -> 추후 설계 (값만 보관, 파생 계산에는 미연결)

# ===== 기초 스텟 (Base Stats) =====
@export var hp: int = 100            # 최대 HP
@export var strength: int = 10       # 근력 (삼각근 강화로 상승)
@export var defense: int = 10        # 방어력 (장비 + 근력 기반)
@export var intelligence: int = 10   # 지능 (추후 설계)
@export var faith: int = 10          # 신앙심

# ===== 장비 보너스 (Equipment Bonuses) =====
# 장비 시스템이 채워 넣는 입력값. 각 파생 스텟 계산에 합산된다.
# 모두 기본 0이라 장비가 없으면 파생 계산에 영향을 주지 않는다(기존 .tres 호환).
@export var equip_physical_defense: int = 0
@export var equip_magic_defense: int = 0
@export var equip_physical_attack: int = 0
@export var equip_magic_attack: int = 0
@export var equip_max_hp: int = 0

# ===== 기여 계수 (Contribution Coefficients) =====
const STRENGTH_TO_PHYS_ATK: float = 2.0    # 근력 1 -> 물리 공격력
const STRENGTH_TO_PHYS_DEF: float = 1.0    # 근력 1 -> 물리 방어력
const STRENGTH_TO_MAGIC_DEF: float = 0.5   # 근력 1 -> 마법 방어력
const DEFENSE_TO_PHYS_DEF: float = 1.5     # 방어력 1 -> 물리 방어력
const DEFENSE_TO_MAGIC_DEF: float = 1.5    # 방어력 1 -> 마법 방어력
const FAITH_TO_MAGIC_ATK: float = 2.0      # 신앙심 1 -> 마법 공격력
const FAITH_TO_SKILL_BOOST: float = 0.05   # 신앙심 1 -> 여신 스킬 강화 +5%


# ===== 세부 스텟 (Derived Stats) =====

# 최대 HP = 기초 HP + 장비 HP 보너스
func get_max_hp() -> int:
	return hp + equip_max_hp

# 물리 공격력 = 근력 기여 + 장비 보너스
func get_physical_attack() -> int:
	return int(round(strength * STRENGTH_TO_PHYS_ATK)) + equip_physical_attack

# 마법 공격력 = 신앙심 기여 + 장비 보너스
func get_magic_attack() -> int:
	return int(round(faith * FAITH_TO_MAGIC_ATK)) + equip_magic_attack

# 물리 방어력 = 근력 기여분 + 방어력 스텟 기여분 + 장비 (합산)
func get_physical_defense() -> int:
	var from_strength := strength * STRENGTH_TO_PHYS_DEF
	var from_defense := defense * DEFENSE_TO_PHYS_DEF
	return int(round(from_strength + from_defense)) + equip_physical_defense

# 마법 방어력 = 근력 기여분 + 방어력 스텟 기여분 + 장비 (합산)
func get_magic_defense() -> int:
	var from_strength := strength * STRENGTH_TO_MAGIC_DEF
	var from_defense := defense * DEFENSE_TO_MAGIC_DEF
	return int(round(from_strength + from_defense)) + equip_magic_defense

# 여신의 스킬 강화 배수 (신앙심 기여). 1.0 = 강화 없음.
func get_goddess_skill_boost() -> float:
	return 1.0 + faith * FAITH_TO_SKILL_BOOST


# ===== 성장 (Growth) =====

# 삼각근 강화: 근력을 올린다.
func train_deltoid(amount: int = 1) -> void:
	if amount <= 0:
		return
	strength += amount

# 장비 방어 보너스를 갱신한다 (장비 시스템에서 호출).
func set_equipment_defense(physical: int, magic: int) -> void:
	equip_physical_defense = max(physical, 0)
	equip_magic_defense = max(magic, 0)

# 장비 보너스 전체를 갱신한다 (CharacterData가 장착 상태를 합산해 호출).
# 음수는 0으로 클램프한다.
func set_equipment_bonuses(physical_attack: int, magic_attack: int, physical_defense: int, magic_defense: int, max_hp: int) -> void:
	equip_physical_attack = max(physical_attack, 0)
	equip_magic_attack = max(magic_attack, 0)
	equip_physical_defense = max(physical_defense, 0)
	equip_magic_defense = max(magic_defense, 0)
	equip_max_hp = max(max_hp, 0)


# ===== 디버그 (Debug) =====

# 모든 세부 스텟을 Dictionary로 반환 (테스트/UI/디버그용).
func get_derived_summary() -> Dictionary:
	return {
		"max_hp": get_max_hp(),
		"physical_attack": get_physical_attack(),
		"magic_attack": get_magic_attack(),
		"physical_defense": get_physical_defense(),
		"magic_defense": get_magic_defense(),
		"goddess_skill_boost": get_goddess_skill_boost(),
	}

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
@export var hp: int = 1000           # 최대 HP
@export var strength: int = 100      # 근력 (삼각근 강화로 상승)
@export var defense: int = 100       # 방어력 (장비 + 근력 기반)
@export var intelligence: int = 100  # 지능 (추후 설계)
@export var faith: int = 100          # 신앙심

# ===== 장비 보너스 (Equipment Bonuses) =====
# 장비 시스템이 채워 넣는 입력값. 각 파생 스텟 계산에 합산된다.
# 모두 기본 0이라 장비가 없으면 파생 계산에 영향을 주지 않는다(기존 .tres 호환).
@export var equip_physical_defense: int = 0
@export var equip_magic_defense: int = 0
@export var equip_physical_attack: int = 0
@export var equip_magic_attack: int = 0
@export var equip_max_hp: int = 0

# ===== 버프/디버프 보너스 (Status Effect Bonuses) =====
# 상태 효과 시스템이 채워 넣는 입력값. 장비 채널(equip_*)과 **독립적인 별도 채널**이라
# 서로 덮어쓰지 않고 함께 합산된다. (StatusEffectData.STAT_MOD가 이 채널을 쓴다.)
#
# 가산(flat): 기본값 0 -> 버프가 없으면 파생 계산에 영향을 주지 않는다.
@export var buff_physical_attack: int = 0
@export var buff_magic_attack: int = 0
@export var buff_physical_defense: int = 0
@export var buff_magic_defense: int = 0
@export var buff_max_hp: int = 0

# 배율(percent): 0.2 = +20%, -0.2 = -20%. 기본값 0.0 = 변화 없음.
# 최종 배수는 (1.0 + 값)이며 0.0 미만으로는 내려가지 않도록 클램프한다.
@export var buff_physical_attack_percent: float = 0.0
@export var buff_magic_attack_percent: float = 0.0
@export var buff_physical_defense_percent: float = 0.0
@export var buff_magic_defense_percent: float = 0.0
# 공속/이속은 PlayerStats에 기초 수치가 없다. 기본치는 CombatConfig가 소유하고,
# 여기서는 그 기본치에 곱할 배율만 제공한다(원딜 스택 등이 이 값을 올린다).
@export var buff_attack_speed_percent: float = 0.0
@export var buff_move_speed_percent: float = 0.0

# ===== 기여 계수 (Contribution Coefficients) =====
# 계수의 출처는 CombatTuning(data/combat/combat_tuning.tres)이다.
# PlayerStats는 값을 소유하지 않고 읽기만 하므로, 계수를 여기서 다시 정의하지 않는다.
# 밸런싱은 .tres 인스펙터에서 한다.

# 폴백용 기본 인스턴스.
# autoload 순서상 CharacterDatabase(.tres 로드)가 CombatConfig보다 먼저 초기화되고,
# 에디터 툴이나 단독 테스트에서는 autoload가 아예 없을 수도 있다.
# 그 경우에도 CombatTuning.gd의 기본값으로 안전하게 동작하도록 한다.
# (기본값의 정의처는 CombatTuning.gd 한 곳이며 여기에 복제하지 않는다.)
static var _fallback_tuning: CombatTuning = null

# 유효한 튜닝 리소스를 반환한다. CombatConfig를 쓸 수 없으면 기본값 인스턴스를 쓴다.
static func get_tuning() -> CombatTuning:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var cfg := (loop as SceneTree).root.get_node_or_null("CombatConfig")
		if cfg != null and cfg.tuning != null:
			return cfg.tuning

	if _fallback_tuning == null:
		_fallback_tuning = CombatTuning.new()
	return _fallback_tuning


# ===== 세부 스텟 (Derived Stats) =====
#
# 합산 순서: (기초 기여 + 장비 가산 + 버프 가산) * 버프 배수
# 버프 채널이 비어 있으면(가산 0 / 배율 0.0) 결과는 장비까지만 합산한 기존 값과 동일하다.

# 버프 배율을 최종 배수로 바꾼다. (1.0 = 변화 없음, 0.0 미만은 클램프)
func _buff_multiplier(percent: float) -> float:
	return max(1.0 + percent, 0.0)

# 최대 HP = 기초 HP + 장비 HP 보너스 + 버프 HP 보너스
func get_max_hp() -> int:
	return hp + equip_max_hp + buff_max_hp

# 물리 공격력 = 근력 기여 + 장비 보너스 + 버프 (가산 후 배율)
func get_physical_attack() -> int:
	var t := get_tuning()
	var total := float(int(round(strength * t.strength_to_phys_atk)) + equip_physical_attack + buff_physical_attack)
	return int(round(total * _buff_multiplier(buff_physical_attack_percent)))

# 마법 공격력 = 신앙심 기여 + 장비 보너스 + 버프 (가산 후 배율)
func get_magic_attack() -> int:
	var t := get_tuning()
	var total := float(int(round(faith * t.faith_to_magic_atk)) + equip_magic_attack + buff_magic_attack)
	return int(round(total * _buff_multiplier(buff_magic_attack_percent)))

# 물리 방어력 = 근력 기여분 + 방어력 스텟 기여분 + 장비 + 버프 (가산 후 배율)
func get_physical_defense() -> int:
	var t := get_tuning()
	var from_strength := strength * t.strength_to_phys_def
	var from_defense := defense * t.defense_to_phys_def
	var total := float(int(round(from_strength + from_defense)) + equip_physical_defense + buff_physical_defense)
	return int(round(total * _buff_multiplier(buff_physical_defense_percent)))

# 마법 방어력 = 근력 기여분 + 방어력 스텟 기여분 + 장비 + 버프 (가산 후 배율)
func get_magic_defense() -> int:
	var t := get_tuning()
	var from_strength := strength * t.strength_to_magic_def
	var from_defense := defense * t.defense_to_magic_def
	var total := float(int(round(from_strength + from_defense)) + equip_magic_defense + buff_magic_defense)
	return int(round(total * _buff_multiplier(buff_magic_defense_percent)))

# 공격 속도 배수. 기초 쿨다운은 CombatConfig.BASE_ATTACK_COOLDOWN이 소유한다.
# 사용 예: 실제 쿨다운 = CombatConfig.BASE_ATTACK_COOLDOWN / get_attack_speed_multiplier()
func get_attack_speed_multiplier() -> float:
	return _buff_multiplier(buff_attack_speed_percent)

# 이동 속도 배수. 기초 이동속도는 CombatConfig.BASE_MOVE_SPEED가 소유한다.
# 사용 예: 실제 이동속도 = CombatConfig.BASE_MOVE_SPEED * get_move_speed_multiplier()
func get_move_speed_multiplier() -> float:
	return _buff_multiplier(buff_move_speed_percent)

# 여신의 스킬 강화 배수 (신앙심 기여). 1.0 = 강화 없음.
func get_goddess_skill_boost() -> float:
	return 1.0 + faith * get_tuning().faith_to_skill_boost


# ===== 피해 계산 (Damage) =====

# 들어온 피해에 이 대상의 물리 방어력을 적용해 실제 피해를 반환한다.
#
# 스케일 불변 공식: 피해 = 원피해² / (원피해 + 방어력)
#
#   성질:
#     방어력 0          -> 피해 전량
#     방어력 = 원피해   -> 정확히 절반
#     방어력 = 원피해x3 -> 정확히 1/4
#
#   왜 이 공식인가:
#     ① 감산(원피해 - 방어력)은 방어가 공격을 넘으면 피해가 최소치로 눌리고,
#        경계 근처에서 스텟 1포인트가 피해를 몇 배로 바꿔 밸런싱이 불가능했다.
#     ② 이전의 K 비율식(원피해 x K/(K+방어력))은 K가 방어력의 **절대 스케일**에 묶여 있었다.
#        스탯을 10배 하면 피해가 10배가 아니라 뭉개져, 스케일을 바꿀 때마다 K를 다시
#        조정해야 했다.
#     이 공식은 상수가 없어 **스케일 불변**이다. 공격력과 방어력을 함께 k배 하면
#     피해도 정확히 k배가 되므로, 스탯 스케일을 바꿔도 공식을 다시 만지지 않는다.
#
# **피해 공식은 이 메서드에만 존재한다.** Player와 EnemyBase가 각자 계산하지 않고
# 이 메서드를 호출한다.
func apply_defense(raw_damage: int) -> int:
	var t := get_tuning()
	var raw := float(raw_damage)
	var def := maxf(float(get_physical_defense()), 0.0)

	# 원피해가 0 이하면 방어를 적용할 것이 없다(0으로 나누는 것도 막는다).
	if raw <= 0.0:
		return t.damage_min

	var reduced: float = raw * raw / (raw + def)
	return maxi(int(round(reduced)), t.damage_min)


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

# 버프/디버프 보너스 전체를 갱신한다 (상태 효과 시스템에서 호출).
# 장비 채널과 별도이므로 이 호출은 equip_* 값을 건드리지 않는다.
#
# 여러 상태 효과가 걸려 있으면 호출자가 합산한 결과를 한 번에 넘긴다.
# flat 키:    physical_attack, magic_attack, physical_defense, magic_defense, max_hp
# percent 키: physical_attack, magic_attack, physical_defense, magic_defense,
#             attack_speed, move_speed   (0.2 = +20%)
#
# 디버프도 표현해야 하므로 가산은 음수를 허용한다(장비 채널과 달리 클램프하지 않는다).
# 최종 파생값은 각 getter에서 배수를 0.0 미만으로 내려가지 않게 클램프한다.
func set_buff_bonuses(flat: Dictionary = {}, percent: Dictionary = {}) -> void:
	buff_physical_attack = int(flat.get("physical_attack", 0))
	buff_magic_attack = int(flat.get("magic_attack", 0))
	buff_physical_defense = int(flat.get("physical_defense", 0))
	buff_magic_defense = int(flat.get("magic_defense", 0))
	buff_max_hp = int(flat.get("max_hp", 0))

	buff_physical_attack_percent = float(percent.get("physical_attack", 0.0))
	buff_magic_attack_percent = float(percent.get("magic_attack", 0.0))
	buff_physical_defense_percent = float(percent.get("physical_defense", 0.0))
	buff_magic_defense_percent = float(percent.get("magic_defense", 0.0))
	buff_attack_speed_percent = float(percent.get("attack_speed", 0.0))
	buff_move_speed_percent = float(percent.get("move_speed", 0.0))

# 모든 버프/디버프 보너스를 해제한다 (상태 효과가 전부 사라졌을 때).
func clear_buff_bonuses() -> void:
	set_buff_bonuses({}, {})


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
		"attack_speed_multiplier": get_attack_speed_multiplier(),
		"move_speed_multiplier": get_move_speed_multiplier(),
	}

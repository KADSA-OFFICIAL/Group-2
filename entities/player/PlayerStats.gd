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

# ===== 성장 채널 (Growth) =====
# 삼각근 Lv.이 만드는 기초 스텟 배수. 1.0 = Lv.1(보너스 없음).
# 밀어 넣는 쪽은 PlayerProfile 이고, 대상은 로스터 캐릭터뿐이다.
#
# @export 가 아닌 이유: 이 값의 출처는 플레이어 진행도(세이브)이지 캐릭터 저작
# 데이터가 아니다. .tres 에 굳으면 같은 값이 저작 파일과 세이브 두 곳에 남는다.
#
# 적(EnemyData.stats)도 이 클래스를 공유하므로 여기서 PlayerProfile 을 직접 읽지
# 않는다. 그러면 적까지 같이 강해진다. 장비(equip_*)·버프(buff_*) 와 같은 입력 채널이다.
var growth_multiplier: float = 1.0

# ===== 장비 보너스 (Equipment Bonuses) =====
# 장비 시스템이 채워 넣는 입력값. 각 파생 스텟 계산에 합산된다.
# 모두 기본 0이라 장비가 없으면 파생 계산에 영향을 주지 않는다(기존 .tres 호환).
@export var equip_physical_defense: int = 0
@export var equip_magic_defense: int = 0
@export var equip_physical_attack: int = 0
@export var equip_magic_attack: int = 0
@export var equip_max_hp: int = 0
# 이동속도(비율, 0.05 = +5%)와 여신 스킬 강화(가산, 0.10 = +10%p) 장비 입력.
@export var equip_move_speed_percent: float = 0.0
@export var equip_goddess_boost: float = 0.0

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

## **받는 피해** 배율의 변화분(#334). -0.25 면 받는 피해가 25% 줄고, +0.25 면 25% 늘어난다.
##
## 방어력(buff_physical_defense_percent)과 왜 따로인가: 피해 공식이 `raw^2/(raw+def)` 라
## 방어력을 올려도 **"받는 피해 몇 퍼센트 감소"가 되지 않는다.** 같은 방어력 증가가 원피해
## 크기에 따라 전혀 다른 감소율을 낸다 — 작은 타격은 크게 깎이고 큰 타격은 덜 깎인다.
## 강지 Q 처럼 "받는 피해가 감소한다"가 스펙인 효과는 그 스펙대로 표현되어야 한다.
##
## 적용 지점은 대상의 take_damage() 이며 **방어력 적용 뒤**다. 방어를 무시하는 피해
## (StatusEffectData.tick_ignores_defense)에도 이 감소는 걸린다 — 무시 대상은 방어력이고
## 이 채널은 별개다.
@export var buff_damage_taken_percent: float = 0.0

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


# ===== 기초 스텟 조회 (Base stat accessors) =====
#
# 저작된 기초값에 성장 배수를 적용한 값이다. **파생 계산과 화면은 이쪽을 읽는다.**
# 필드를 직접 읽으면 삼각근 Lv.이 반영되지 않는다.

func _grown(base: int) -> int:
	return int(round(float(base) * growth_multiplier))

func get_hp() -> int:
	return _grown(hp)

func get_strength() -> int:
	return _grown(strength)

func get_defense() -> int:
	return _grown(defense)

func get_intelligence() -> int:
	return _grown(intelligence)

func get_faith() -> int:
	return _grown(faith)


# ===== 세부 스텟 (Derived Stats) =====
#
# 합산 순서: (기초 기여 + 장비 가산 + 버프 가산) * 버프 배수
# 버프 채널이 비어 있으면(가산 0 / 배율 0.0) 결과는 장비까지만 합산한 기존 값과 동일하다.

# 버프 배율을 최종 배수로 바꾼다. (1.0 = 변화 없음, 0.0 미만은 클램프)
func _buff_multiplier(percent: float) -> float:
	return max(1.0 + percent, 0.0)

# 최대 HP = 기초 HP + 장비 HP 보너스 + 버프 HP 보너스
func get_max_hp() -> int:
	return get_hp() + equip_max_hp + buff_max_hp

# 물리 공격력 = 근력 기여 + 장비 보너스 + 버프 (가산 후 배율)
func get_physical_attack() -> int:
	var t := get_tuning()
	var total := float(int(round(get_strength() * t.strength_to_phys_atk)) + equip_physical_attack + buff_physical_attack)
	return int(round(total * _buff_multiplier(buff_physical_attack_percent)))

# 마법 공격력 = 신앙심 기여 + 장비 보너스 + 버프 (가산 후 배율)
func get_magic_attack() -> int:
	var t := get_tuning()
	var total := float(int(round(get_faith() * t.faith_to_magic_atk)) + equip_magic_attack + buff_magic_attack)
	return int(round(total * _buff_multiplier(buff_magic_attack_percent)))

# 물리 방어력 = 근력 기여분 + 방어력 스텟 기여분 + 장비 + 버프 (가산 후 배율)
func get_physical_defense() -> int:
	var t := get_tuning()
	var from_strength := get_strength() * t.strength_to_phys_def
	var from_defense := get_defense() * t.defense_to_phys_def
	var total := float(int(round(from_strength + from_defense)) + equip_physical_defense + buff_physical_defense)
	return int(round(total * _buff_multiplier(buff_physical_defense_percent)))

# 마법 방어력 = 근력 기여분 + 방어력 스텟 기여분 + 장비 + 버프 (가산 후 배율)
func get_magic_defense() -> int:
	var t := get_tuning()
	var from_strength := get_strength() * t.strength_to_magic_def
	var from_defense := get_defense() * t.defense_to_magic_def
	var total := float(int(round(from_strength + from_defense)) + equip_magic_defense + buff_magic_defense)
	return int(round(total * _buff_multiplier(buff_magic_defense_percent)))

# 공격 속도 배수. 기초 쿨다운은 CombatConfig.BASE_ATTACK_COOLDOWN이 소유한다.
# 사용 예: 실제 쿨다운 = CombatConfig.BASE_ATTACK_COOLDOWN / get_attack_speed_multiplier()
func get_attack_speed_multiplier() -> float:
	return _buff_multiplier(buff_attack_speed_percent)

# 이동 속도 배수. 기초 이동속도는 CombatConfig.BASE_MOVE_SPEED가 소유한다.
# 사용 예: 실제 이동속도 = CombatConfig.BASE_MOVE_SPEED * get_move_speed_multiplier()
func get_move_speed_multiplier() -> float:
	return _buff_multiplier(buff_move_speed_percent + equip_move_speed_percent)

# 여신의 스킬 강화 배수 (신앙심 기여 + 장비). 1.0 = 강화 없음.
#
# 신앙심은 get_faith() 로 읽는다 — 마법 공격력과 같은 스텟에서 나오는 값이므로
# 삼각근 Lv.의 성장도 같이 받아야 한다. equip_goddess_boost 는 장비 채널이라
# 성장 배수를 받지 않는다(기초 스텟이 아니다).
func get_goddess_skill_boost() -> float:
	return 1.0 + get_faith() * get_tuning().faith_to_skill_boost + equip_goddess_boost


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


# 받는 피해 배율. 1.0 = 변화 없음, 0.75 = 받는 피해 25% 감소(#334).
#
# 방어력과 왜 다른 통로인가는 buff_damage_taken_percent 주석에 있다 —
# 방어 공식이 비선형이라 "받는 피해 N% 감소"를 방어력으로 표현할 수 없다.
func get_damage_taken_multiplier() -> float:
	return _buff_multiplier(buff_damage_taken_percent)


# 방어력이 적용된 피해에 **받는 피해 배율**까지 반영한 최종 피해(#334).
#
# 방어와 나눠 둔 이유: 방어를 무시하는 피해(StatusEffectData.tick_ignores_defense)도
# 이 감소는 받아야 한다. 한 함수로 뭉치면 방어를 건너뛸 때 감소까지 함께 사라진다.
#
# 최소 피해(damage_min)는 여기서도 지킨다 — 감소로 0 이 되면 무적과 구분되지 않는다.
# 무적은 별개 통로(StatusEffectData.grants_invulnerable)가 담당한다.
func apply_damage_taken(damage: int) -> int:
	if damage <= 0:
		return damage
	var multiplier := get_damage_taken_multiplier()
	if is_equal_approx(multiplier, 1.0):
		return damage
	return maxi(int(round(float(damage) * multiplier)), get_tuning().damage_min)


# ===== 성장 (Growth) =====

# 삼각근 Lv.의 스텟 배수를 갱신한다 (PlayerProfile 이 호출).
#
# 이전의 train_deltoid() 를 대체한다. 근력만 직접 더하던 방식은 성장이 어디까지
# 진행됐는지 되돌아볼 수 없고(누적분이 기초값에 섞인다) 세이브와도 이어지지 않았다.
# 이제 성장의 출처는 PlayerProfile 의 삼각근 Lv. 하나다.
func set_growth_multiplier(value: float) -> void:
	growth_multiplier = maxf(value, 0.0)

# 장비 방어 보너스를 갱신한다 (장비 시스템에서 호출).
func set_equipment_defense(physical: int, magic: int) -> void:
	equip_physical_defense = max(physical, 0)
	equip_magic_defense = max(magic, 0)

# 장비 보너스 전체를 갱신한다 (CharacterData가 장착 상태를 합산해 호출).
# 음수는 0으로 클램프한다.
func set_equipment_bonuses(physical_attack: int, magic_attack: int, physical_defense: int, magic_defense: int, max_hp: int, move_speed_percent: float = 0.0, goddess_boost: float = 0.0) -> void:
	equip_physical_attack = max(physical_attack, 0)
	equip_magic_attack = max(magic_attack, 0)
	equip_physical_defense = max(physical_defense, 0)
	equip_magic_defense = max(magic_defense, 0)
	equip_max_hp = max(max_hp, 0)
	equip_move_speed_percent = max(move_speed_percent, 0.0)
	equip_goddess_boost = max(goddess_boost, 0.0)

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
	buff_damage_taken_percent = float(percent.get("damage_taken", 0.0))

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
		"damage_taken_multiplier": get_damage_taken_multiplier(),
	}


# =====================================================================
# 턴제 스텟 (Turn-based stats) — #450
# =====================================================================
#
# 왜 여기에 두는가: 스텟의 단일 출처는 `PlayerStats` 하나다(SYSTEM_CONVENTIONS §2).
# 턴제 전투용 스텟을 별도 리소스로 만들면 같은 캐릭터의 스텟이 두 파일에 나뉘어,
# 장비·버프·성장 배수를 각자 다시 구현해야 한다.
#
# 기존 필드와의 관계: 위쪽 실시간 파생 스텟(`get_physical_attack()`, `apply_defense()` 등)은
# **하나도 건드리지 않았다.** 턴제는 아래 스텟을 추가로 읽을 뿐이고, 실시간 전투의 결과는
# 이 섹션이 있든 없든 같다.
#
# 기본값의 원칙: 전부 **"효과 없음"**에 해당하는 값이다. 그래서 이 섹션을 모르는 기존
# `.tres`(캐릭터 6인 · 적 6종)가 그대로 로드되고, 턴제에서도 표준 유닛으로 동작한다.

# ===== 기초 (Base) =====

## 속도(SPD). 행동값 `AV = av_scale / SPD`를 결정한다 — 턴제 전투의 뼈대다.
## 100이 "1사이클 1행동" 기준선이다(설계서 §4.2.3).
@export var speed: int = 100

## 오의(필살기) 게이지 최대치. 캐릭터마다 100 / 120 / 140 등으로 다르다.
## 0이면 오의가 없는 유닛(잡몹 등)으로 취급한다.
@export var energy_max: int = 0

# ===== 치명타 (Crit) =====
#
# 비율로 저장한다. 0.05 = 5%. 기본값은 "치명타가 거의 나지 않는" 표준선이다.
@export var crit_rate: float = 0.05
## 치명타 시 곱해지는 **추가** 피해. 0.5 = 치명타 배율 1.5배.
@export var crit_damage: float = 0.5

# ===== 격파 / 인성치 (Break) =====

## 격파 특화. 격파·초격파 피해에 곱연산(버킷 F). 0.0 = 보너스 없음.
@export var break_effect: float = 0.0
## 인성치 피해 배율. 자물쇠 해제 효율에 곱해진다. 0.0 = 기본(x1.0).
@export var toughness_damage_bonus: float = 0.0

# ===== 확률 (Chance) =====

## 효과 적중. 디버프 부여 성공률에 가산된다.
@export var effect_hit: float = 0.0
## 효과 저항. 디버프를 튕겨 낼 확률. 상한은 튜닝의 `effect_res_cap`(기본 80%).
@export var effect_res: float = 0.0

# ===== 배율 (Multipliers) =====

## 오의 회복 효율. 에너지 획득량에 곱연산. 0.0 = x1.0.
@export var energy_recharge: float = 0.0
## 회복량 증가. 힐 배율에 곱연산. 0.0 = x1.0.
@export var heal_boost: float = 0.0
## 원소 피해 보너스 (버킷 A). 0.0 = 보너스 없음.
@export var element_damage_bonus: float = 0.0

# ===== 장비 채널 (Equipment channel) =====
#
# 장비 시스템이 채워 넣는 입력값. 실시간 `equip_*`와 같은 성격이며 서로 독립적이다.
@export var equip_speed: int = 0
@export var equip_crit_rate: float = 0.0
@export var equip_crit_damage: float = 0.0
@export var equip_break_effect: float = 0.0
@export var equip_effect_hit: float = 0.0
@export var equip_effect_res: float = 0.0
@export var equip_energy_recharge: float = 0.0
@export var equip_heal_boost: float = 0.0
@export var equip_element_damage_bonus: float = 0.0

# ===== 버프 채널 (Buff channel) =====
#
# 턴제 상태 효과(`TurnStatusSystem`)가 채워 넣는 입력값.
# 장비 채널과 **독립적인 별도 채널**이라 서로 덮어쓰지 않고 함께 합산된다.
# 디버프도 표현해야 하므로 음수를 허용한다.
@export var buff_speed: int = 0
## 속도 **배율**의 변화분. 각인(광휘 격파)의 "속도 -20%"가 이 채널을 쓴다.
@export var buff_speed_percent: float = 0.0
@export var buff_crit_rate: float = 0.0
@export var buff_crit_damage: float = 0.0
@export var buff_break_effect: float = 0.0
@export var buff_effect_hit: float = 0.0
@export var buff_effect_res: float = 0.0
@export var buff_energy_recharge: float = 0.0
@export var buff_heal_boost: float = 0.0
@export var buff_element_damage_bonus: float = 0.0
## 버킷 D — 받는 피해 증가(취약). 위쪽 `buff_damage_taken_percent`(실시간 감소 통로)와
## 별개로 둔 이유: 실시간 쪽은 "받는 피해 N% 감소"라는 확정 스펙을 표현하는 자리이고,
## 이쪽은 턴제 데미지 파이프라인의 **버킷 D 합산값**이다. 한 필드에 섞으면 실시간
## 강지 Q의 감소가 턴제 취약과 같은 통에 들어가 서로를 지운다.
@export var buff_vulnerability: float = 0.0
## 버킷 A — 피해증가%.
@export var buff_damage_bonus: float = 0.0
## 버킷 B — 방어력 감소 비율. 0.32 = 방어력 32% 감소.
@export var buff_defense_reduction: float = 0.0
## 버킷 C — 원소 저항 관통.
@export var buff_res_penetration: float = 0.0


# ===== 턴제 파생 스텟 (Turn-based derived) =====
#
# 합산 순서는 실시간 파생과 같다: (기초 + 장비 + 버프) 에 배율.
# 기초값에는 성장 배수(`growth_multiplier`)를 태운다 — 삼각근 Lv.이 속도에도 반영되어야
# 같은 캐릭터가 실시간과 턴제에서 다른 성장을 갖지 않는다.

## 속도. 소프트캡은 여기서 걸지 않는다 — 캡은 행동값을 만드는
## `TurnCombatTuning.action_value_for_speed()` 한 곳에서만 적용한다(화면마다 다른
## 숫자가 나오지 않게 하려는 것이다).
func get_speed() -> int:
	var total := float(_grown(speed) + equip_speed + buff_speed)
	return maxi(int(round(total * _buff_multiplier(buff_speed_percent))), 1)

func get_energy_max() -> int:
	return maxi(energy_max, 0)

func get_crit_rate() -> float:
	return maxf(crit_rate + equip_crit_rate + buff_crit_rate, 0.0)

func get_crit_damage() -> float:
	return maxf(crit_damage + equip_crit_damage + buff_crit_damage, 0.0)

func get_break_effect() -> float:
	return maxf(break_effect + equip_break_effect + buff_break_effect, 0.0)

func get_toughness_damage_multiplier() -> float:
	return maxf(1.0 + toughness_damage_bonus, 0.0)

func get_effect_hit() -> float:
	return maxf(effect_hit + equip_effect_hit + buff_effect_hit, 0.0)

## 효과 저항. 상한(기본 80%)을 넘지 않는다 — 100%가 되면 디버프 자체가 죽는다.
func get_effect_res() -> float:
	var total := effect_res + equip_effect_res + buff_effect_res
	return clampf(total, 0.0, get_tuning_turn().effect_res_cap)

func get_energy_recharge_multiplier() -> float:
	return maxf(1.0 + energy_recharge + equip_energy_recharge + buff_energy_recharge, 0.0)

func get_heal_boost_multiplier() -> float:
	return maxf(1.0 + heal_boost + equip_heal_boost + buff_heal_boost, 0.0)

## 버킷 A 합산값 — 원소 피해 보너스 + 피해증가%.
func get_damage_bonus() -> float:
	return element_damage_bonus + equip_element_damage_bonus \
		+ buff_element_damage_bonus + buff_damage_bonus

## 버킷 B — 방어력 감소 비율. 1.0을 넘으면 방어력이 음수가 되므로 클램프한다.
func get_defense_reduction() -> float:
	return clampf(buff_defense_reduction, 0.0, 1.0)

## 버킷 C — 저항 관통.
func get_res_penetration() -> float:
	return maxf(buff_res_penetration, 0.0)

## 버킷 D — 받는 피해 증가(취약).
func get_vulnerability() -> float:
	return buff_vulnerability


# 턴제 튜닝 리소스. 실시간 `get_tuning()`과 이름을 나눠 둔 이유: 두 리소스는 서로 다른
# 스키마이고, 같은 이름으로 오버로드하면 호출부가 어느 쪽을 원했는지 알 수 없다.
static var _fallback_turn_tuning: TurnCombatTuning = null

static func get_tuning_turn() -> TurnCombatTuning:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var cfg := (loop as SceneTree).root.get_node_or_null("TurnCombatConfig")
		if cfg != null and cfg.tuning != null:
			return cfg.tuning

	if _fallback_turn_tuning == null:
		_fallback_turn_tuning = TurnCombatTuning.new()
	return _fallback_turn_tuning


# 턴제 행동값(AV). 소프트캡이 적용된 값이다.
func get_action_value() -> float:
	return get_tuning_turn().action_value_for_speed(float(get_speed()))


# 다음 속도 구간까지 필요한 속도 (설계서 §4.2.3 — UI에 명시해야 하는 값).
func get_speed_to_next_breakpoint(cycles: int = 3) -> int:
	return get_tuning_turn().speed_to_next_breakpoint(float(get_speed()), cycles)


# 턴제 장비 보너스를 갱신한다 (장비 시스템에서 호출).
# 실시간 `set_equipment_bonuses()`와 별도 통로다 — 그 함수의 인자를 늘리면 기존 호출부가 전부 깨진다.
func set_turn_equipment_bonuses(bonuses: Dictionary = {}) -> void:
	equip_speed = int(bonuses.get("speed", 0))
	equip_crit_rate = float(bonuses.get("crit_rate", 0.0))
	equip_crit_damage = float(bonuses.get("crit_damage", 0.0))
	equip_break_effect = float(bonuses.get("break_effect", 0.0))
	equip_effect_hit = float(bonuses.get("effect_hit", 0.0))
	equip_effect_res = float(bonuses.get("effect_res", 0.0))
	equip_energy_recharge = float(bonuses.get("energy_recharge", 0.0))
	equip_heal_boost = float(bonuses.get("heal_boost", 0.0))
	equip_element_damage_bonus = float(bonuses.get("element_damage_bonus", 0.0))


# 턴제 버프/디버프 보너스 전체를 갱신한다 (`TurnStatusSystem`에서 호출).
# 여러 상태 효과가 걸려 있으면 호출자가 합산한 결과를 한 번에 넘긴다.
func set_turn_buff_bonuses(flat: Dictionary = {}, percent: Dictionary = {}) -> void:
	buff_speed = int(flat.get("speed", 0))
	buff_speed_percent = float(percent.get("speed", 0.0))
	buff_crit_rate = float(percent.get("crit_rate", 0.0))
	buff_crit_damage = float(percent.get("crit_damage", 0.0))
	buff_break_effect = float(percent.get("break_effect", 0.0))
	buff_effect_hit = float(percent.get("effect_hit", 0.0))
	buff_effect_res = float(percent.get("effect_res", 0.0))
	buff_energy_recharge = float(percent.get("energy_recharge", 0.0))
	buff_heal_boost = float(percent.get("heal_boost", 0.0))
	buff_element_damage_bonus = float(percent.get("element_damage_bonus", 0.0))
	buff_vulnerability = float(percent.get("vulnerability", 0.0))
	buff_damage_bonus = float(percent.get("damage_bonus", 0.0))
	buff_defense_reduction = float(percent.get("defense_reduction", 0.0))
	buff_res_penetration = float(percent.get("res_penetration", 0.0))


func clear_turn_buff_bonuses() -> void:
	set_turn_buff_bonuses({}, {})


# 턴제 스텟 요약. 스텟 화면과 디버그가 읽는다.
func get_turn_summary() -> Dictionary:
	return {
		"speed": get_speed(),
		"action_value": get_action_value(),
		"speed_to_next_breakpoint": get_speed_to_next_breakpoint(),
		"energy_max": get_energy_max(),
		"crit_rate": get_crit_rate(),
		"crit_damage": get_crit_damage(),
		"break_effect": get_break_effect(),
		"toughness_damage_multiplier": get_toughness_damage_multiplier(),
		"effect_hit": get_effect_hit(),
		"effect_res": get_effect_res(),
		"energy_recharge_multiplier": get_energy_recharge_multiplier(),
		"heal_boost_multiplier": get_heal_boost_multiplier(),
	}

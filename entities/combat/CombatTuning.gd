extends Resource
class_name CombatTuning

# 전투 튜닝 수치의 정의 스키마.
# 실제 값은 data/combat/combat_tuning.tres에 저작하며, 그 파일이 수치의 단일 출처다.
# CombatConfig(autoload)가 이 리소스를 로드해 CombatConfig.tuning.<필드>로 제공한다.
#
# 왜 const가 아니라 Resource인가:
#   밸런싱은 수십 번 반복하는 작업이다. const는 바꿀 때마다 .gd 편집이 필요하지만,
#   .tres는 Godot 에디터 인스펙터에서 숫자만 고치면 되고 코드를 건드리지 않는다.
#
# 값의 성격: 아래 모든 값은 **[임시값]**이다. 플레이 검증 전 임의 시작점이며 밸런싱 대상이다.
#
# 스케일 안전성:
#   가능한 곳은 **비율(percent)**로 정의했다. 기본 스텟이나 피해 공식이 조정되어도
#   비율 값은 다시 만질 필요가 적기 때문이다.
#   (참고: 현재 PlayerStats 기본값으로는 물공 20 vs 물방 25라 피해가 1로 눌린다.
#    기본 스텟/피해 공식 재조정은 별도 과제다.)
#
# 참고: docs/combat-screen-design.md §8.1

# ===== 공통 전투 기본값 (Global) =====
@export_group("공통")
## 평타 기본 쿨다운(초). 원거리 스택 공속이 여기에 곱해진다.
@export var base_attack_cooldown: float = 0.5
## 이동 기본 속도(px/s). 원거리 스택 이속이 여기에 곱해진다.
@export var base_move_speed: float = 200.0

# ===== 탱커 1단계 · 표식 → 기절 =====
@export_group("탱커 1단계 (표식)")
## 표식이 터지는 데 필요한 평타 횟수. 파티 전체의 평타가 카운트된다.
@export var mark_threshold: int = 5
## 평타 1회당 표식 충전량.
@export var mark_gain_per_hit: int = 1
## 표식 폭발 시 기절 지속(초).
@export var mark_stun_duration: float = 2.0
## 표식 폭발 시 추가 피해 = 표식을 부여한 탱커의 물리 공격력 x 이 배수.
## 비율이라 공격력 스케일이 바뀌어도 유지된다.
@export var mark_burst_damage_multiplier: float = 2.0

# ===== 탱커 3단계 · 반사 / 기절 회복 =====
@export_group("탱커 3단계 (반사·회복)")
## 탱커가 피격당했을 때 공격자에게 되돌리는 피해 비율(받은 피해 대비).
@export var reflect_damage_percent: float = 0.3
## 적을 기절시켰을 때 탱커가 회복하는 양(탱커 최대 체력 대비 비율).
@export var stun_heal_percent: float = 0.05

# ===== 원거리딜러 1단계 · 스택 =====
@export_group("원거리 1단계 (스택)")
## 최대 스택 수.
@export var stack_max: int = 10
## 평타 1회당 스택 증가.
@export var stack_gain_per_hit: int = 1
## 스택 1당 공격속도 증가 비율 (0.05 = +5%). 최대 스택에서 +50%.
@export var stack_attack_speed_per_stack: float = 0.05
## 스택 1당 이동속도 증가 비율 (0.02 = +2%). 최대 스택에서 +20%.
@export var stack_move_speed_per_stack: float = 0.02
## 조종 중일 때 초당 스택 감소량. 놓으면 "서서히 감소"가 전투의 리듬(docs §4.1).
@export var stack_decay_per_sec_controlled: float = 1.0
## 미조종(AI) 중일 때 초당 스택 감소량. 조종 중보다 빠르다.
@export var stack_decay_per_sec_uncontrolled: float = 2.5

# ===== 원거리딜러 3단계 · 피흡 / 보호막 =====
@export_group("원거리 3단계 (피흡·보호막)")
## 평타로 준 피해 중 회복되는 비율.
@export var lifesteal_percent: float = 0.15
## 체력이 가득 찬 뒤의 초과 회복분 중 보호막으로 전환되는 비율.
@export var overheal_to_shield_percent: float = 0.5
## 보호막 한도(최대 체력 대비 비율). 이 이상은 쌓이지 않는다.
@export var shield_max_percent: float = 0.3

# ===== 버퍼 1단계 · 처형 =====
@export_group("버퍼 1단계 (처형)")
## 처형 가능한 체력 비율(적 최대 체력 대비). 이 이하일 때 버퍼가 공격하면 처형된다.
@export var execute_hp_percent: float = 0.2

# ===== 버퍼 3단계 · 힐/보호막 비례 추가 피해 =====
@export_group("버퍼 3단계 (추가 피해)")
## 제공한 힐/보호막 양 대비 추가 피해 비율.
@export var heal_to_damage_percent: float = 0.5

# ===== 승리 조건 · 점령 =====
@export_group("점령")
## 거점 존 확보에 필요한 시간(초).
@export var capture_hold_seconds: float = 10.0


# 디버그/검증용: 모든 값을 Dictionary로 반환한다.
func get_summary() -> Dictionary:
	return {
		"base_attack_cooldown": base_attack_cooldown,
		"base_move_speed": base_move_speed,
		"mark_threshold": mark_threshold,
		"mark_gain_per_hit": mark_gain_per_hit,
		"mark_stun_duration": mark_stun_duration,
		"mark_burst_damage_multiplier": mark_burst_damage_multiplier,
		"reflect_damage_percent": reflect_damage_percent,
		"stun_heal_percent": stun_heal_percent,
		"stack_max": stack_max,
		"stack_gain_per_hit": stack_gain_per_hit,
		"stack_attack_speed_per_stack": stack_attack_speed_per_stack,
		"stack_move_speed_per_stack": stack_move_speed_per_stack,
		"stack_decay_per_sec_controlled": stack_decay_per_sec_controlled,
		"stack_decay_per_sec_uncontrolled": stack_decay_per_sec_uncontrolled,
		"lifesteal_percent": lifesteal_percent,
		"overheal_to_shield_percent": overheal_to_shield_percent,
		"shield_max_percent": shield_max_percent,
		"execute_hp_percent": execute_hp_percent,
		"heal_to_damage_percent": heal_to_damage_percent,
		"capture_hold_seconds": capture_hold_seconds,
	}


# 데이터 무결성 점검. 문제 메시지 배열을 반환한다.
# 밸런싱 중 실수로 음수나 0을 넣는 것을 잡는다.
func validate() -> Array[String]:
	var problems: Array[String] = []

	if mark_threshold < 1:
		problems.append("mark_threshold는 1 이상이어야 합니다.")
	if mark_gain_per_hit < 1:
		problems.append("mark_gain_per_hit는 1 이상이어야 합니다.")
	if stack_max < 1:
		problems.append("stack_max는 1 이상이어야 합니다.")
	if base_attack_cooldown <= 0.0:
		problems.append("base_attack_cooldown은 0보다 커야 합니다.")
	if base_move_speed <= 0.0:
		problems.append("base_move_speed는 0보다 커야 합니다.")
	if capture_hold_seconds <= 0.0:
		problems.append("capture_hold_seconds는 0보다 커야 합니다.")

	# 비율 값은 음수를 허용하지 않는다.
	var percents := {
		"reflect_damage_percent": reflect_damage_percent,
		"stun_heal_percent": stun_heal_percent,
		"lifesteal_percent": lifesteal_percent,
		"overheal_to_shield_percent": overheal_to_shield_percent,
		"shield_max_percent": shield_max_percent,
		"execute_hp_percent": execute_hp_percent,
		"heal_to_damage_percent": heal_to_damage_percent,
	}
	for key in percents:
		if float(percents[key]) < 0.0:
			problems.append(key + "는 0 이상이어야 합니다.")

	# 처형 체력선이 1.0(=100%)을 넘으면 항상 처형되어 버린다.
	if execute_hp_percent > 1.0:
		problems.append("execute_hp_percent가 1.0을 넘으면 모든 적이 즉시 처형됩니다.")

	return problems

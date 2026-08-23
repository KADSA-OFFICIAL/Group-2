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

# ===== 대시 (Dash) =====
# 로스터 **전원 공용** 회피 조작이다(#235). 캐릭터별 차등은 두지 않았다.
@export_group("대시")
## 연속으로 쓸 수 있는 대시 횟수. 다 쓰면 dash_cooldown 이 돌고, 끝나면 이 수만큼 **함께** 복구된다.
## (한 발씩 개별 재충전이 아니다 — "두 번 쓰면 쿨타임"이 확정 스펙이다.)
@export var dash_charges: int = 2
## 대시 속도 배수. 실제 속도 = base_move_speed x 이 값.
##
## 이속 배수(PlayerStats.get_move_speed_multiplier)를 **타지 않는다.** 회피 거리는
## 예측 가능해야 하는데, 원거리 스택이 쌓일수록 대시가 멀리 나가면 거리 감각이 매번 달라진다.
@export var dash_speed_multiplier: float = 4.0
## 대시가 지속되는 시간(초). 대시 거리 = base_move_speed x dash_speed_multiplier x 이 값.
@export var dash_duration: float = 0.15
## 충전을 다 쓴 뒤 전부 다시 채워지기까지의 시간(초).
@export var dash_cooldown: float = 2.0

# ===== 동료 AI (Ally AI) =====
# 조종하지 않는 파티원 2명이 스스로 하는 기본 행동의 수치다(#247, docs §4).
# **스킬과 대시는 AI가 쓰지 않는다** — 그것은 사람이 잡아야 하는 행동이다.
@export_group("동료 AI")
## **조종 중인 멤버 기준** 이 거리 안에 적이 있으면 교전한다. 없으면 조종자를 따라온다.
##
## 기준점이 조종자인 이유: AI 자기 위치를 기준으로 하면 자기 옆의 적을 쫓느라
## 조종자에게서 무한히 멀어진다(전환했을 때 남겨진 멤버가 계속 뒤처졌다).
## 조종자 기준이면 파티가 조종자 주위 이 범위 안에 머문다.
##
## 기본값을 적 탐지 범위(EnemyData.detection_range 600, #208)와 같게 두었다.
## 적이 나를 보는 거리와 내가 적에게 붙는 거리가 같으면, 한쪽만 일방적으로
## 끌려가거나 무한 추격이 되는 구간이 생기지 않는다.
@export var ally_ai_engage_range: float = 600.0
## 평타 사거리의 이 비율까지 접근하면 멈춘다.
##
## 1.0 이면 사거리 경계에서 붙었다 떨어지며 떤다. 조금 안쪽에서 멈춰 여유를 둔다.
@export var ally_ai_stop_range_ratio: float = 0.9
## 교전할 적이 없을 때 조종 중인 멤버에게서 이 거리 안이면 멈춘다.
##
## 이 값이 없으면 적이 없을 때 파티가 흩어져, 전환했을 때 그 멤버가 전장 밖에 있다.
@export var ally_ai_follow_distance: float = 80.0

# ===== 피해 공식 (Damage Formula) =====
# 피해 = 공격력² / (공격력 + 방어력)   -- 구현은 PlayerStats.apply_defense()
#
# **조정할 상수가 없다.** 이 공식은 스케일 불변이라, 공격력과 방어력을 함께 k배 하면
# 피해도 정확히 k배가 된다. 그래서 스탯 스케일을 바꿔도 여기서 손볼 것이 없다.
# (이전에는 damage_defense_constant(K)가 방어력의 절대 스케일에 묶여 있어,
#  스탯을 10배 하면 피해가 뭉개져 K를 매번 다시 조정해야 했다. 그래서 제거했다.)
@export_group("피해 공식")
## 최소 피해. 방어력이 아무리 높아도 이 값 아래로는 내려가지 않는다.
@export var damage_min: int = 1

# ===== 스텟 기여 계수 (Stat Contribution) =====
# PlayerStats가 기초 스텟에서 파생 스텟을 계산할 때 쓰는 계수.
# PlayerStats는 이 값을 소유하지 않고 여기서 읽는다(단일 출처).
@export_group("스텟 계수")
## 근력 1 -> 물리 공격력
@export var strength_to_phys_atk: float = 2.0
## 근력 1 -> 물리 방어력
@export var strength_to_phys_def: float = 1.0
## 근력 1 -> 마법 방어력
@export var strength_to_magic_def: float = 0.5
## 방어력 1 -> 물리 방어력
@export var defense_to_phys_def: float = 1.5
## 방어력 1 -> 마법 방어력
@export var defense_to_magic_def: float = 1.5
## 신앙심 1 -> 마법 공격력
@export var faith_to_magic_atk: float = 2.0
## 신앙심 1 -> 여신 스킬 강화 비율. 신앙심 100 기준 최종 배수 1.5.
@export var faith_to_skill_boost: float = 0.005

# ===== 탱커 1단계 · 표식 → 기절 =====
@export_group("탱커 1단계 (표식)")
## 표식이 터지는 데 필요한 평타 횟수. 파티 전체의 평타가 카운트된다.
@export var mark_threshold: int = 5
## 평타 1회당 표식 충전량.
@export var mark_gain_per_hit: int = 1
# [이전됨] 표식 폭발 시 기절 지속시간은 data/status_effects/stun.tres 가 소유한다.
# 효과의 지속시간·차단 대상 같은 "효과 자신의 성질"은 효과 리소스에 두고,
# 여기에는 메커니즘 밸런스 수치(임계치·비율·계수)만 남긴다. 두 곳에 같은 값을 두지 않는다.
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
		"dash_charges": dash_charges,
		"dash_speed_multiplier": dash_speed_multiplier,
		"dash_duration": dash_duration,
		"dash_cooldown": dash_cooldown,
		"ally_ai_engage_range": ally_ai_engage_range,
		"ally_ai_stop_range_ratio": ally_ai_stop_range_ratio,
		"ally_ai_follow_distance": ally_ai_follow_distance,
		"damage_min": damage_min,
		"strength_to_phys_atk": strength_to_phys_atk,
		"strength_to_phys_def": strength_to_phys_def,
		"strength_to_magic_def": strength_to_magic_def,
		"defense_to_phys_def": defense_to_phys_def,
		"defense_to_magic_def": defense_to_magic_def,
		"faith_to_magic_atk": faith_to_magic_atk,
		"faith_to_skill_boost": faith_to_skill_boost,
		"mark_threshold": mark_threshold,
		"mark_gain_per_hit": mark_gain_per_hit,
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
	if dash_charges < 1:
		problems.append("dash_charges는 1 이상이어야 합니다.")
	if dash_speed_multiplier <= 1.0:
		problems.append("dash_speed_multiplier가 1.0 이하면 대시가 평소 이동보다 느립니다.")
	if dash_duration <= 0.0:
		problems.append("dash_duration은 0보다 커야 합니다.")
	if dash_cooldown <= 0.0:
		problems.append("dash_cooldown은 0보다 커야 합니다.")
	if ally_ai_engage_range <= 0.0:
		problems.append("ally_ai_engage_range는 0보다 커야 합니다.")
	if ally_ai_stop_range_ratio <= 0.0 or ally_ai_stop_range_ratio > 1.0:
		problems.append("ally_ai_stop_range_ratio는 0보다 크고 1.0 이하여야 합니다.")
	if ally_ai_follow_distance <= 0.0:
		problems.append("ally_ai_follow_distance는 0보다 커야 합니다.")
	if capture_hold_seconds <= 0.0:
		problems.append("capture_hold_seconds는 0보다 커야 합니다.")

	if damage_min < 0:
		problems.append("damage_min은 0 이상이어야 합니다.")
	# 공격 기여가 0이면 물리 공격력이 장비 보너스에만 의존하게 된다.
	if strength_to_phys_atk <= 0.0:
		problems.append("strength_to_phys_atk는 0보다 커야 합니다.")

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

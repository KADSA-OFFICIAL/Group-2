extends Resource
class_name GoddessSkillData

# 여신의 스킬 정의의 단일 출처 (data definition).
#
# 캐릭터 스킬(SkillData)과 무엇이 다른가:
#   - **파티 공용**이다. 특정 캐릭터가 배우는 것이 아니라 파티가 하나를 들고 나간다.
#   - **스테이지당 1회**다. 쿨타임도 자원 소모도 없다.
#   - 효과가 전투 규칙 자체를 건드린다(시간 정지·부활). 그래서 위력 수치 하나로
#     표현되지 않고 종류마다 다른 파라미터를 쓴다.
#   그래서 SkillData 를 재사용하지 않고 별도 정의를 둔다. 대신 강화 배수는
#   PlayerStats.get_goddess_skill_boost() 를 **그대로 쓴다** — 그 배수의 이름이
#   가리키는 대상이 바로 이 스킬이다.
#
# 참고: autoload/GoddessSkillSystem.gd, entities/player/PlayerStats.gd(강화 배수),
#       entities/equipment/EquipmentData.gd(거울 = 여신 강화 전용 슬롯)

# ===== 종류 (Kind) =====
#
# 효과 구현은 GoddessSkillSystem 이 종류별로 갖는다. 데이터가 코드를 고르는 구조라
# 새 종류를 추가할 때 enum 한 줄 + 구현 한 함수가 늘고, 저작본은 그대로 둔다.
enum Kind {
	TIME_STOP,   # 파티원을 제외한 모든 것의 시간을 멈춘다
	REVIVE,      # 죽은 파티원 한 명을 되살린다
	TIME_HASTE,  # 파티원의 이속·공속을 지속 시간에 걸쳐 점점 올린다 (#366)
}

# ===== 식별 (Identity) =====
@export var skill_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export var kind: Kind = Kind.TIME_STOP

# ===== 파라미터 (Parameters) =====

## TIME_STOP / TIME_HASTE 가 유지되는 시간(초).
@export var duration: float = 0.0

## REVIVE 전용. 되살릴 때 채워 줄 최대 체력 비율(0.5 = 50%).
@export var revive_hp_percent: float = 0.0

# ----- TIME_HASTE 전용 (#366) -----
#
## 지속 시간 끝에 도달하는 공격속도 증가율(0.5 = +50%).
@export var haste_attack_speed_max: float = 0.0

## 지속 시간 끝에 도달하는 이동속도 증가율(0.2 = +20%).
@export var haste_move_speed_max: float = 0.0

## 증가 곡선의 거듭제곱 지수. `증가율 = 최대치 × 진행도 ^ 지수`.
##
## 1.0 이면 선형, 2.0 이면 느리게 시작해 뒤에서 몰아친다(진행 50% 에 최대치의 25%).
## 키우면 더 늦게 터진다. 시작이 정확히 0, 끝이 정확히 최대치라 경계가 깔끔하다.
@export var ramp_exponent: float = 2.0

## 위 수치에 여신 스킬 강화 배수(신앙심 + 거울)를 곱할지.
##
## 켜 두면 파티 편성과 거울 투자가 이 스킬의 값어치를 바꾼다. 끄면 저작값 그대로다.
## 비율(revive_hp_percent)은 곱한 뒤에도 1.0(100%)을 넘기지 않는다 — GoddessSkillSystem 이 자른다.
##
## **종류마다 배수를 타는 수치가 하나씩 정해져 있다**:
##   TIME_STOP   -> duration (정지가 길어진다)
##   REVIVE      -> revive_hp_percent (더 많이 채워 준다)
##   TIME_HASTE  -> 최대 증가율 둘 (더 빨라진다. **duration 은 타지 않는다**)
##
## TIME_HASTE 의 지속이 배수를 타지 않는 이유: 지속과 최대치를 모두 태우면 배수가
## 두 번 곱해진다(1.92 면 19.2초 동안 +96%). 곡선이 끝에서 최대치에 닿는 구조라
## 지속이 늘어나는 것 자체가 이미 총량을 크게 키운다.
@export var scales_with_boost: bool = true


# 강화 배수를 적용한 실제 지속시간.
#
# TIME_HASTE 는 저작값을 그대로 쓴다(위 scales_with_boost 주석의 종류별 규칙).
func get_effective_duration(boost: float) -> float:
	if not scales_with_boost or kind == Kind.TIME_HASTE:
		return duration
	return duration * maxf(boost, 0.0)


# 진행도(0~1)에서의 증가 곡선 값(0~1). duration 이 0 이면 의미가 없어 0 을 반환한다.
func get_ramp_ratio(progress: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	return pow(p, maxf(ramp_exponent, 0.0))


# 진행도에서의 실제 공격속도 증가율(0.5 = +50%).
func get_haste_attack_speed(progress: float, boost: float) -> float:
	return _haste_value(haste_attack_speed_max, progress, boost)


# 진행도에서의 실제 이동속도 증가율.
func get_haste_move_speed(progress: float, boost: float) -> float:
	return _haste_value(haste_move_speed_max, progress, boost)


func _haste_value(max_value: float, progress: float, boost: float) -> float:
	var scaled := max_value
	if scales_with_boost:
		scaled *= maxf(boost, 0.0)
	return scaled * get_ramp_ratio(progress)


# 강화 배수를 적용한 실제 부활 체력 비율(0.0~1.0).
func get_effective_revive_percent(boost: float) -> float:
	var value := revive_hp_percent
	if scales_with_boost:
		value *= maxf(boost, 0.0)
	return clampf(value, 0.0, 1.0)


# ===== 무결성 점검 (Validation) =====
# EnemyData / StageData 와 같은 규약. 문제 메시지 배열을 반환한다.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(skill_id).is_empty():
		problems.append("skill_id가 비어 있습니다.")
	if display_name.is_empty():
		problems.append("display_name이 비어 있습니다.")

	# 종류마다 필요한 파라미터가 다르다. 비어 있으면 발동해도 아무 일이 없다.
	match kind:
		Kind.TIME_STOP:
			if duration <= 0.0:
				problems.append("TIME_STOP은 duration이 0보다 커야 합니다: " + String(skill_id))
		Kind.REVIVE:
			if revive_hp_percent <= 0.0:
				problems.append("REVIVE는 revive_hp_percent가 0보다 커야 합니다: " + String(skill_id))
		Kind.TIME_HASTE:
			if duration <= 0.0:
				problems.append("TIME_HASTE는 duration이 0보다 커야 합니다: " + String(skill_id))
			# 둘 중 하나라도 있으면 효과가 있다. 둘 다 0 이면 발동해도 아무 일이 없다.
			if haste_attack_speed_max <= 0.0 and haste_move_speed_max <= 0.0:
				problems.append("TIME_HASTE는 공속/이속 최대 증가율 중 하나는 0보다 커야 합니다: "
					+ String(skill_id))
			if ramp_exponent <= 0.0:
				problems.append("ramp_exponent는 0보다 커야 합니다: " + String(skill_id))

	return problems

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
}

# ===== 식별 (Identity) =====
@export var skill_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export var kind: Kind = Kind.TIME_STOP

# ===== 파라미터 (Parameters) =====

## TIME_STOP 전용. 정지가 유지되는 시간(초).
@export var duration: float = 0.0

## REVIVE 전용. 되살릴 때 채워 줄 최대 체력 비율(0.5 = 50%).
@export var revive_hp_percent: float = 0.0

## 위 수치에 여신 스킬 강화 배수(신앙심 + 거울)를 곱할지.
##
## 켜 두면 파티 편성과 거울 투자가 이 스킬의 값어치를 바꾼다. 끄면 저작값 그대로다.
## 비율(revive_hp_percent)은 곱한 뒤에도 1.0(100%)을 넘기지 않는다 — GoddessSkillSystem 이 자른다.
@export var scales_with_boost: bool = true


# 강화 배수를 적용한 실제 지속시간.
func get_effective_duration(boost: float) -> float:
	if not scales_with_boost:
		return duration
	return duration * maxf(boost, 0.0)


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

	return problems

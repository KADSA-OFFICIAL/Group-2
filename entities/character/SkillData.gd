extends Resource
class_name SkillData

# 스킬 데이터 정의 (data definition only).
# 실제 발동 로직/이펙트는 이번 범위 밖이며, 후속 이슈에서 이 데이터를 소비한다.

# ===== 식별 (Identity) =====
@export var skill_id: StringName = &""   # 고유 식별자 (예: &"smite")
@export var display_name: String = ""     # 화면 표시 이름
@export_multiline var description: String = ""

# ===== 수치 (Numbers) =====
# 기본 위력(파생 계산 전). 0이면 위력 없음(버프/유틸 스킬 등).
@export var base_power: int = 0

# 신앙심 스케일링: 여신 스킬 강화 배수를 적용할지 여부.
# PlayerStats.get_goddess_skill_boost()를 곱해 최종 위력을 구하도록 한다.
@export var scales_with_faith: bool = true


# 신앙심 강화 배수를 반영한 최종 위력을 계산한다.
# boost는 PlayerStats.get_goddess_skill_boost()(1.0 = 강화 없음)를 넘긴다.
func get_effective_power(faith_boost: float = 1.0) -> int:
	if not scales_with_faith:
		return base_power
	return int(round(base_power * faith_boost))
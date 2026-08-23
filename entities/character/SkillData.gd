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

# ===== 보호막 (Shield) =====
#
# 설계 §3 의 [확정 제약]: 고유 스킬 중 일부는 힐 또는 보호막을 제공해야 한다.
# 버퍼 3단계가 "제공한 힐/보호막 양에 비례한 추가 피해"이고, 문서에 있는 다른 보호막
# 출처(원거리 3단계)는 §8.2 상 버퍼 3단계와 동시에 켜질 수 없기 때문이다.
#
# 왜 절대량이 아니라 비율인가: 대상의 최대 체력이 서로 다르고 성장(PlayerProfile)으로
# 계속 오른다. 비율이면 스케일이 바뀌어도 의미가 유지된다 — CombatTuning 의
# shield_max_percent / stun_heal_percent 와 같은 규약이다.

## 부여하는 보호막량 (대상 최대 체력 대비 비율). 0 이면 보호막을 주지 않는 스킬이다.
@export var shield_percent: float = 0.0

## 보호막 지속시간(초). 0 이면 시간으로는 사라지지 않는다(피해로만 깎인다).
##
## 이 값이 여기 있는 이유: 지속시간은 "보호막 자신의 성질"이다. 상태 효과의 지속시간을
## StatusEffectData 가 갖고 CombatTuning 이 갖지 않는 것과 같은 규약이다.
@export var shield_duration: float = 0.0

# ===== 범위 (Area) =====

## 원형 광역 피해 반경(px). 0 이면 광역이 아니다.
## 근접 공격 사거리(EnemyData.attack_range 기본값 45)와 같은 픽셀 단위다.
@export var aoe_radius: float = 0.0


# ===== 아직 필드가 아닌 것 (Not fields yet) =====
#
# **대상 선정**(누구에게 주는가)과 **발동 조건**(언제 터지는가)은 필드로 두지 않았다.
# 저작된 스킬이 1종뿐이라, 표본 하나로 대상/트리거 프레임워크를 만들면 그 모양이 미나
# 한 명 기준으로 굳는다. 지금은 description 이 그 계약을 들고 있고, 발동을 구현하는
# 이슈에서 6종을 함께 보고 필드로 승격한다.
#
# 예) 미나: "자기 + 가장 체력 낮은 파티원에게 보호막. 보호막이 깨지거나 지속시간이
#     끝나면 그 자리에서 aoe_radius 원형으로 base_power 광역 피해."


# 신앙심 강화 배수를 반영한 최종 위력을 계산한다.
# boost는 PlayerStats.get_goddess_skill_boost()(1.0 = 강화 없음)를 넘긴다.
func get_effective_power(faith_boost: float = 1.0) -> int:
	if not scales_with_faith:
		return base_power
	return int(round(base_power * faith_boost))
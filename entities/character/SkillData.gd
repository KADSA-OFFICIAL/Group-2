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

# ===== 입력 슬롯 (Input slot) =====
#
# 캐릭터마다 키로 쓰는 고유 스킬 슬롯이 **Q · E 두 개**다(#237, docs §4).
#
# 어느 키에 걸리는지는 **스킬 자신이 선언한다.** CharacterData.skills 는 배열이라 순서만
# 있는데, 그 배열에는 키로 쓰지 않는 평타 패시브도 함께 들어 있어 순서로 슬롯을 정할 수 없다.
enum InputSlot {
	NONE,   # 키로 발동하지 않는다 (평타 패시브 등)
	Q,
	E,
}

## 이 스킬이 걸린 키 슬롯. 기본값 NONE 이라 기존 .tres 는 키에 걸리지 않는다.
@export var input_slot: InputSlot = InputSlot.NONE

# ===== 평타 트리거 (Basic-attack trigger) =====

## 평타 N회마다 발동한다. 0 이면 평타로 발동하지 않는다(플레이어가 직접 쓰는 발동형 스킬).
##
## **"발생" 기준이고 적중이 아니다.** Player.try_attack() 이 쿨다운을 소비한 직후,
## 피해·처형 판정 **전에** 센다. 그래서 처형으로 끝난 평타와 적을 죽인 평타도 세어진다.
## (지금은 사거리 안에 적이 없으면 평타 자체가 나가지 않으므로 발생 = 적중이지만,
##  헛스윙이 생기더라도 이 위치에서 세면 스펙이 그대로 유지된다.)
@export var every_n_attacks: int = 0

# ===== 회복 (Heal) =====

## 시전자가 **잃은 체력** 대비 회복 비율. 0 이면 회복하지 않는다.
##
## 최대 체력이 아니라 잃은 체력이 기준이다 — 체력이 가득 차 있으면 0이 되므로
## 몰릴수록 세지는 역전 장치가 된다. 이 성질이 의도다.
@export var heal_missing_hp_percent: float = 0.0

## **실제로 회복한 양** 대비 광역 피해 비율. aoe_radius 안의 적 전체에 들어간다.
##
## 버퍼 3단계(CombatTuning.heal_to_damage_percent)와 같은 발상이지만 **별개 채널**이다.
## 그쪽은 시너지라 파티 구성에 따라 켜지고 꺼지지만, 이쪽은 캐릭터 개성이라 항상 작동한다.
## 회복량이 0이면 이 피해도 0이다.
@export var heal_to_aoe_damage_percent: float = 0.0


# ===== 아직 필드가 아닌 것 (Not fields yet) =====
#
# **대상 선정**(누구에게 주는가)은 필드로 두지 않았다. 저작된 스킬이 적어 표본 하나로
# 대상 프레임워크를 만들면 그 모양이 한 캐릭터 기준으로 굳는다. 지금은 description 이
# 그 계약을 들고 있고, 발동을 구현하는 이슈에서 6종을 함께 보고 필드로 승격한다.
#
# 트리거는 **스펙이 요구할 때만** 필드가 된다. every_n_attacks 는 "평타 3번마다"라는
# 확정된 스펙이 있어서 필드로 만들었다. 반면 보호막 폭발의 "보호막이 깨지거나 지속시간이
# 끝나면"은 아직 description 에 있다 — 발동 로직이 없어 필드로 만들 근거가 없다.
#
# 예) 미나 보호막 폭발: "자기 + 가장 체력 낮은 파티원에게 보호막. 보호막이 깨지거나
#     지속시간이 끝나면 그 자리에서 aoe_radius 원형으로 base_power 광역 피해."

# 신앙심 강화 배수를 반영한 최종 위력을 계산한다.
# boost는 PlayerStats.get_goddess_skill_boost()(1.0 = 강화 없음)를 넘긴다.
func get_effective_power(faith_boost: float = 1.0) -> int:
	if not scales_with_faith:
		return base_power
	return int(round(base_power * faith_boost))
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
# **대상의 최대 체력에 비례하지 않는다**(#259). 보호막 양 = shield_base + 게이지비율 x shield_gauge_bonus.
#
# 왜 절대량인가: 이 보호막은 **시전자의 자원(게이지)에서 나오는 것**이지 받는 사람의 그릇에서
# 나오는 것이 아니다. 비율로 두면 같은 게이지를 써도 체력 큰 대상에게 걸릴 때만 두꺼워져,
# "얼마나 모아서 쓸까"라는 판단과 실제 보호막 양이 어긋난다.
# 대가: 절대량이라 스텟 스케일이 바뀌면 같이 조정해야 한다(비율 값과 달리 자동으로 따라오지 않는다).
#
# 받는 쪽 총량 한도는 없다(#261 에서 제거). 여기 적힌 값이 그대로 들어간다.

## 게이지가 0 일 때 주는 보호막(절대값). 이 스킬의 **최소 보장치**다.
## 0 이면서 shield_gauge_bonus 도 0 이면 보호막을 주지 않는 스킬이다.
@export var shield_base: int = 0

## 게이지가 가득일 때 shield_base 에 **더해지는** 보호막(절대값).
## 게이지 절반이면 이 값의 절반이 더해진다.
@export var shield_gauge_bonus: int = 0

## 보호막 지속시간(초). 0 이면 시간으로는 사라지지 않는다(피해로만 깎인다).
##
## 이 값이 여기 있는 이유: 지속시간은 "보호막 자신의 성질"이다. 상태 효과의 지속시간을
## StatusEffectData 가 갖고 CombatTuning 이 갖지 않는 것과 같은 규약이다.
@export var shield_duration: float = 0.0

## 쿨타임(초). 0 이면 제한이 없다.
##
## **시전 시점부터** 돈다 — 즉시 폭발로 일찍 끝내도 남은 시간은 기다려야 한다.
## 쿨타임이 막는 것은 "보호막 생성"이고, 이미 두른 보호막을 터뜨리는 것은 막지 않는다.
##
## 왜 CombatTuning 이 아니라 여기인가: 대시 쿨타임(#235)은 **전원 공용 메커니즘**이라
## CombatTuning 이 갖지만, 스킬 쿨타임은 스킬마다 다른 **그 스킬 자신의 성질**이다
## (상태 효과의 지속시간을 StatusEffectData 가 갖는 것과 같은 규약).
@export var cooldown: float = 0.0

# ===== 범위 (Area) =====

## 원형 광역 피해 반경(px). 0 이면 광역이 아니다.
## 근접 공격 사거리(EnemyData.attack_range 기본값 45)와 같은 픽셀 단위다.
@export var aoe_radius: float = 0.0


# ===== 투사체 (Projectile) =====
#
# 0 이면 투사체가 아니다 — 그 자리에서 즉시 발동하는 스킬이다.
# 투사체 스킬은 **적에 닿으면 그 자리에서**, 아무것도 맞히지 못하면 **최대 사거리에서** 터진다.
# 빗나가도 아무 일이 없으면 조준을 요구하는 대가만 있고 보상이 없기 때문이다.
#
# 실제 비행·명중 판정은 Projectile 이 한다. 여기 있는 것은 그 값의 출처다.

## 투사체 속도(px/s). 0 이면 투사체 스킬이 아니다.
@export var projectile_speed: float = 0.0

## 최대 비행 거리(px). 이만큼 날아가면 그 자리에서 터진다.
@export var projectile_range: float = 0.0

# ===== 부여 효과 (Applied effect) =====

## 맞은 대상에게 걸 상태 효과 id. 비어 있으면 피해만 준다.
## 효과의 정의(지속시간·봉인 범위 등)는 StatusEffectData 가 소유한다 — 여기서 다시 적지 않는다.
@export var apply_effect_id: StringName = &""

# ===== 게이지 연동 (Skill gauge) =====
#
# 게이지를 가진 캐릭터(CharacterData.skill_gauge_max > 0)의 스킬은 게이지에 비례해 세진다.
# **무엇이 세지는가는 스킬마다 다르다.** 그래서 하나의 "게이지 보너스" 필드로 뭉치지 않고
# 대상 수치별로 나눠 두었다 — 어느 값이 커지는지가 데이터에서 바로 보여야 한다.
#
# 계산 규약: 최종값 = 기본값 x (1 + 게이지비율 x 보너스비율). 게이지가 0 이면 기본값 그대로다.

## 게이지가 가득일 때 aoe_radius 가 늘어나는 비율. 1.0 이면 반경 2배.
@export var gauge_radius_bonus_percent: float = 0.0

## 시전하면 게이지를 **전량** 소모하는가.
##
## 전량인 이유: 스킬 세기가 게이지에 비례하므로, 남겨 두는 선택지를 주면 "언제 터뜨릴까"라는
## 판단 하나가 "얼마나 남길까"까지 갈라져 리듬이 흐려진다. 게이지 0 에서도 최소 성능으로 나간다.
@export var consumes_gauge: bool = false
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

# 이 스킬이 날아가는 투사체인가.
func is_projectile() -> bool:
	return projectile_speed > 0.0


# 게이지 비율(0.0~1.0)을 반영한 최종 광역 반경.
# 게이지가 없는 캐릭터는 0.0 이 들어와 기본 반경 그대로다.
func get_effective_radius(gauge_ratio: float = 0.0) -> float:
	return aoe_radius * (1.0 + clampf(gauge_ratio, 0.0, 1.0) * gauge_radius_bonus_percent)


# 이 스킬이 보호막을 주는가.
func grants_shield() -> bool:
	return shield_base > 0 or shield_gauge_bonus > 0


# 게이지 비율(0.0~1.0)을 반영한 최종 보호막량(절대값).
# 받는 쪽의 최대 체력과도, 총량 한도와도 무관하다(#261). 이 값이 그대로 들어간다.
func get_effective_shield(gauge_ratio: float = 0.0) -> int:
	return shield_base + int(round(clampf(gauge_ratio, 0.0, 1.0) * float(shield_gauge_bonus)))

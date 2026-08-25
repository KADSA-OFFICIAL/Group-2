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


# ===== 평타 광역 (Basic-attack AoE) =====

## 평타 패시브가 내는 광역 피해 = **시전자 물리 공격력 x 이 비율**. 0 이면 이 채널을 쓰지 않는다.
##
## 왜 heal_to_aoe_damage_percent 와 따로인가: 그쪽은 **회복량**에서 피해가 나오므로
## 체력이 가득 차 있으면 0 이 되는 역전 장치다(미나). 이쪽은 회복과 무관하게 항상 같은
## 비율로 나가는 딜링 채널이다. 한 필드로 뭉치면 "무엇에 비례하는가"가 데이터에서 사라진다.
##
## 비율이라 공격력 스케일이 바뀌어도 유지된다(mark_burst_damage_multiplier 와 같은 규약).
## aoe_radius 와 함께 쓴다 — 반경이 0 이면 때릴 범위가 없어 아무 일도 하지 않는다.
@export var attack_aoe_power_percent: float = 0.0

## 이 평타 패시브가 터지는 광역을 **평타 투사체의 착탄 지점**에서 낼 것인가.
##
## false 면 시전자 발밑에서 터진다(미나의 3타 회복 폭발). true 면 날아간 탄이 멈춘 자리에서
## 터진다(태희의 4타 광역) — 원거리 캐릭터의 광역이 자기 발밑에서 나면 사거리의 의미가 없다.
##
## 시전자가 투사체 평타를 쓰지 않으면(CharacterData.basic_attack_projectile_speed == 0)
## 이 값이 true 여도 발밑에서 난다. 날아갈 탄이 없기 때문이다.
@export var aoe_at_projectile_impact: bool = false

# ===== 평타 체인 (Basic-attack chain) =====
#
# 시전하면 **일정 시간 동안** 시전자의 평타 투사체가 맞은 뒤 다음 적에게 튕긴다.
# 즉발 피해가 아니라 **평타를 강화하는 창(window)** 이라, 이 스킬의 값어치는 그 창 안에
# 평타를 몇 번 넣느냐로 정해진다 — 공속(원거리 스택)이 그대로 이 스킬의 세기가 된다.

## 체인이 유지되는 시간(초). 0 이면 체인 스킬이 아니다.
@export var chain_duration: float = 0.0

## 첫 명중 뒤 **추가로** 튕겨 맞히는 적 수. 3 이면 최대 4체(첫 대상 + 3)를 때린다.
##
## "추가"인 이유: 첫 명중은 체인이 없어도 일어난다. 이 값이 세는 것은 스킬이 만들어 낸 몫이다.
@export var chain_bounces: int = 0

## 튕길 다음 적을 찾는 반경(px). 이 안에 **아직 맞지 않은** 적이 없으면 거기서 끝난다.
@export var chain_range: float = 0.0

## 튕긴 타격의 피해 비율. 0.6 이면 튕길 때마다 직전 타격의 60%.
##
## **누적**이다(0.6 -> 0.36 -> 0.216). 감쇠가 없으면 창 안의 화력이 그대로 몇 배가 된다.
@export var chain_damage_percent: float = 1.0

# ===== 시전 시간 (Cast time) =====

## 누른 뒤 실제로 나가기까지 걸리는 시간(초). 0 이면 즉발이다.
##
## **공격속도 배수로 나뉜다** — 실제 시전 시간 = cast_time / 공속 배수.
## 원거리 1단계 스택이 공속을 올리면 캐스트도 함께 짧아진다. 캐스트 중은 무방비이므로
## 이 연동이 "평타를 쳐서 쌓은 것이 곧 안전"이 되게 하는 장치다.
##
## 캐스트 중에는 평타가 나가지 않는다. 이동은 막지 않는다 — 이 프로젝트에는 이동 봉인을
## 스킬이 자기 자신에게 거는 통로가 없고, 있는 것처럼 흉내 내면 상태 효과와 출처가 갈린다.
@export var cast_time: float = 0.0

# ===== 직선 범위 (Beam) =====
#
# 원형(aoe_radius)이 아니라 **조준 방향으로 뻗는 직사각형**으로 때린다.
# 방향의 출처는 Player.get_aim_direction() 이다 — 조종 중이면 커서, 아니면 진행 방향(#264).
# 관통이다 — 앞의 적이 막아 주지 않는다.

## 빔이 뻗는 길이(px). 0 이면 빔이 아니다.
@export var beam_length: float = 0.0

## 빔의 폭(px). 진행축에서 좌우로 이 값의 **절반**씩 벌어진 띠 안이 판정 범위다.
@export var beam_width: float = 0.0

# ===== 현재 체력 비례 피해 (Current-HP damage) =====

## 맞은 적의 **현재 체력 x 이 비율**을 base_power 에 더해 때린다. 0 이면 쓰지 않는다.
##
## 대상마다 피해가 다르다 — 체력이 많이 남은 적일수록 많이 아프다. 뒤집으면 깎일수록
## 덜 아프므로 **마무리는 못 한다**. 그래서 base_power 를 최소 보장치로 함께 둔다.
##
## 방어력은 기존 규약대로 대상의 take_damage() -> PlayerStats.apply_defense() 가 적용한다.
## 여기서 방어를 무시하지 않는다 — 피해 공식의 단일 출처를 우회하지 않기 위해서다.
@export var current_hp_damage_percent: float = 0.0

# ===== 평타 쿨감 (Cooldown reduction on attack) =====

## 시전자가 평타를 **1회** 낼 때마다 이 스킬의 남은 쿨타임에서 빼는 시간(초).
## 0 이면 시간으로만 줄어든다(기본).
##
## 평타 **발생** 기준이다(every_n_attacks 와 같은 규약). 빗나간 탄도 쿨감을 준다 —
## 명중 기준이면 탄이 날아가는 동안 쿨타임이 멈춘 것처럼 보여 인과가 흐려진다.
@export var cooldown_reduction_per_attack: float = 0.0

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


# 이 스킬이 평타에 체인을 거는가.
func chains_basic_attacks() -> bool:
	return chain_duration > 0.0 and chain_bounces > 0


# 이 스킬이 직선 범위(빔)로 때리는가.
func is_beam() -> bool:
	return beam_length > 0.0 and beam_width > 0.0


# 공속 배수를 반영한 실제 시전 시간(초). 0 이면 즉발이다.
#
# 배수가 0 이하로 들어오면(버그성 입력) 나누지 않고 기본값을 돌려준다 —
# Player.get_attack_cooldown() 이 같은 상황을 처리하는 방식과 같은 규약이다.
func get_cast_time(attack_speed_multiplier: float = 1.0) -> float:
	if cast_time <= 0.0:
		return 0.0
	if attack_speed_multiplier <= 0.0:
		return cast_time
	return cast_time / attack_speed_multiplier


# 대상 하나에게 넣을 피해. 최소 보장치(base_power, 신앙심 강화 적용) + 현재 체력 비례분.
#
# 방어력은 여기서 적용하지 않는다. 대상의 take_damage() 가 한다(피해 공식 단일 출처).
func get_damage_against(target_current_hp: int, faith_boost: float = 1.0) -> int:
	var total := float(get_effective_power(faith_boost))
	if current_hp_damage_percent > 0.0:
		total += maxf(float(target_current_hp), 0.0) * current_hp_damage_percent
	return int(round(total))

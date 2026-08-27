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

# ===== 즉발 광역 (Instant AoE) =====
#
# 시전한 **그 순간 시전자 자리에서** 원형으로 때리는 채널(#328).
#
# 왜 aoe_radius 를 쓰지 않는가: 그 필드는 이미 **다른 것에 붙어 있는 반경**이다 —
# 투사체가 터질 반경(미나 Q)이거나 평타 패시브가 낼 반경(태희 4타)이다. 같은 필드로
# "그냥 지금 여기서 터진다"까지 겸하게 하면, 반경이 0 이 아닌 스킬이 무엇을 하는지
# 다른 필드를 다 봐야 알게 된다. 빔(beam_*)과 파동(wave_*)이 각자 반경을 가진 것과 같은 규약이다.
#
# 파동(wave_*)과 다른 점: 파동은 판정이 시간에 따라 퍼져서 **달려서 피할 수 있다.**
# 이쪽은 누른 순간 반경 안이 전부 맞는다. 도발처럼 "지금 당장 끌어와야" 값어치가 있는
# 스킬은 피할 수 있으면 안 된다.
#
# 적에게 들어가는 것: base_power 피해(0 이면 피해 없음)와 apply_effect_id 상태 효과.
# 피해가 0 이고 효과만 있는 스킬도 정상이다 — 하랑 Q 가 그렇다.

## 즉발 광역 반경(px). 0 이면 이 채널을 쓰지 않는다.
@export var instant_aoe_radius: float = 0.0

# ===== 지대 (Aura zone) =====
#
# 시전 자리에 **일정 시간 남아 있는 원형 지대**를 놓는다(#334).
#
# 앞의 세 범위 채널과 무엇이 다른가:
#   즉발 광역(instant_aoe_radius) — 누른 순간 한 번. 판정이 그때 끝난다.
#   파동(wave_*)              — 판정이 퍼져 나간다. 지나가면 끝난다.
#   지대(aura_*)              — **그 자리에 머문다.** 안에 있는 동안만 효과가 걸린다.
#
# 그래서 이 채널의 값어치는 "맞혔는가"가 아니라 **"아군이 거기 서 있는가"** 다.
# 들어오면 걸리고 나가면 그 즉시 풀린다 — 머문 시간이 곧 이득이다.
#
# 지대는 시전 **자리에 고정**된다(시전자를 따라다니지 않는다). 따라다니면 시전자는 항상
# 안에 있어서 "안에 있는가"라는 판단이 시전자에게만 사라지고, 지대를 깔 위치를 고르는
# 조작도 없어진다. 서 있을 곳을 고르는 것이 이 스킬이다.
#
# 적에게는 아무 일도 하지 않는다. 피해를 주는 지대가 필요해지면 그때 채널을 더한다 —
# 지금 스펙에 없는 것을 미리 만들면 쓰이지 않는 분기가 남는다.

## 지대가 남아 있는 시간(초). 0 이면 지대 스킬이 아니다.
@export var aura_duration: float = 0.0

## 지대의 반경(px). 0 이면 지대 스킬이 아니다.
@export var aura_radius: float = 0.0

## 지대 안 아군에게 걸 상태 효과 id. 비어 있으면 지대가 아무 일도 하지 않는다.
##
## 효과의 내용(공속·받는 피해 감소 등)과 지속시간은 **효과 리소스가 소유한다.**
## 다만 지대가 나갈 때 직접 풀어 주므로, 이 효과의 duration 은 지대 수명의 보험이다.
@export var aura_effect_id: StringName = &""


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

## 평타로 **실제로 들어간 피해** 대비 아군 회복 비율. 0 이면 이 채널을 쓰지 않는다(#334).
##
## 대상은 **체력 비율이 가장 낮은 아군**이다(시전자 자신도 후보다) — ally_heal 과 같은 선정 규칙이다.
##
## **`every_n_attacks` 주기가 아니라 평타 1회마다** 나간다. 그래서 발동 지점이
## `_apply_attack_passives()`(주기 패시브)가 아니라 `_resolve_attack_hit()`(평타가 닿은 자리)다.
## 기준이 "발생"이 아니라 **"실제로 들어간 피해"** 이므로 닿아야만 나간다 — 빗나간 탄은
## 회복시키지 않는다. 원거리 3단계 피흡이 같은 자리에서 같은 기준을 쓴다.
##
## ally_heal(절대값)과 왜 다른가: 그쪽은 스킬이 주는 고정량이라 시전자의 화력과 무관하다.
## 이쪽은 **때린 만큼 살린다** — 강지가 딜을 넣지 않으면 파티가 회복되지 않는다는 것이 의도다.
## 그래서 비율이고, 신앙심 강화(scales_with_faith)를 타지 않는다. 피해가 이미 스텟을 거쳐 나온 값이다.
@export var attack_damage_to_ally_heal_percent: float = 0.0

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

# ===== 평타 변형 창 (Basic-attack override window) =====
#
# 시전하면 **일정 시간 동안 평타 자체가 다른 평타로 바뀐다**(#328).
#
# 체인 창(chain_*)과 나눠 둔 이유: 체인은 평타에 **얹는다** — 대상도, 피해 공식도,
# 단일 대상이라는 성질도 그대로이고 맞은 뒤 튕김이 추가될 뿐이다. 이쪽은 평타를
# **갈아치운다** — 단일 대상이 광역이 되고, 피해 공식이 공격력에서 대상 최대 체력으로 바뀐다.
# 한 창으로 뭉치면 "평타가 지금 무엇인가"를 창 종류가 아니라 필드 조합으로 추측하게 된다.
#
# 창이 열려 있는 동안에도 평타의 나머지 규칙(처형 -> 피해 -> 피흡 -> 표식)은 그대로다.
# 반경 안 적 **하나하나가** 평타를 한 번 맞은 것으로 처리된다 — 그래서 표식도 전원에게 붙는다.
#
# 겹쳐 쓰면 남은 시간이 **갱신**된다(체인 창과 같은 규약).

## 평타가 바뀌어 있는 시간(초). 0 이면 이 채널을 쓰지 않는다.
@export var attack_override_duration: float = 0.0

## 바뀐 평타가 때리는 반경(px). 0 이면 창이 열려도 광역이 되지 않는다.
##
## instant_aoe_radius 와 따로인 이유: 그쪽은 **스킬을 누른 순간 한 번** 터지는 범위이고,
## 이쪽은 창이 열린 동안 **평타마다** 나가는 범위다. 근접 평타의 사거리를 넓히는 값이라
## 즉발 광역보다 작게 잡는 것이 보통이다.
@export var attack_override_aoe_radius: float = 0.0

## 바뀐 평타의 피해 = **맞은 적의 최대 체력 x 이 비율**. 0 이면 공격력 그대로다.
##
## current_hp_damage_percent(태희 E)와 다른 축이다. 그쪽은 **현재** 체력 비례라 깎일수록
## 약해지고 마무리를 못 한다. 이쪽은 **최대** 체력 비례라 체력이 얼마 남았든 같은 값이 들어간다
## — 큰 적에게 강하고, 마무리도 할 수 있다.
##
## 방어력은 그대로 받는다(대상의 take_damage -> apply_defense). 여기서 우회하지 않는 것은
## current_hp_damage_percent 와 같은 규약이다 — 피해 공식의 단일 출처를 지킨다.
## 그래서 이 비율은 **방어 적용 전** 값이라는 것을 염두에 두고 저작한다.
@export var attack_override_max_hp_percent: float = 0.0

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

# ===== 부채꼴 (Cone) =====
#
# 조준 방향으로 **퍼지는 부채꼴**로 때린다(#336). 방향의 출처는 빔과 같은
# `Player.get_aim_direction()` 이다 — 조종 중이면 커서, 아니면 진행 방향.
#
# 빔(직사각형)과 무엇이 다른가: 빔은 **멀어져도 폭이 같다.** 부채꼴은 멀수록 넓어지고
# 가까울수록 좁다. 그래서 빔은 "줄을 맞춘 적"에게 강하고, 부채꼴은 **붙어 있는 적 무리**에게 강하다.
# 밀어내기처럼 "내 앞을 치우는" 스킬은 바로 앞이 넓어야 하는데, 그것은 폭이 아니라 각도로 표현된다.
#
# 원형(instant_aoe_radius)과도 다르다: 원은 등 뒤까지 때리므로 어디를 보고 있는지가 값어치에
# 들어가지 않는다. 부채꼴은 조준이 곧 판단이다.
#
# 관통이다 — 앞의 적이 뒤의 적을 막아 주지 않는다(빔과 같은 규약).

## 부채꼴이 뻗는 거리(px). 0 이면 부채꼴 스킬이 아니다.
@export var cone_length: float = 0.0

## 부채꼴의 **전체** 각도(도). 90 이면 조준 방향 기준 좌우 45도씩이다.
## 0 이면 부채꼴 스킬이 아니다. 360 이상이면 사실상 원이 되므로 저작하지 않는다.
@export var cone_angle_degrees: float = 0.0

# ===== 넉백 (Knockback) =====

## 맞은 적을 **시전자 반대 방향으로** 밀어내는 거리(px). 0 이면 밀어내지 않는다(#336).
##
## 방향은 시전자에서 대상으로 향하는 벡터다 — 조준 방향이 아니다. 부채꼴 가장자리에 있던 적은
## 비스듬히 밀려나고, 정면에 있던 적은 곧게 밀려난다. 조준 방향으로 일괄해서 밀면 옆에 있던 적이
## 옆으로 끌려가 "내 앞을 치웠다"는 감각이 어긋난다.
##
## **순간이동이 아니다.** 대상이 짧은 시간에 걸쳐 미끄러지며, 이동은 `move_and_slide` 를 거치므로
## 벽을 통과하지 않는다(EnemyBase.apply_knockback). 밀리는 동안 대상의 추격 이동은 멈춘다.
##
## 지금은 적에게만 걸린다 — 아군을 밀어내는 스킬은 스펙에 없다.
@export var knockback_distance: float = 0.0

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

# ===== 아군 회복 (Ally heal) =====

## 이 스킬이 **아군 한 명에게** 주는 회복량(절대값). 0 이면 아군을 회복시키지 않는다.
##
## scales_with_faith 가 켜져 있으면 여신 스킬 강화 배수를 탄다(base_power 와 같은 규약).
##
## 왜 절대값인가: 미나 보호막(#259, #261)과 같은 이유다. 이 회복은 **시전자가 주는 것**이지
## 받는 사람의 그릇에서 나오는 것이 아니다. 최대 체력 비례로 두면 같은 스킬이 체력 큰 대상에게
## 걸릴 때만 두꺼워져, "누구를 살릴까"라는 판단과 실제 회복량이 어긋난다.
## 대가: 절대량이라 스텟 스케일이 바뀌면 같이 조정해야 한다.
##
## heal_missing_hp_percent 와 다른 채널이다. 그쪽은 **시전자 자신**의 잃은 체력 비례이고,
## 이쪽은 **아군에게** 주는 고정량이다.
@export var ally_heal: int = 0

# ===== 파동 (Shockwave) =====
#
# 고정 반경 원(aoe_radius)과 달리 **시간에 따라 퍼지는** 판정이다(#276).
# 파동이 닿는 그 순간 적중하므로 달려서 피할 수 있고, 먼 대상일수록 늦게 맞는다.
# 한 대상은 한 번만 맞는다 — 되돌아오지 않는다.
#
# 적에게는 base_power 피해가, 아군에게는 ally_heal 회복이 들어간다.

## 파동이 퍼지는 최대 반경(px). 0 이면 파동 스킬이 아니다.
@export var wave_radius: float = 0.0

## 파동이 퍼지는 속도(px/s). 0 이면 파동 스킬이 아니다.
##
## 이 값이 곧 "피할 수 있는가"를 정한다. 너무 빠르면 즉발과 구분되지 않고,
## 너무 느리면 아군 회복이 늦어 죽은 뒤에 닿는다.
@export var wave_speed: float = 0.0

# ===== 파티 전체 효과 부여 (Party-wide effect) =====

## 시전하면 **파티 전원**(시전자 포함, 아군 AI 포함)에게 걸 상태 효과 id. 비어 있으면 걸지 않는다.
##
## apply_effect_id 와 나눠 둔 이유: 그쪽은 **맞은 대상**(적)에게 거는 것이고, 이쪽은 조준·명중과
## 무관하게 **아군 전원**에게 간다. 한 필드로 뭉치면 "누구에게 걸리는가"가 데이터에서 사라진다.
##
## 효과의 정의(지속시간·부여하는 행동)는 StatusEffectData 가 소유한다 — 여기서 다시 적지 않는다.
@export var party_effect_id: StringName = &""

# ===== 자기 효과 부여 (Self effect) =====

## 시전하면 **시전자 자신에게만** 걸 상태 효과 id. 비어 있으면 걸지 않는다(#328).
##
## party_effect_id 와 나눠 둔 이유: 그쪽은 파티 전원에게 가는 **파티 버프**다(설아 E).
## 이쪽은 자기만 강해지고 자기만 대가를 치르는 **자기 강화**다(하랑 E — 공속과 흡혈을 얻고
## 그 대가로 자기 체력이 탄다). 한 필드로 뭉치면 "누가 이득을 보고 누가 대가를 치르는가"가
## 데이터에서 사라진다. 실제로 하랑 E 를 파티 전원에게 걸면 파티가 전멸한다.
##
## 종류가 섞인 상태(공속 + 흡혈 + 지속 피해)는 효과 하나로 담지 않는다 —
## StatusEffectData.also_apply_effect_id 로 이어 붙인 첫 효과 id 만 여기 적는다.
@export var self_effect_id: StringName = &""

# ===== 아군 1명 효과 부여 (Single-ally effect) =====

## 시전하면 **아군 한 명**에게 걸 상태 효과 id. 비어 있으면 걸지 않는다(#334).
##
## 대상은 **체력 비율이 가장 낮은 아군**이다(시전자 자신도 후보다).
## ally_heal(설아 3타 회복)이 쓰는 것과 같은 선정 규칙이라 여기서 다시 만들지 않는다.
##
## party_effect_id·self_effect_id 와 나눠 둔 이유는 그 둘이 서로 나뉜 이유와 같다 —
## **누구에게 걸리는가**가 데이터에서 보여야 한다. 셋의 대상은 각각 파티 전원 / 자기 / 아군 하나다.
## 강지 E 의 무적을 파티 전원에게 걸면 그것은 다른 스킬이 된다.
##
## 조준을 요구하지 않는다: 이 프로젝트에는 아직 대상 선정 프레임워크가 없고(이 파일 맨 아래
## "아직 필드가 아닌 것" 참고), 표본이 적은 상태에서 만들면 한 캐릭터 기준으로 굳는다.
@export var ally_effect_id: StringName = &""

# ===== 시전 조건 (Cast condition) =====

## 시전자의 체력 비율이 **이 값 미만일 때만** 시전할 수 있다. 0 이면 조건이 없다(#328).
##
## 0.3 이면 체력 30% 미만에서만 나간다. 조건에 걸리면 **쿨타임도 게이지도 소모하지 않는다**
## — 아무 일도 일어나지 않았기 때문이다(쿨타임 중 시전과 같은 처리다).
##
## 왜 쿨타임과 따로인가: 쿨타임은 "얼마나 자주"이고 이것은 "언제"다. 몰린 순간에만 쓸 수 있는
## 역전기는 쿨타임을 아무리 길게 잡아도 표현되지 않는다.
##
## 조건을 **비율**로 두는 이유: 절대 체력으로 두면 성장·장비로 최대 체력이 오를 때마다
## 조건이 사실상 느슨해진다(SkillData.heal_missing_hp_percent 와 같은 규약).
@export var require_hp_below_percent: float = 0.0

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


# 이 스킬이 부채꼴로 때리는가(#336).
func is_cone() -> bool:
	return cone_length > 0.0 and cone_angle_degrees > 0.0


# 부채꼴 판정에 쓸 **반각**(라디안). 조준축에서 좌우로 이만큼씩 벌어진 안이 범위다.
#
# 180도(반각 90도)를 넘지 않게 자른다. 그 이상은 등 뒤까지 때리는 것이라 부채꼴이 아니라
# 원이고, 원이 필요하면 instant_aoe_radius 를 쓴다.
func get_cone_half_angle() -> float:
	return deg_to_rad(clampf(cone_angle_degrees, 0.0, 180.0) * 0.5)


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


# 이 스킬이 퍼지는 파동인가.
func is_wave() -> bool:
	return wave_radius > 0.0 and wave_speed > 0.0


# 이 스킬이 지대를 놓는가(#334).
#
# 셋이 모두 있어야 한다: 시간, 반경, 걸 효과. 하나라도 없으면 놓을 이유가 없다 —
# 효과가 없는 지대는 그림이고, 시간이나 반경이 0 이면 아무도 그 안에 있을 수 없다.
func creates_aura() -> bool:
	return aura_duration > 0.0 and aura_radius > 0.0 and aura_effect_id != &""


# 이 스킬이 평타로 아군을 회복시키는가(#334).
func heals_ally_on_attack() -> bool:
	return attack_damage_to_ally_heal_percent > 0.0


# 평타로 들어간 피해에 대해 아군에게 줄 회복량(#334).
#
# 신앙심 강화를 타지 않는다 — 피해가 이미 시전자 스텟을 거쳐 나온 값이라
# 여기서 다시 곱하면 같은 스텟이 두 번 실린다.
func get_ally_heal_from_damage(damage_dealt: int) -> int:
	if attack_damage_to_ally_heal_percent <= 0.0 or damage_dealt <= 0:
		return 0
	return int(round(float(damage_dealt) * attack_damage_to_ally_heal_percent))


# 이 스킬이 시전 자리에서 즉발 광역으로 때리는가(#328).
#
# 반경만 본다. 피해가 0 이고 상태 효과만 거는 스킬도 이 채널을 쓴다(하랑 Q).
func is_instant_aoe() -> bool:
	return instant_aoe_radius > 0.0


# 이 스킬이 평타를 일정 시간 다른 평타로 바꾸는가(#328).
#
# 지속시간만으로는 부족하다 — 바꿔 놓고 아무것도 달라지지 않으면 창을 열 이유가 없다.
# 그래서 "무엇으로 바뀌는가"(광역 반경 또는 최대체력 비례 피해)가 하나라도 있어야 한다.
func overrides_basic_attack() -> bool:
	if attack_override_duration <= 0.0:
		return false
	return attack_override_aoe_radius > 0.0 or attack_override_max_hp_percent > 0.0


# 시전자가 지금 이 스킬을 쓸 수 있는 체력인가(#328).
#
# 조건이 없으면(0) 언제나 true 다. 최대 체력이 0 인 비정상 상태에서는 막는다 —
# 0 으로 나누지 않고, "체력이 없는데 역전기가 나가는" 쪽보다 안전하다.
func meets_hp_condition(current_hp: int, max_hp_value: int) -> bool:
	if require_hp_below_percent <= 0.0:
		return true
	if max_hp_value <= 0:
		return false
	return float(current_hp) / float(max_hp_value) < require_hp_below_percent


# 바뀐 평타가 이 적에게 넣을 피해. 비율이 0 이면 공격력을 그대로 쓰라는 뜻이라 0 을 돌려준다.
#
# 방어력은 여기서 적용하지 않는다. 대상의 take_damage() 가 한다(get_damage_against 와 같은 규약).
func get_attack_override_damage(target_max_hp: int) -> int:
	if attack_override_max_hp_percent <= 0.0:
		return 0
	return int(round(maxf(float(target_max_hp), 0.0) * attack_override_max_hp_percent))


# 이 스킬이 아군을 회복시키는가.
func heals_allies() -> bool:
	return ally_heal > 0


# 신앙심 강화를 반영한 아군 회복량.
# base_power 와 같은 규약을 쓴다 — scales_with_faith 가 꺼져 있으면 적힌 값 그대로다.
func get_effective_ally_heal(faith_boost: float = 1.0) -> int:
	if not scales_with_faith:
		return ally_heal
	return int(round(ally_heal * faith_boost))

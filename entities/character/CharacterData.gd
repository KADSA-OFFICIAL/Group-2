extends Resource
class_name CharacterData

# 캐릭터의 단일 정의 출처 (data definition).
# 이름/스텟/스킬/외형을 한 리소스로 묶는다.
# 스텟은 기존 PlayerStats를 재사용하고, 캐릭터별 .tres로 교체 주입한다.

# ===== 분류 (Role) =====
# 캐릭터의 전투 역할 분류. 편성/시너지/밸런스/UI 표시 등에서 참고한다.
#
# 역할 기본기(설계 정본: docs/combat-screen-design.md §2):
#   TANK          - 표식 -> 기절
#   RANGED_DEALER - 평타 스택(공속·이속)
#   BUFFER        - 처형
enum Role {
	TANK,           # 탱커 (구 MELEE_DEALER. 값 0 유지로 기존 .tres 호환)
	RANGED_DEALER,  # 원거리 딜러
	BUFFER,         # 버퍼
}

# 기본값 TANK: 기존/신규 .tres가 누락 시 안전하게 로드되도록 첫 값을 기본으로 둔다.
@export var role: Role = Role.TANK

# ===== 겸직 (Dual Role) =====
# 로스터 6명 중 3명은 두 역할을 겸직한다(탱커/버퍼, 원거리/탱커, 버퍼/원거리).
# 겸직자는 시너지 계산에서 **두 역할 카운트에 각각 +1** 기여한다.
#
# NONE이 기본값(0)이라 기존 .tres는 그대로 단일 역할로 로드된다(하위 호환).
# Role과 별도 enum인 이유: Role에 NONE을 넣으면 역할 카운트 순회에 빈 값이 섞이기 때문이다.
enum SecondaryRole {
	NONE,           # 겸직 없음 (순혈)
	TANK,
	RANGED_DEALER,
	BUFFER,
}

@export var secondary_role: SecondaryRole = SecondaryRole.NONE

# ===== 식별 (Identity) =====
@export var character_id: StringName = &""   # 고유 식별자 (예: &"gangji")
@export var display_name: String = ""         # 화면 표시 이름
@export_multiline var description: String = ""

# 플레이어가 파티에 넣어 쓸 수 있는가. false 면 **편성이 거부된다**(#216).
#
# **기본값이 false 인 이유**: 플레이어블 로스터는 6명으로 닫혔다. 앞으로 추가되는
# 캐릭터는 전부 스토리 전용이다. 그래서 "편성 가능"이 예외이고 명시해야 하는 쪽이다.
#   - 기본 true 였다면 스토리 캐릭터를 저작할 때마다 false 를 기억해서 적어야 하고,
#     빼먹으면 조용히 편성 목록과 시너지 계산에 들어간다(#216 이 고친 그 문제).
#   - 기본 false 면 빼먹었을 때 "편성이 안 된다"로 드러난다. 조용히 틀리지 않는다.
#
# 편성 가능한 6명은 각자 .tres 에 playable = true 를 명시한다.
#
# 왜 필요한가: 초상 아트가 먼저 들어온 인물이 로스터에 저작되면(#184) 편성이 되고,
# 편성되면 SynergySystem 이 그 역할을 세어 시너지를 열어 준다. 스토리 인물과 보스가
# 플레이어 시너지를 만드는 것은 의도가 아니다.
#
# 왜 이름이 story_only 가 아닌가: goddess 는 스토리 전용이 아니라 **최종보스로 등장할**
# 인물이다. 둘의 공통점은 "스토리에만 나온다"가 아니라 "플레이어가 쓰지 않는다"다.
# 필드 이름은 이유가 아니라 규칙을 말해야 한다.
#
# **정의를 지우는 것이 아니다.** 여기 남아 있어야 스토리의 character_id 가 계속
# 해석되어 이름·초상·색이 출처에서 나온다(#187). playable 은 편성 가능 여부만 정한다.
@export var playable: bool = false

# ===== 스텟 (Stats) =====
# 캐릭터의 스텟 출처. 비어 있으면 기본값 PlayerStats를 사용한다.
@export var stats: PlayerStats = PlayerStats.new()

# ===== 스킬 (Skills) =====
@export var skills: Array[SkillData] = []


# ===== 스킬 게이지 (Skill gauge) =====
#
# 이 캐릭터가 **전투 중 쌓아 쓰는 자원**을 갖는가. 0 이면 게이지가 없다(대부분의 캐릭터).
#
# 왜 CharacterData 인가: 게이지는 캐릭터 개성이다. 역할 메커니즘(원거리 스택)처럼 파티
# 구성으로 켜지고 꺼지는 것이 아니라 그 인물이 항상 갖는 것이라, 수치의 출처가 CombatTuning
# (전원 공용) 이 아니라 캐릭터 정의다. 스킬 두 개가 같은 게이지를 나눠 쓰므로 SkillData 도 아니다.
#
# 충전 규약: **파티 전체의 평타**가 채운다(자기 평타 포함). 표식 충전(docs §8.1)과 같은 규약이다.
# 시간으로 줄지 않는다 — 쓸 때만 사라진다.

## 게이지 상한. 0 이면 이 캐릭터는 게이지를 갖지 않는다.
@export var skill_gauge_max: int = 0

## 파티원 평타 1회당 차는 양.
@export var skill_gauge_gain_per_attack: int = 0
# ===== 평타 (Basic attack) =====
#
# 평타가 **근접 즉시타격인가 원거리 투사체인가**는 캐릭터의 성질이다(미나는 근접, 태희는 원거리).
# 역할(RANGED_DEALER)로 판단하지 않는다 — 역할은 시너지 카운트를 위한 분류이고, 겸직도 있어서
# "원거리 역할을 가졌으니 평타도 원거리"가 성립하지 않는다.
#
# 기본값 0 은 지금까지의 근접 즉시타격이라, 이 필드를 적지 않은 기존 .tres 는 그대로 돈다.

## 평타 투사체의 속도(px/s). 0 이면 **근접 즉시타격**이다(사거리 안이면 그 자리에서 명중).
@export var basic_attack_projectile_speed: float = 0.0

## 평타 투사체가 날아가는 최대 거리(px). basic_attack_projectile_speed 가 0 이면 쓰지 않는다.
@export var basic_attack_projectile_range: float = 0.0

## 평타 사거리(px). 0 이면 씬의 AttackArea2D 위치에서 구한다(지금까지의 동작).
##
## 원거리 평타는 씬 노드보다 훨씬 멀리 닿아야 하는데, 그 거리를 씬에서 주면 캐릭터마다
## Player.tscn 을 복제해야 한다. 사거리는 캐릭터 정의가 갖는 편이 옳다.
@export var basic_attack_range: float = 0.0

## 평타가 **대상 자리에 떨어질 때** 함께 때리는 원의 반경(px). 0 이면 대상 하나만 때린다(#336).
##
## 세 번째 평타 모양이다. 앞의 둘과 무엇이 다른가:
##   근접 즉시타격 — 사거리 안 대상 **하나**를 그 자리에서 때린다.
##   투사체        — **날아가서** 맞는다. 그래서 빗나갈 수 있고 조준이 의미를 갖는다.
##   낙뢰(이 필드) — 원거리인데 **날아가지 않는다.** 대상 자리에 즉시 떨어지고 그 원 안이 전부 맞는다.
##
## 투사체와 나눠 둔 이유: 날아가는 시간이 없으므로 **빗나가지 않는다.** 그 대신 판정이
## 대상 자리에 묶여 있어 조준으로 더 많이 맞힐 수 없다 — 적이 뭉쳐 있을 때만 여러 명이 맞는다.
## 투사체의 `aoe_at_projectile_impact`(태희 4타)와 겉모습이 비슷하지만 그쪽은 **탄이 멈춘 자리**이고
## 이쪽은 **대상 자리**다. 탄이 없으므로 멈출 자리도 없다.
##
## 반경 안 적 하나하나가 평타를 맞은 것으로 처리된다 — 처형·피흡·표식이 각각 적용된다.
@export var basic_attack_strike_radius: float = 0.0

## 평타에 맞은 적에게 걸 상태 효과 id. 비어 있으면 피해만 준다(#336).
##
## 적 쪽에는 이미 같은 통로가 있었지만(`EnemyData.charged_attack_effect`) 플레이어 평타에는
## 없었다. 스킬(`SkillData.apply_effect_id`)이 아니라 **캐릭터 정의**가 갖는 이유는 평타의
## 다른 성질(근접/원거리/사거리)과 같다 — 이것은 "이 인물의 평타가 무엇인가"이지
## 따로 발동하는 스킬이 아니다.
##
## 평타 모양과 무관하게 걸린다: 근접이든 투사체든 낙뢰든 **닿았으면** 걸린다.
## 판정 지점이 `Player._resolve_attack_hit()`(평타 규칙의 단일 출처) 한 곳이기 때문이다.
## 효과의 지속시간·내용은 `StatusEffectData` 가 소유한다.
@export var basic_attack_effect_id: StringName = &""


# 이 캐릭터의 평타가 날아가는 투사체인가.
func has_projectile_basic_attack() -> bool:
	return basic_attack_projectile_speed > 0.0


# 이 캐릭터의 평타가 대상 자리에 떨어지는 낙뢰형인가(#336).
#
# 투사체와 동시에 켜지면 투사체가 이긴다(Player.try_attack 의 분기 순서).
# 둘 다 저작하는 것은 지금 스펙에 없어서 validate() 가 막는다.
func has_strike_basic_attack() -> bool:
	return basic_attack_strike_radius > 0.0 and not has_projectile_basic_attack()

# ===== 외형 (Appearance) =====
@export var sprite_texture: Texture2D = null
## 흰색 도형 플레이스홀더를 칠하는 색이다. 아래 walk_frames(실제 아트)에는 입히지 않는다
## — 실제 아트는 자기 색을 가지므로 곱하면 색이 죽는다.
## 메타 화면(캐릭터/편성/주문 등)은 이 색을 도형 스와치에 계속 쓴다.
@export var tint: Color = Color.WHITE
@export var sprite_scale: Vector2 = Vector2(2, 2)

# ----- 워크 애니메이션 (Walk animation) -----
# 4방향 x 3프레임 워크 사이클. 씬에 AnimatedSprite2D가 있고 이 값이 채워져 있으면
# 그쪽이 외형을 맡고 위 sprite_texture(도형 플레이스홀더)는 숨는다.
# null이면 지금까지와 똑같이 Sprite2D로 정지 이미지를 그린다(하위 호환).
#
# 애니메이션 이름과 방향 판정의 단일 출처는 WalkAnimation이다(적과 플레이어가 같이 쓴다).
# 규약만 지키면 시트를 갈아끼워도 스크립트를 고칠 필요가 없다.
# 시트 저작 규약: assets/sprites/characters/README.md
@export var walk_frames: SpriteFrames = null
## 워크 시트 표시 배율. 시트마다 원본 해상도가 달라 sprite_texture와 따로 둔다.
@export var walk_sprite_scale: Vector2 = Vector2(1, 1)
## 워크 시트 표시 오프셋(px, 배율 적용 전). 셀 안의 발 기준선을 노드 원점에 맞추는 값이다.
## 시트 셀이 캐릭터보다 크므로 이 값이 없으면 스프라이트가 발밑이 아니라 몸 한가운데에 걸린다.
@export var walk_sprite_offset: Vector2 = Vector2.ZERO

# ----- 턴제 전투 정지 스프라이트 (Turn-battle standing sprite) -----
# 턴제 전투 화면(`stage/turn/TurnBattle.tscn`)이 세우는 **측면 전투 자세 한 장**이다.
#
# 워크 시트(`walk_frames`)와 용도가 다르다: 그쪽은 실시간 화면의 4방향 이동이고,
# 이쪽은 제자리에 서서 턴을 기다리는 측면 포즈다. 턴제 화면에서 워크 시트의 한 컷을
# 빌려 쓰면 걷다 멈춘 자세로 굳어 보인다.
#
# 비어 있으면 전투 화면이 `tint` 색 네모를 세운다(Phase 0 플레이스홀더).
# 저작 규약과 생성 프롬프트: docs/turn-battle-sprite-prompts.md
@export var battle_sprite: Texture2D = null

# 메타 화면(메인화면 등)에서 크게 보여주는 전신 일러스트.
# 전투용 sprite_texture 와 용도가 다르므로 필드를 나눈다.
# 기본값 null 이며, 비어 있으면 화면이 tint 색 플레이스홀더로 대체한다.
# (docs §0: 아트 확정 전까지는 도형 플레이스홀더를 쓴다.)
@export var portrait: Texture2D = null

# ===== 장비 (Equipment) =====
# 슬롯당 1개 장착. 장착/해제 시 스텟에 보너스를 합산/원복한다.
# 착탈 오케스트레이션·제작·인벤토리는 EquipmentSystem(autoload)이 담당한다.
@export var equipped_weapon: EquipmentData = null
@export var equipped_helmet: EquipmentData = null
@export var equipped_chest: EquipmentData = null
@export var equipped_leggings: EquipmentData = null
@export var equipped_mirror: EquipmentData = null

# ----- 확장 가이드 (Extensibility) -----
# 새 항목은 위 섹션 중 알맞은 곳에 @export 필드를 "기본값과 함께" 추가한다.
# 기본값이 있으면 기존 .tres는 누락 필드를 기본값으로 로드하므로 호환이 유지된다.
# 후속 이슈에서: level/exp 등 성장 필드, voice/portrait 등 외형 필드를 같은 방식으로 추가한다.


# ===== 스킬 조회 (Skill Accessors) =====
# "이 키 슬롯에 걸린 스킬이 무엇인가"의 단일 진입점이다.
# 화면·입력 처리가 skills 배열을 각자 훑으면 슬롯 해석이 흩어진다(get_roles() 와 같은 이유).
#
# skills 에는 키로 쓰지 않는 평타 패시브(SkillData.every_n_attacks)도 들어 있으므로
# 배열 순서가 아니라 각 스킬이 선언한 input_slot 으로 찾는다.

func get_skill_for_slot(slot: SkillData.InputSlot) -> SkillData:
	if slot == SkillData.InputSlot.NONE:
		return null
	for skill in skills:
		if skill != null and skill.input_slot == slot:
			return skill
	return null


# 이 캐릭터가 스킬 게이지를 갖는가.
func has_skill_gauge() -> bool:
	return skill_gauge_max > 0


# ===== 역할 조회 (Role Accessors) =====
# 시너지 계산 등은 아래 헬퍼를 통해 역할을 읽는다.
# role/secondary_role 필드를 각자 해석하면 겸직 처리가 흩어지므로, get_roles()를 단일 진입점으로 둔다.

# 이 캐릭터가 가진 역할 전부를 반환한다. 순혈이면 1개, 겸직이면 2개.
func get_roles() -> Array[Role]:
	var result: Array[Role] = [role]
	var second := get_secondary_role_as_role()
	if second != -1 and second != role:
		result.append(second)
	return result

# secondary_role을 Role로 변환한다. 겸직이 없으면 -1.
# SecondaryRole은 NONE이 0이라 Role보다 1씩 밀려 있다.
func get_secondary_role_as_role() -> int:
	if secondary_role == SecondaryRole.NONE:
		return -1
	return (secondary_role - 1) as Role

# 겸직 여부.
func is_dual_role() -> bool:
	return get_roles().size() >= 2

# 특정 역할을 가지고 있는지 (주 역할이든 겸직이든).
func has_role(r: Role) -> bool:
	return get_roles().has(r)


# 역할의 화면 표시용 한글 이름을 반환한다.
func get_role_name() -> String:
	return role_to_name(role)

# 겸직까지 포함한 표시 이름. 순혈이면 "탱커", 겸직이면 "탱커/버퍼".
func get_roles_display_name() -> String:
	var names: Array[String] = []
	for r in get_roles():
		names.append(role_to_name(r))
	return "/".join(names)

# Role -> 한글 이름. 표시 이름의 단일 출처.
static func role_to_name(r: Role) -> String:
	match r:
		Role.TANK:
			return "탱커"
		Role.RANGED_DEALER:
			return "원거리 딜러"
		Role.BUFFER:
			return "버퍼"
		_:
			return "알 수 없음"

# 안전한 스텟 접근: stats가 비어 있으면 기본 PlayerStats를 반환한다.
func get_stats() -> PlayerStats:
	if stats == null:
		stats = PlayerStats.new()
	return stats

# skill_id로 스킬을 찾는다. 없으면 null.
func find_skill(id: StringName) -> SkillData:
	for skill in skills:
		if skill != null and skill.skill_id == id:
			return skill
	return null

# ===== 장비 착탈 (Equip / Unequip) =====

# 슬롯에 맞는 장비를 장착한다. 같은 슬롯의 기존 장비는 교체된다.
# 장착 후 스텟 보너스를 재계산해 PlayerStats에 반영한다.
func equip(item: EquipmentData) -> void:
	if item == null:
		return
	match item.slot:
		EquipmentData.Slot.WEAPON:
			equipped_weapon = item
		EquipmentData.Slot.HELMET:
			equipped_helmet = item
		EquipmentData.Slot.CHEST:
			equipped_chest = item
		EquipmentData.Slot.LEGGINGS:
			equipped_leggings = item
		EquipmentData.Slot.MIRROR:
			equipped_mirror = item
	_apply_equipment_to_stats()

# 특정 슬롯의 장비를 해제한다. 해제 후 스텟 보너스를 재계산한다.
func unequip(slot: EquipmentData.Slot) -> void:
	match slot:
		EquipmentData.Slot.WEAPON:
			equipped_weapon = null
		EquipmentData.Slot.HELMET:
			equipped_helmet = null
		EquipmentData.Slot.CHEST:
			equipped_chest = null
		EquipmentData.Slot.LEGGINGS:
			equipped_leggings = null
		EquipmentData.Slot.MIRROR:
			equipped_mirror = null
	_apply_equipment_to_stats()

# 슬롯에 장착된 장비를 반환한다. 없으면 null.
func get_equipped(slot: EquipmentData.Slot) -> EquipmentData:
	match slot:
		EquipmentData.Slot.WEAPON:
			return equipped_weapon
		EquipmentData.Slot.HELMET:
			return equipped_helmet
		EquipmentData.Slot.CHEST:
			return equipped_chest
		EquipmentData.Slot.LEGGINGS:
			return equipped_leggings
		EquipmentData.Slot.MIRROR:
			return equipped_mirror
	return null

# 장착된 모든 장비의 스텟 보너스를 합산해 Dictionary로 반환한다.
func get_equipment_bonuses() -> Dictionary:
	var totals := {
		"physical_attack": 0,
		"magic_attack": 0,
		"physical_defense": 0,
		"magic_defense": 0,
		"hp": 0,
		"move_speed_percent": 0.0,
		"goddess_boost": 0.0,
	}
	for item in [equipped_weapon, equipped_helmet, equipped_chest, equipped_leggings, equipped_mirror]:
		if item == null:
			continue
		totals["physical_attack"] += item.physical_attack_bonus
		totals["magic_attack"] += item.magic_attack_bonus
		totals["physical_defense"] += item.physical_defense_bonus
		totals["magic_defense"] += item.magic_defense_bonus
		totals["hp"] += item.hp_bonus
		totals["move_speed_percent"] += item.move_speed_bonus
		totals["goddess_boost"] += item.goddess_skill_boost_bonus
	return totals

# 장착 상태의 보너스 합계를 PlayerStats(단일 출처)에 밀어 넣는다.
func _apply_equipment_to_stats() -> void:
	var b := get_equipment_bonuses()
	get_stats().set_equipment_bonuses(
		b["physical_attack"], b["magic_attack"],
		b["physical_defense"], b["magic_defense"], b["hp"],
		b["move_speed_percent"], b["goddess_boost"]
	)

# 데이터 무결성 점검 (id가 비었는지 등). 문제 메시지 배열을 반환한다.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(character_id).is_empty():
		problems.append("character_id가 비어 있습니다.")
	if display_name.is_empty():
		problems.append("display_name이 비어 있습니다.")
	# 겸직인데 주 역할과 같으면 카운트가 중복되므로 데이터 오류다.
	if secondary_role != SecondaryRole.NONE and get_secondary_role_as_role() == role:
		problems.append("secondary_role이 주 역할과 같습니다: " + get_role_name())

	# 게이지를 가진 캐릭터는 충전량도 있어야 한다. 충전량이 0이면 영원히 0인 자원이 된다.
	if skill_gauge_max < 0:
		problems.append("skill_gauge_max는 0 이상이어야 합니다.")
	if skill_gauge_max > 0 and skill_gauge_gain_per_attack <= 0:
		problems.append("skill_gauge_max가 있으면 skill_gauge_gain_per_attack도 0보다 커야 합니다.")
	if skill_gauge_max == 0 and skill_gauge_gain_per_attack != 0:
		problems.append("skill_gauge_max가 0인데 skill_gauge_gain_per_attack이 설정되어 있습니다.")

	# 투사체 평타는 날아갈 거리가 있어야 한다. 0 이면 발사되자마자 사라진다.
	if basic_attack_projectile_speed > 0.0 and basic_attack_projectile_range <= 0.0:
		problems.append("basic_attack_projectile_speed가 있으면 basic_attack_projectile_range도 0보다 커야 합니다.")
	if basic_attack_projectile_speed < 0.0 or basic_attack_projectile_range < 0.0 or basic_attack_range < 0.0:
		problems.append("basic_attack_* 값은 0 이상이어야 합니다.")
	if basic_attack_strike_radius < 0.0:
		problems.append("basic_attack_strike_radius는 0 이상이어야 합니다.")
	# 평타 모양은 하나여야 한다. 둘 다 켜면 어느 쪽이 나가는지가 코드의 분기 순서에 숨는다.
	if basic_attack_strike_radius > 0.0 and basic_attack_projectile_speed > 0.0:
		problems.append("basic_attack_strike_radius와 basic_attack_projectile_speed를 함께 쓸 수 없습니다(평타 모양은 하나다).")

	# 워크 시트를 지정했다면 네 방향이 모두 있어야 한다.
	# 하나라도 빠지면 그 방향으로 이동할 때 재생할 애니메이션이 없어 외형이 멈춘다.
	for anim in WalkAnimation.missing_animations(walk_frames):
		problems.append("walk_frames에 '%s' 애니메이션이 없습니다." % anim)

	# 턴제 필드(#450). 저작하지 않은 기존 .tres 는 기본값이라 아무 문제도 보고되지 않는다.
	problems.append_array(validate_turn())

	return problems


# =====================================================================
# 턴제 (Turn-based) — #450
# =====================================================================
#
# 캐릭터 정의의 단일 출처는 `CharacterData` 하나다(SYSTEM_CONVENTIONS §2). 턴제 전투용
# 로스터를 별도 파일/딕셔너리로 다시 정의하지 않고 여기에 얹는다.
#
# 기존 `role`/`secondary_role`(탱커/원거리/버퍼)은 **그대로 둔다.** 그 축은 실시간 전투와
# `SynergySystem`의 역할 카운트가 쓰고 있고, 턴제 8역할과는 다른 분류다. 둘은 나란히 존재한다.
#
# 기본값의 원칙: 전부 표준 유닛에 해당하는 값이다. 그래서 이 섹션을 모르는 기존 6인의
# `.tres`가 경고 없이 로드되고, 턴제에서도 "충격 / 참격 / 파괴자 / 전열 선호"로 동작한다.

@export_group("턴제")

## 원소. 약점 격파와 자물쇠 해제의 축이다.
@export var element: TurnCombat.Element = TurnCombat.Element.IMPACT

## 물리 타입. 원소와 독립된 두 번째 상성 축이다.
@export var physical_type: TurnCombat.PhysicalType = TurnCombat.PhysicalType.SLASH

## 턴제 역할(8종). 아이콘 하나로 역할을 소통하기 위한 분류다.
@export var battle_class: TurnCombat.BattleClass = TurnCombat.BattleClass.BREAKER

## 선호 랭크(1~4). 편성 화면이 자동 배치할 때 쓰고, 벗어나면 UI가 경고만 한다
## (강제하지 않는다 — 위치를 옮기는 것 자체가 전술이므로 금지하면 시스템이 죽는다).
@export var preferred_ranks: Array[int] = [1, 2]

## 이 캐릭터의 턴제 스킬. `skills`(실시간 Q/E/패시브)와 **별도 배열**이다.
##
## 왜 나눴는가: 같은 배열에 섞으면 실시간 HUD가 오의를 Q 슬롯으로 집어 오고, 턴제
## 액션 바가 투사체 패시브를 스킬 버튼으로 띄운다. 둘 다 `SkillData`이므로 **정의 출처는
## 하나**이고, 나뉜 것은 "어느 전투가 이 스킬을 쓰는가"라는 소속뿐이다.
@export var turn_skills: Array[SkillData] = []


# ===== 턴제 스킬 조회 (Turn skill accessors) =====

# 지정한 행동 종류의 스킬을 반환한다. 없으면 null.
#
# 오의·평타는 캐릭터당 하나라는 전제다(설계서 §4.3.2 — 오의 버튼은 하나뿐이다).
func get_turn_skill(kind: TurnCombat.ActionKind) -> SkillData:
	for skill in turn_skills:
		if skill != null and skill.turn_action == kind:
			return skill
	return null


# 지정한 행동 종류의 스킬 전부. 전투 스킬과 특성은 여러 개일 수 있다.
func get_turn_skills(kind: TurnCombat.ActionKind) -> Array[SkillData]:
	var out: Array[SkillData] = []
	for skill in turn_skills:
		if skill != null and skill.turn_action == kind:
			out.append(skill)
	return out


func get_turn_basic() -> SkillData:
	return get_turn_skill(TurnCombat.ActionKind.BASIC)


func get_turn_ultimate() -> SkillData:
	return get_turn_skill(TurnCombat.ActionKind.ULTIMATE)


# 턴제 전투에 참여할 수 있는가. 평타가 없으면 차례가 와도 할 수 있는 일이 없다.
func is_turn_ready() -> bool:
	return get_turn_basic() != null


func get_battle_class_name() -> String:
	return TurnCombat.class_name_of(battle_class)


func get_element_name() -> String:
	return TurnCombat.element_name(element)


func get_physical_type_name() -> String:
	return TurnCombat.physical_name(physical_type)


# 선호 랭크를 벗어난 자리인가. UI가 경고 색을 칠하는 데만 쓴다.
func is_off_preferred_rank(rank: int) -> bool:
	if preferred_ranks.is_empty():
		return false
	return not preferred_ranks.has(rank)


# 턴제 데이터의 무결성 점검. `validate()`가 호출한다.
#
# 별도 함수로 둔 이유: 위쪽 `validate()`는 실시간 필드를 검사하고 있고, 두 검사를 한 함수에
# 뭉치면 어느 축이 깨졌는지 메시지만 보고 알기 어렵다.
func validate_turn() -> Array[String]:
	var problems: Array[String] = []

	for rank in preferred_ranks:
		if rank < 1 or rank > TurnCombat.ALLY_RANK_COUNT:
			problems.append("preferred_ranks에 아군 랭크 범위(1~%d) 밖의 값이 있습니다: %d"
				% [TurnCombat.ALLY_RANK_COUNT, rank])

	# 턴제 스킬을 저작했다면 최소한 평타는 있어야 한다. 없으면 차례가 와도 할 수 있는 일이 없다.
	if not turn_skills.is_empty() and get_turn_basic() == null:
		problems.append("turn_skills에 일반공격(ActionKind.BASIC)이 없습니다.")

	# 오의를 저작했는데 게이지 최대치가 0이면 영원히 발동되지 않는다.
	if get_turn_ultimate() != null and get_stats().get_energy_max() <= 0:
		problems.append("오의가 있는데 stats.energy_max가 0입니다(영원히 발동되지 않습니다).")

	# 같은 행동 종류가 둘 이상이면 액션 버튼이 어느 쪽을 띄울지 코드 분기 순서에 숨는다.
	if get_turn_skills(TurnCombat.ActionKind.BASIC).size() > 1:
		problems.append("일반공격이 둘 이상입니다(하나여야 합니다).")
	if get_turn_skills(TurnCombat.ActionKind.ULTIMATE).size() > 1:
		problems.append("오의가 둘 이상입니다(하나여야 합니다).")

	return problems

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
@export var character_id: StringName = &""   # 고유 식별자 (예: &"shipduck")
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

	# 워크 시트를 지정했다면 네 방향이 모두 있어야 한다.
	# 하나라도 빠지면 그 방향으로 이동할 때 재생할 애니메이션이 없어 외형이 멈춘다.
	for anim in WalkAnimation.missing_animations(walk_frames):
		problems.append("walk_frames에 '%s' 애니메이션이 없습니다." % anim)

	return problems
extends Resource
class_name CharacterData

# 캐릭터의 단일 정의 출처 (data definition).
# 이름/스텟/스킬/외형을 한 리소스로 묶는다.
# 스텟은 기존 PlayerStats를 재사용하고, 캐릭터별 .tres로 교체 주입한다.

# ===== 분류 (Role) =====
# 캐릭터의 전투 역할 분류. 편성/밸런스/UI 표시 등에서 참고한다.
enum Role {
	MELEE_DEALER,   # 근접 딜러
	RANGED_DEALER,  # 원거리 딜러
	BUFFER,         # 버퍼
}

# 기본값 MELEE_DEALER: 기존/신규 .tres가 누락 시 안전하게 로드되도록 첫 값을 기본으로 둔다.
@export var role: Role = Role.MELEE_DEALER

# ===== 식별 (Identity) =====
@export var character_id: StringName = &""   # 고유 식별자 (예: &"shipduck")
@export var display_name: String = ""         # 화면 표시 이름
@export_multiline var description: String = ""

# ===== 스텟 (Stats) =====
# 캐릭터의 스텟 출처. 비어 있으면 기본값 PlayerStats를 사용한다.
@export var stats: PlayerStats = PlayerStats.new()

# ===== 스킬 (Skills) =====
@export var skills: Array[SkillData] = []

# ===== 외형 (Appearance) =====
@export var sprite_texture: Texture2D = null
@export var tint: Color = Color.WHITE
@export var sprite_scale: Vector2 = Vector2(2, 2)

# ===== 장비 (Equipment) =====
# 슬롯당 1개 장착. 장착/해제 시 스텟에 보너스를 합산/원복한다.
# 착탈 오케스트레이션·제작·인벤토리는 EquipmentSystem(autoload)이 담당한다.
@export var equipped_weapon: EquipmentData = null
@export var equipped_armor: EquipmentData = null
@export var equipped_accessory: EquipmentData = null

# ----- 확장 가이드 (Extensibility) -----
# 새 항목은 위 섹션 중 알맞은 곳에 @export 필드를 "기본값과 함께" 추가한다.
# 기본값이 있으면 기존 .tres는 누락 필드를 기본값으로 로드하므로 호환이 유지된다.
# 후속 이슈에서: level/exp 등 성장 필드, voice/portrait 등 외형 필드를 같은 방식으로 추가한다.


# 역할의 화면 표시용 한글 이름을 반환한다.
func get_role_name() -> String:
	match role:
		Role.MELEE_DEALER:
			return "근접 딜러"
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
		EquipmentData.Slot.ARMOR:
			equipped_armor = item
		EquipmentData.Slot.ACCESSORY:
			equipped_accessory = item
	_apply_equipment_to_stats()

# 특정 슬롯의 장비를 해제한다. 해제 후 스텟 보너스를 재계산한다.
func unequip(slot: EquipmentData.Slot) -> void:
	match slot:
		EquipmentData.Slot.WEAPON:
			equipped_weapon = null
		EquipmentData.Slot.ARMOR:
			equipped_armor = null
		EquipmentData.Slot.ACCESSORY:
			equipped_accessory = null
	_apply_equipment_to_stats()

# 슬롯에 장착된 장비를 반환한다. 없으면 null.
func get_equipped(slot: EquipmentData.Slot) -> EquipmentData:
	match slot:
		EquipmentData.Slot.WEAPON:
			return equipped_weapon
		EquipmentData.Slot.ARMOR:
			return equipped_armor
		EquipmentData.Slot.ACCESSORY:
			return equipped_accessory
	return null

# 장착된 모든 장비의 스텟 보너스를 합산해 Dictionary로 반환한다.
func get_equipment_bonuses() -> Dictionary:
	var totals := {
		"physical_attack": 0,
		"magic_attack": 0,
		"physical_defense": 0,
		"magic_defense": 0,
		"hp": 0,
	}
	for item in [equipped_weapon, equipped_armor, equipped_accessory]:
		if item == null:
			continue
		totals["physical_attack"] += item.physical_attack_bonus
		totals["magic_attack"] += item.magic_attack_bonus
		totals["physical_defense"] += item.physical_defense_bonus
		totals["magic_defense"] += item.magic_defense_bonus
		totals["hp"] += item.hp_bonus
	return totals

# 장착 상태의 보너스 합계를 PlayerStats(단일 출처)에 밀어 넣는다.
func _apply_equipment_to_stats() -> void:
	var b := get_equipment_bonuses()
	get_stats().set_equipment_bonuses(
		b["physical_attack"], b["magic_attack"],
		b["physical_defense"], b["magic_defense"], b["hp"]
	)

# 데이터 무결성 점검 (id가 비었는지 등). 문제 메시지 배열을 반환한다.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(character_id).is_empty():
		problems.append("character_id가 비어 있습니다.")
	if display_name.is_empty():
		problems.append("display_name이 비어 있습니다.")
	return problems
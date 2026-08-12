extends Node

# 장비 런타임 시스템 (autoload).
# 책임: 제작(재화 차감) + 보유 인벤토리 + 캐릭터 착탈 오케스트레이션.
# 데이터 출처는 EquipmentDatabase, 재화 출처는 CurrencySystem, 스텟은 PlayerStats.
# (단일 출처 원칙: 여기서 재화/스텟/장비를 다시 정의하지 않고 참조한다.)

# 저장 스키마에서 장비(보유 + 착용)가 들어가는 키.
const SAVE_KEY := "equipment"

# 보유 인벤토리: equipment_id(StringName) -> 보유 수량(int)
var _inventory: Dictionary = {}

func _ready() -> void:
	name = "EquipmentSystem"
	# 저장 스키마의 장비 부분은 이 시스템이 소유한다(SaveSystem은 내부를 모른다).
	SaveSystem.register_provider(SAVE_KEY, self)

# ===== 제작 (Crafting) =====

# 제작 가능 여부: 장비가 존재하고, 모든 craft_cost를 충당할 재화가 있는지.
func can_craft(equipment_id: StringName) -> bool:
	if not EquipmentDatabase.has_equipment(equipment_id):
		return false
	var data := EquipmentDatabase.get_equipment(equipment_id)
	if data == null:
		return false
	for currency_type in data.craft_cost:
		var need: int = int(data.craft_cost[currency_type])
		if not CurrencySystem.has_enough(currency_type, need):
			return false
	return true

# 제작한다. 성공 시 재화를 차감하고 보유에 추가한다.
func craft(equipment_id: StringName) -> bool:
	if not can_craft(equipment_id):
		push_warning("EquipmentSystem: 제작 불가(재화 부족 또는 미존재): " + String(equipment_id))
		return false

	var data := EquipmentDatabase.get_equipment(equipment_id)
	# 재화 차감 (CurrencySystem이 유일한 재화 출처).
	for currency_type in data.craft_cost:
		var cost: int = int(data.craft_cost[currency_type])
		if cost > 0:
			CurrencySystem.subtract_currency(currency_type, cost)

	_inventory[equipment_id] = get_owned_count(equipment_id) + 1
	EventBus.equipment_crafted.emit(equipment_id)
	return true

# ===== 보유 인벤토리 (Inventory) =====

func get_owned_count(equipment_id: StringName) -> int:
	return int(_inventory.get(equipment_id, 0))

func is_owned(equipment_id: StringName) -> bool:
	return get_owned_count(equipment_id) > 0

func get_owned_ids() -> Array:
	return _inventory.keys()

# ===== 착탈 (Equip / Unequip) =====

# 캐릭터에 장비를 장착한다. 보유한 장비여야 한다.
# 장착해도 인벤토리에서 소모하지 않는다(착용 중일 뿐 보유는 유지).
func equip(character: CharacterData, equipment_id: StringName) -> bool:
	if character == null:
		push_warning("EquipmentSystem: character가 null입니다.")
		return false
	if not is_owned(equipment_id):
		push_warning("EquipmentSystem: 보유하지 않은 장비입니다: " + String(equipment_id))
		return false

	var data := EquipmentDatabase.get_equipment(equipment_id)
	if data == null:
		return false

	character.equip(data)
	EventBus.equipment_equipped.emit(character.character_id, equipment_id, data.slot)
	return true

# 캐릭터의 특정 슬롯 장비를 해제한다.
func unequip(character: CharacterData, slot: EquipmentData.Slot) -> bool:
	if character == null:
		push_warning("EquipmentSystem: character가 null입니다.")
		return false
	character.unequip(slot)
	EventBus.equipment_unequipped.emit(character.character_id, slot)
	return true

# ===== 저장/복원 (Save / Load) =====
# SaveSystem은 이 두 함수만 호출한다.
#
# 착용 상태를 여기서 다루는 이유: 값의 소유자는 CharacterData(착용의 출처)지만,
# 착탈 오케스트레이션이 이 시스템의 책임이므로 직렬화도 여기서 CharacterDatabase를
# 순회해 모은다. 슬롯은 EquipmentData.slot에서 알 수 있으므로 따로 저장하지 않는다(중복 방지).
#
# 저장 형태:
#   {"inventory": {equipment_id: 수량}, "equipped": {character_id: [equipment_id, ...]}}

func to_save_dict() -> Dictionary:
	var inventory := {}
	for id in _inventory:
		inventory[String(id)] = get_owned_count(id)

	var equipped := {}
	for character_id in CharacterDatabase.get_all_ids():
		var character := CharacterDatabase.get_character(character_id)
		if character == null:
			continue
		var ids: Array[String] = []
		for slot in EquipmentData.Slot.values():
			var item := character.get_equipped(slot)
			if item != null:
				ids.append(String(item.equipment_id))
		if not ids.is_empty():
			equipped[String(character_id)] = ids

	return {
		"inventory": inventory,
		"equipped": equipped,
	}

func from_save_dict(data: Dictionary) -> void:
	# 보유 인벤토리를 먼저 복원한다. equip()이 보유를 요구하기 때문이다.
	_inventory.clear()
	var inventory: Dictionary = data.get("inventory", {})
	for raw in inventory:
		var equipment_id := StringName(raw)
		# 장비 정의가 사라졌으면(데이터 변경) 건너뛴다. 정의의 출처는 EquipmentDatabase다.
		if not EquipmentDatabase.has_equipment(equipment_id):
			push_warning("EquipmentSystem: 세이브의 알 수 없는 equipment_id(건너뜀): " + String(equipment_id))
			continue
		var count := int(inventory[raw])
		if count > 0:
			_inventory[equipment_id] = count

	# 착용 상태 복원: 모든 캐릭터의 슬롯을 비운 뒤 저장된 것만 다시 채운다.
	# (CharacterData는 .tres 캐시로 공유되므로 이전 착용 상태가 남아 있을 수 있다.)
	var equipped: Dictionary = data.get("equipped", {})
	for character_id in CharacterDatabase.get_all_ids():
		var character := CharacterDatabase.get_character(character_id)
		if character == null:
			continue
		for slot in EquipmentData.Slot.values():
			character.unequip(slot)
		for raw in equipped.get(String(character_id), []):
			equip(character, StringName(raw))

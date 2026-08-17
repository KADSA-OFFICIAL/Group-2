extends Node

# 상점 런타임 시스템 (autoload).
# 책임: 구매 가능 판정 + 구매 실행(재화 차감 -> 장비 지급).
#
# 단일 출처 원칙 (여기서 다시 정의하지 않는다):
#   판매 목록·가격 -> ShopDatabase / ShopEntryData
#   재화          -> CurrencySystem
#   장비 정의      -> EquipmentDatabase
#   보유 인벤토리  -> EquipmentSystem.grant()
#
# EquipmentSystem.craft() 와 같은 모양으로 만들었다(can_* 로 묻고 실행).
# 다른 점은 대가의 출처다: 제작은 EquipmentData.craft_cost, 구매는 ShopEntryData.price.

func _ready() -> void:
	name = "ShopSystem"

# ===== 판정 (Query) =====

# 구매 가능 여부: 항목이 존재하고, 모든 price 를 충당할 재화가 있는지.
func can_buy(entry_id: StringName) -> bool:
	var entry := ShopDatabase.get_entry(entry_id)
	if entry == null:
		return false
	return can_afford(entry)

# 이 항목의 가격을 지금 낼 수 있는가. (화면이 재화 비교를 다시 하지 않도록 공개한다.)
func can_afford(entry: ShopEntryData) -> bool:
	if entry == null:
		return false
	for currency_type in entry.price:
		var need: int = int(entry.price[currency_type])
		if not CurrencySystem.has_enough(currency_type, need):
			return false
	return true

# ===== 구매 (Purchase) =====

# 구매한다. 성공 시 재화를 차감하고 장비를 지급한다.
#
# 차감을 먼저 하고 지급을 나중에 하지 않는다. 지급이 실패하면 재화만 사라지기 때문이다.
# 그래서 지급 가능 여부(장비 정의 존재)를 먼저 확인한 뒤 차감한다.
func buy(entry_id: StringName) -> bool:
	var entry := ShopDatabase.get_entry(entry_id)
	if entry == null:
		return false

	if not can_afford(entry):
		push_warning("ShopSystem: 재화가 부족합니다: " + String(entry_id))
		return false

	# 지급할 수 없는 항목이면 재화를 건드리지 않고 중단한다.
	if not EquipmentDatabase.has_equipment(entry.equipment_id):
		push_warning("ShopSystem: 지급할 장비가 없습니다: " + String(entry.equipment_id))
		return false

	# 재화 차감 (CurrencySystem 이 유일한 재화 출처).
	for currency_type in entry.price:
		var cost: int = int(entry.price[currency_type])
		if cost > 0:
			CurrencySystem.subtract_currency(currency_type, cost)

	# 지급 (EquipmentSystem 이 인벤토리의 소유자).
	return EquipmentSystem.grant(entry.equipment_id, entry.count)

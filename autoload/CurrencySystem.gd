extends Node

# 재화 정식 목록(단일 출처). 다른 시스템(SaveSystem 등)은 이 상수를 참조한다.
# 장비 제작 재료: stone, tin, copper, iron_ore, coal
# 통화: gold
# 특수 재화: faith_stone
const DEFAULT_CURRENCIES := {
	"stone": 0,
	"tin": 0,
	"copper": 0,
	"iron_ore": 0,
	"coal": 0,
	"gold": 0,
	"faith_stone": 0
}

# 저장 스키마에서 재화가 들어가는 키. 기존 세이브 파일과 같은 키를 유지한다.
const SAVE_KEY := "currencies"

# Dictionary to store currency amounts
var currencies: Dictionary = {}

# Signal for currency changes
signal currency_changed(currency_type: String, amount: int, new_balance: int)
signal currency_added(currency_type: String, amount: int, new_balance: int)
signal currency_subtracted(currency_type: String, amount: int, new_balance: int)

func _ready():
	name = "CurrencySystem"
	# Initialize default currencies
	if currencies.is_empty():
		currencies = DEFAULT_CURRENCIES.duplicate()
	# 저장 스키마의 재화 부분은 이 시스템이 소유한다(SaveSystem은 내부를 모른다).
	SaveSystem.register_provider(SAVE_KEY, self)

# Add currency amount
func add_currency(currency_type: String, amount: int) -> bool:
	if amount < 0:
		push_error("Cannot add negative amount: ", amount)
		return false
	
	if not currencies.has(currency_type):
		currencies[currency_type] = 0
	
	currencies[currency_type] += amount
	var new_balance = currencies[currency_type]
	
	currency_changed.emit(currency_type, amount, new_balance)
	currency_added.emit(currency_type, amount, new_balance)
	
	return true

# Subtract currency amount
func subtract_currency(currency_type: String, amount: int) -> bool:
	if amount < 0:
		push_error("Cannot subtract negative amount: ", amount)
		return false
	
	if not currencies.has(currency_type):
		currencies[currency_type] = 0
	
	if currencies[currency_type] < amount:
		push_warning("Insufficient currency: ", currency_type)
		return false
	
	currencies[currency_type] -= amount
	var new_balance = currencies[currency_type]
	
	currency_changed.emit(currency_type, amount, new_balance)
	currency_subtracted.emit(currency_type, amount, new_balance)
	
	return true

# Get current balance of a currency
func get_balance(currency_type: String) -> int:
	if not currencies.has(currency_type):
		return 0
	return currencies[currency_type]

# Get all currencies
func get_all_currencies() -> Dictionary:
	return currencies.duplicate()

# Set currency to a specific value (useful for loading from save)
func set_currency(currency_type: String, amount: int):
	if amount < 0:
		push_error("Cannot set negative amount: ", amount)
		return
	
	var old_balance = currencies.get(currency_type, 0)
	currencies[currency_type] = amount
	
	var change = amount - old_balance
	if change != 0:
		currency_changed.emit(currency_type, change, amount)

# Clear all currencies
func reset_currencies():
	currencies = DEFAULT_CURRENCIES.duplicate()

# Check if has enough currency
func has_enough(currency_type: String, amount: int) -> bool:
	return get_balance(currency_type) >= amount

# ===== 저장/복원 (Save / Load) =====
# SaveSystem이 이 두 함수만 호출한다. 재화의 내부 표현은 이 시스템 밖으로 나가지 않는다.

func to_save_dict() -> Dictionary:
	return get_all_currencies()

func from_save_dict(data: Dictionary) -> void:
	for currency_type in data:
		set_currency(currency_type, int(data[currency_type]))

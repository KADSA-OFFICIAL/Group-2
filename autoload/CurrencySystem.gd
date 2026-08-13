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

# 메인화면처럼 좁은 자리에 상시 노출할 "주요 재화".
# 어떤 재화가 중요한지는 재화 도메인의 지식이므로 화면이 아니라 여기서 정한다.
# (화면마다 각자 고르면 화면끼리 목록이 어긋난다.)
#
# 위 주석의 분류를 그대로 따랐다: 통화(gold) + 특수 재화(faith_stone).
# 나머지(제작 재료)는 창고 화면에서 전부 볼 수 있다.
# 자리 제약상 최대 MAX_PRIMARY 개까지만 둔다.
const MAX_PRIMARY: int = 3
const PRIMARY_CURRENCIES := ["gold", "faith_stone"]


# 주요 재화 목록. 상한을 넘게 저작되어도 화면이 깨지지 않도록 잘라서 돌려준다.
func get_primary_currencies() -> Array:
	var out: Array = []
	for currency_type in PRIMARY_CURRENCIES:
		if DEFAULT_CURRENCIES.has(currency_type) and out.size() < MAX_PRIMARY:
			out.append(currency_type)
	return out


# 주요 재화를 뺀 나머지(창고에서 보여줄 재화).
func get_secondary_currencies() -> Array:
	var primary := get_primary_currencies()
	var out: Array = []
	for currency_type in DEFAULT_CURRENCIES:
		if not primary.has(currency_type):
			out.append(currency_type)
	return out

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

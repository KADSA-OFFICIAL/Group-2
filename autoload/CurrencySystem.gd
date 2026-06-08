extends Node

# Dictionary to store currency amounts: {"gold": 100, "diamond": 50}
var currencies: Dictionary = {}

# Signal for currency changes
signal currency_changed(currency_type: String, amount: int, new_balance: int)
signal currency_added(currency_type: String, amount: int, new_balance: int)
signal currency_subtracted(currency_type: String, amount: int, new_balance: int)

func _ready():
	name = "CurrencySystem"
	# Initialize default currencies
	if currencies.is_empty():
		currencies = {
			"gold": 0,
			"diamond": 0
		}

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
	currencies = {
		"gold": 0,
		"diamond": 0
	}

# Check if has enough currency
func has_enough(currency_type: String, amount: int) -> bool:
	return get_balance(currency_type) >= amount

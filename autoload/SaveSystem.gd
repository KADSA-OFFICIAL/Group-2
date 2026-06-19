extends Node

const SAVE_PATH = "user://game_save.json"

func _ready():
	name = "SaveSystem"

func save_game(data: Dictionary) -> bool:
	var json_string = JSON.stringify(data)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	
	if file == null:
		print("Error opening save file: ", FileAccess.get_open_error())
		return false
	
	file.store_string(json_string)
	return true

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return get_default_save()
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	
	if file == null:
		print("Error opening save file: ", FileAccess.get_open_error())
		return get_default_save()
	
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		print("Error parsing JSON: ", error)
		return get_default_save()
	
	var data = json.data as Dictionary
	
	# Load currencies to CurrencySystem if available
	if data.has("currencies") and CurrencySystem:
		for currency_type in data["currencies"]:
			CurrencySystem.set_currency(currency_type, data["currencies"][currency_type])
	
	return data

func get_default_save() -> Dictionary:
	# 재화 목록은 CurrencySystem(단일 출처)을 참조한다.
	return {
		"stage": "Stage1_1",
		"playtime": 0.0,
		"currencies": CurrencySystem.DEFAULT_CURRENCIES.duplicate()
	}

func clear_save() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		var error = DirAccess.remove_absolute(SAVE_PATH)
		if error != OK:
			print("Error deleting save file: ", error)
			return false
	return true

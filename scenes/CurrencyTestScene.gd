extends Node2D

func _ready():
	# Initialize CurrencySystem with save data
	var save_data = SaveSystem.load_game()
	if save_data.has("currencies"):
		for currency_type in save_data["currencies"]:
			CurrencySystem.set_currency(currency_type, save_data["currencies"][currency_type])
	
	# Create HUD
	var hud = Control.new()
	hud.name = "CurrencyHUD"
	add_child(hud)
	
	# Add currency display script
	var script = load("res://scenes/CurrencyHUD.gd")
	hud.set_script(script)
	
	# Create test buttons for currency testing
	var gold_add_btn = Button.new()
	gold_add_btn.text = "Add 100 Gold"
	gold_add_btn.pressed.connect(func(): CurrencySystem.add_currency("gold", 100))
	hud.add_child(gold_add_btn)
	gold_add_btn.anchor_left = 0.0
	gold_add_btn.anchor_top = 0.0
	gold_add_btn.offset_left = 20
	gold_add_btn.offset_top = 120
	gold_add_btn.custom_minimum_size = Vector2(150, 40)
	
	var gold_sub_btn = Button.new()
	gold_sub_btn.text = "Subtract 50 Gold"
	gold_sub_btn.pressed.connect(func(): CurrencySystem.subtract_currency("gold", 50))
	hud.add_child(gold_sub_btn)
	gold_sub_btn.anchor_left = 0.0
	gold_sub_btn.anchor_top = 0.0
	gold_sub_btn.offset_left = 20
	gold_sub_btn.offset_top = 170
	gold_sub_btn.custom_minimum_size = Vector2(150, 40)
	
	var save_btn = Button.new()
	save_btn.text = "Save Game"
	save_btn.pressed.connect(_on_save_game)
	hud.add_child(save_btn)
	save_btn.anchor_left = 0.0
	save_btn.anchor_top = 0.0
	save_btn.offset_left = 20
	save_btn.offset_top = 220
	save_btn.custom_minimum_size = Vector2(150, 40)

func _on_save_game():
	var save_data = SaveSystem.load_game()
	save_data["currencies"] = CurrencySystem.get_all_currencies()
	SaveSystem.save_game(save_data)
	print("Game saved! Currencies: ", CurrencySystem.get_all_currencies())

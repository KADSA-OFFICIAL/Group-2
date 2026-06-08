extends CanvasLayer
class_name HUD

var player: Player = null
var hp_label: Label
var parry_label: Label
var enemy_count_label: Label
var currency_label: Label

func _ready():
	name = "HUD"
	
	# Create labels
	hp_label = Label.new()
	parry_label = Label.new()
	enemy_count_label = Label.new()
	currency_label = Label.new()
	
	add_child(hp_label)
	add_child(parry_label)
	add_child(enemy_count_label)
	add_child(currency_label)
	
	hp_label.set_position(Vector2(10, 10))
	parry_label.set_position(Vector2(10, 30))
	enemy_count_label.set_position(Vector2(10, 50))
	currency_label.set_position(Vector2(10, 70))
	
	hp_label.add_theme_font_size_override("font_size", 14)
	parry_label.add_theme_font_size_override("font_size", 14)
	enemy_count_label.add_theme_font_size_override("font_size", 14)
	currency_label.add_theme_font_size_override("font_size", 14)
	
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		EventBus.damage_taken.connect(_on_damage_taken)
		EventBus.healing_applied.connect(_on_healing_applied)
		EventBus.parry_success.connect(_on_parry_success)
	
	# Connect to currency changes
	if CurrencySystem:
		CurrencySystem.currency_changed.connect(_on_currency_changed)

func _physics_process(_delta):
	if player and player.is_alive:
		update_hp_display()
		update_parry_display()
		update_enemy_count()
	
	update_currency_display()

func update_hp_display():
	if player:
		var hp_percent = player.get_health_percent()
		hp_label.text = "HP: %d / %d (%.0f%%)" % [player.hp, player.max_hp, hp_percent * 100]

func update_parry_display():
	if ParrySystem.is_parry_active():
		parry_label.text = "PARRY READY!"
		parry_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		parry_label.text = "Parry cooldown"
		parry_label.add_theme_color_override("font_color", Color.WHITE)

func update_enemy_count():
	var enemy_count = GameManager.get_all_enemies().size()
	enemy_count_label.text = "Enemies: %d" % enemy_count

func update_currency_display():
	if CurrencySystem:
		var gold = CurrencySystem.get_balance("gold")
		var diamond = CurrencySystem.get_balance("diamond")
		currency_label.text = "Gold: %d | Diamond: %d" % [gold, diamond]

func _on_damage_taken(_target, _damage, _position):
	# Could add floating damage text here
	pass

func _on_healing_applied(_target, _amount):
	pass

func _on_parry_success(_position):
	pass

func _on_currency_changed(_currency_type: String, _amount: int, _new_balance: int):
	update_currency_display()

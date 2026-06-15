extends CanvasLayer
class_name HUD

var player: Player = null
var hp_label: Label
var enemy_count_label: Label
var currency_label: Label

func _ready():
	name = "HUD"
	
	# Create labels
	hp_label = Label.new()
	enemy_count_label = Label.new()
	currency_label = Label.new()

	add_child(hp_label)
	add_child(enemy_count_label)
	add_child(currency_label)

	hp_label.set_position(Vector2(10, 10))
	enemy_count_label.set_position(Vector2(10, 30))
	currency_label.set_position(Vector2(10, 50))

	hp_label.add_theme_font_size_override("font_size", 14)
	enemy_count_label.add_theme_font_size_override("font_size", 14)
	currency_label.add_theme_font_size_override("font_size", 14)

	player = get_tree().get_first_node_in_group("player")

	if player:
		EventBus.damage_taken.connect(_on_damage_taken)
		EventBus.healing_applied.connect(_on_healing_applied)
	
	# Connect to currency changes
	if CurrencySystem:
		CurrencySystem.currency_changed.connect(_on_currency_changed)

func _physics_process(_delta):
	if player and player.is_alive:
		update_hp_display()
		update_enemy_count()
	
	update_currency_display()

func update_hp_display():
	if player:
		var hp_percent = player.get_health_percent()
		hp_label.text = "HP: %d / %d (%.0f%%)" % [player.hp, player.max_hp, hp_percent * 100]

func update_enemy_count():
	var enemy_count = GameManager.get_all_enemies().size()
	enemy_count_label.text = "Enemies: %d" % enemy_count

func update_currency_display():
	if CurrencySystem:
		var stone = CurrencySystem.get_balance("stone")
		var tin = CurrencySystem.get_balance("tin")
		var copper = CurrencySystem.get_balance("copper")
		var iron_ore = CurrencySystem.get_balance("iron_ore")
		var coal = CurrencySystem.get_balance("coal")
		var gold = CurrencySystem.get_balance("gold")
		var faith_stone = CurrencySystem.get_balance("faith_stone")
		currency_label.text = "Stone: %d | Tin: %d | Copper: %d | Iron: %d | Coal: %d | Gold: %d | Faith: %d" % [stone, tin, copper, iron_ore, coal, gold, faith_stone]

func _on_damage_taken(_target, _damage, _position):
	# Could add floating damage text here
	pass

func _on_healing_applied(_target, _amount):
	pass

func _on_currency_changed(_currency_type: String, _amount: int, _new_balance: int):
	update_currency_display()

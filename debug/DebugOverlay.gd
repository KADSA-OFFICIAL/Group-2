extends CanvasLayer
class_name DebugOverlay

var debug_enabled: bool = true
var debug_label = Label.new()

func _ready():
	add_child(debug_label)
	debug_label.add_theme_font_size_override("font_size", 12)
	debug_label.set_position(Vector2(10, 100))

func _physics_process(delta):
	if debug_enabled:
		update_debug_info(delta)

func update_debug_info(_delta):
	var player = get_tree().get_first_node_in_group("player")
	var text = "=== DEBUG ===\n"
	
	if player:
		text += "Player Position: %.0f, %.0f\n" % [player.global_position.x, player.global_position.y]
		text += "Player State: %s\n" % ["Alive" if player.is_alive else "Dead"]
	
	var enemies = GameManager.get_all_enemies()
	text += "Active Enemies: %d\n" % enemies.size()
	
	text += "Parry Active: %s\n" % ["Yes" if ParrySystem.is_parry_active() else "No"]
	
	debug_label.text = text

func toggle_debug():
	debug_enabled = not debug_enabled

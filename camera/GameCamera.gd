extends Camera2D
class_name GameCamera

var player: Node = null
var smoothing: float = 5.0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		global_position = player.global_position
		make_current()

func _physics_process(delta):
	if player and is_instance_valid(player):
		var target_position = player.global_position
		global_position = global_position.lerp(target_position, smoothing * delta)

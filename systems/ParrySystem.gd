extends Node
class_name ParrySystemBase

var parry_active: bool = false
var parry_window_time: float = 0.0
var parry_window_duration: float = 0.2

func _physics_process(delta):
	if parry_active:
		parry_window_time -= delta
		if parry_window_time <= 0:
			parry_active = false
			if EventBus:
				EventBus.parry_window_closed.emit()

func open_parry_window(duration: float = 0.2):
	parry_active = true
	parry_window_time = duration
	if EventBus:
		EventBus.parry_window_opened.emit()

func close_parry_window():
	parry_active = false
	if EventBus:
		EventBus.parry_window_closed.emit()

func check_parry_hit(target) -> bool:
	if not parry_active:
		if EventBus:
			EventBus.parry_failed.emit()
		return false
	
	if target and target.has_method("take_damage"):
		if EventBus:
			var target_pos = Vector2.ZERO
			if target.has_method("get_global_position"):
				target_pos = target.global_position
			EventBus.parry_success.emit(target_pos)
		return true
	
	return false

func is_parry_active() -> bool:
	return parry_active

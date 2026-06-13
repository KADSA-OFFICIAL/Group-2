extends Node

class Telegraph:
	var duration: float
	var start_time: float
	var position: Vector2
	var radius: float
	
	func _init(p_duration: float, p_position: Vector2, p_radius: float):
		duration = p_duration
		start_time = Time.get_ticks_msec() / 1000.0
		position = p_position
		radius = p_radius
	
	func get_elapsed() -> float:
		return (Time.get_ticks_msec() / 1000.0) - start_time
	
	func is_done() -> bool:
		return get_elapsed() >= duration

var active_telegraphs: Array = []

func add_telegraph(position: Vector2, radius: float, duration: float = 0.5):
	active_telegraphs.append(Telegraph.new(duration, position, radius))

func update_telegraphs():
	active_telegraphs = active_telegraphs.filter(func(t): return not t.is_done())

func get_active_telegraphs() -> Array:
	update_telegraphs()
	return active_telegraphs

func clear_telegraphs():
	active_telegraphs.clear()

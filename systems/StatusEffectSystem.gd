extends Node
class_name StatusEffectSystemBase

class StatusEffect:
	var effect_type: String
	var duration: float
	var target: Node
	var data: Dictionary = {}
	
	func _init(p_type: String, p_duration: float, p_target: Node, p_data: Dictionary = {}):
		effect_type = p_type
		duration = p_duration
		target = p_target
		data = p_data

var active_effects: Dictionary = {}

func _physics_process(delta):
	update_effects(delta)

func apply_effect(target: Node, effect_type: String, duration: float, data: Dictionary = {}):
	if not active_effects.has(target):
		active_effects[target] = []
	
	var effect = StatusEffect.new(effect_type, duration, target, data)
	active_effects[target].append(effect)
	
	if EventBus:
		EventBus.status_effect_applied.emit(target, effect_type, duration)

func remove_effect(target: Node, effect_type: String):
	if active_effects.has(target):
		active_effects[target] = active_effects[target].filter(func(e): return e.effect_type != effect_type)
		if EventBus:
			EventBus.status_effect_removed.emit(target, effect_type)

func update_effects(delta: float):
	for target in active_effects.keys():
		if not is_instance_valid(target):
			active_effects.erase(target)
			continue
		
		var effects = active_effects[target]
		var effects_to_remove = []
		
		for i in range(effects.size()):
			effects[i].duration -= delta
			if effects[i].duration <= 0:
				effects_to_remove.append(i)
		effects_to_remove.reverse()
		for i in effects_to_remove:
			var removed_effect = effects[i]
			effects.remove_at(i)
			if EventBus:
				effects.remove_at(i)
			EventBus.status_effect_removed.emit(target, removed_effect.effect_type)

func has_effect(target: Node, effect_type: String) -> bool:
	if not active_effects.has(target):
		return false
	
	for effect in active_effects[target]:
		if effect.effect_type == effect_type:
			return true
	
	return false

func get_effect_duration(target: Node, effect_type: String) -> float:
	if not active_effects.has(target):
		return 0.0
	
	for effect in active_effects[target]:
		if effect.effect_type == effect_type:
			return effect.duration
	
	return 0.0

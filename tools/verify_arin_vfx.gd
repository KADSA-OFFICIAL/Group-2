extends Node

# Headless smoke test for Arin's procedural combat VFX (#348).
# Run with: godot --headless --path . res://tools/verify_arin_vfx.tscn

const STRIKE := preload("res://entities/combat/StrikeEffect.tscn")
const CONE := preload("res://entities/combat/ConeEffect.tscn")
const KNOCKBACK := preload("res://entities/combat/KnockbackEffect.tscn")
const OVERLOAD := preload("res://entities/combat/OverloadEffect.tscn")
const TARGET_TEXTURE := preload("res://assets/sprites/placeholder/shape_enemy.svg")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node2D.new()
	get_tree().root.add_child(host)
	var target := _make_target()
	host.add_child(target)

	var strike := STRIKE.instantiate()
	host.add_child(strike)
	strike.setup(55.0, UITheme.AMBER)

	var cone := CONE.instantiate()
	host.add_child(cone)
	cone.setup(Vector2.RIGHT, 300.0, deg_to_rad(35.0), UITheme.AMBER)

	var knockback := KNOCKBACK.instantiate()
	host.add_child(knockback)
	knockback.global_position = target.global_position
	knockback.setup(target, Vector2(-10, 0), 220.0, UITheme.AMBER)

	var overload := OVERLOAD.instantiate()
	overload.setup(0.25, UITheme.AMBER)
	target.add_child(overload)

	StatusEffectSystem.apply(target, &"shock_stun", target)

	await get_tree().create_timer(0.1).timeout
	_assert(is_instance_valid(strike), "strike should survive its telegraph phase")
	_assert(is_instance_valid(cone), "cone should survive its first frame")
	_assert(target.get_node_or_null("ShockStatusEffect") != null, "shock should attach to the target")

	StatusEffectSystem.remove(target, &"shock_stun")
	await get_tree().process_frame
	await get_tree().process_frame
	_assert(target.get_node_or_null("ShockStatusEffect") == null, "shock should leave with the status")

	await get_tree().create_timer(0.8).timeout
	_assert(not is_instance_valid(strike), "strike should clean itself up")
	_assert(not is_instance_valid(cone), "cone should clean itself up")
	_assert(not is_instance_valid(knockback), "knockback trail should clean itself up")
	_assert(not is_instance_valid(overload), "overload should discharge and clean itself up")

	if _failures.is_empty():
		print("Arin VFX smoke test: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


var _failures: Array[String] = []


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _make_target() -> EnemyBase:
	var target := EnemyBase.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = TARGET_TEXTURE
	sprite.scale = Vector2(2, 2)
	target.add_child(sprite)
	return target

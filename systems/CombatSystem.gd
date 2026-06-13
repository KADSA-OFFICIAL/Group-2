extends Node
class_name CombatSystemBase

func apply_damage(target, damage: int, context: Dictionary = {}):
	if target and target.has_method("take_damage"):
		target.take_damage(damage, context.get("source", null))
		if EventBus:
			EventBus.attack_hit.emit(context.get("source", null), target, damage)

func apply_knockback(target, knockback_force: float, direction: Vector2):
	if target is CharacterBody2D:
		target.velocity += direction.normalized() * knockback_force

func check_attack_hit(attack_position: Vector2, target_position: Vector2, attack_range: float) -> bool:
	return attack_position.distance_to(target_position) <= attack_range

func apply_area_damage(area_position: Vector2, damage: int, range_distance: float, exclude_list: Array = []):
	if GameManager:
		var enemies_in_range = GameManager.get_enemies_in_range(area_position, range_distance)
		
		for enemy in enemies_in_range:
			if not exclude_list.has(enemy) and enemy and enemy.has_method("take_damage"):
				apply_damage(enemy, damage, {"source": null})

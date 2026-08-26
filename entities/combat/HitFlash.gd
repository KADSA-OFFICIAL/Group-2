extends Node
class_name HitFlash

# 피해 판정이 끝난 뒤 현재 외형의 shader uniform만 움직이는 연출 리스너(#299).
# modulate는 조종 밝기, self_modulate는 데이터 tint가 소유하므로 둘을 저장·복원하지 않는다.

const DURATION: float = 0.08
const FLASH_PARAMETER: StringName = &"flash"
const FLASH_SHADER: Shader = preload("res://entities/combat/hit_flash.gdshader")


class FlashState extends RefCounted:
	var material: ShaderMaterial
	var elapsed: float = 0.0


	func _init(p_material: ShaderMaterial) -> void:
		material = p_material


var _active: Dictionary = {}


func _ready() -> void:
	set_process(false)
	if not EventBus.damage_taken.is_connected(_on_damage_taken):
		EventBus.damage_taken.connect(_on_damage_taken)


func _exit_tree() -> void:
	if EventBus.damage_taken.is_connected(_on_damage_taken):
		EventBus.damage_taken.disconnect(_on_damage_taken)
	for raw_sprite: Variant in _active.keys():
		var state: FlashState = _active.get(raw_sprite) as FlashState
		if state != null:
			state.material.set_shader_parameter(FLASH_PARAMETER, 0.0)
	_active.clear()


func _on_damage_taken(target: Variant, _damage: int, _position: Vector2) -> void:
	var target_node: Node = target as Node
	if target_node == null or not is_instance_valid(target_node):
		return
	var sprite: CanvasItem = _visible_sprite(target_node)
	if sprite == null:
		return

	var material: ShaderMaterial = _flash_material(sprite)
	var state: FlashState = _active.get(sprite) as FlashState
	if state == null or state.material != material:
		state = FlashState.new(material)
		_active[sprite] = state
	else:
		state.elapsed = 0.0
	material.set_shader_parameter(FLASH_PARAMETER, 1.0)
	set_process(true)


func _visible_sprite(target: Node) -> CanvasItem:
	var animated_sprite: AnimatedSprite2D = target.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite != null and animated_sprite.visible:
		return animated_sprite
	var sprite: Sprite2D = target.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.visible:
		return sprite
	return null


func _flash_material(sprite: CanvasItem) -> ShaderMaterial:
	var material: ShaderMaterial = sprite.material as ShaderMaterial
	if material != null and material.shader == FLASH_SHADER:
		return material

	# 한 번 붙여 0으로 남기면 연속 피격마다 material을 교체하지 않고 시간을 다시 시작할 수 있다(#299).
	# 색 채널 갱신과 수명 경쟁도 생기지 않아 조종 전환이나 tint 재적용을 지우지 않는다.
	material = ShaderMaterial.new()
	material.shader = FLASH_SHADER
	material.set_shader_parameter(FLASH_PARAMETER, 0.0)
	sprite.material = material
	return material


func _process(delta: float) -> void:
	var finished: Array[Variant] = []
	for raw_sprite: Variant in _active.keys():
		var sprite: CanvasItem = raw_sprite as CanvasItem
		var state: FlashState = _active.get(raw_sprite) as FlashState
		if sprite == null or not is_instance_valid(sprite) or state == null:
			finished.append(raw_sprite)
			continue
		# 다른 시스템이 material을 교체했다면 새 material을 덮어쓰거나 예전 것을 복원하지 않는다(#299).
		if sprite.material != state.material:
			finished.append(raw_sprite)
			continue

		state.elapsed += delta
		var ratio: float = clampf(state.elapsed / DURATION, 0.0, 1.0)
		state.material.set_shader_parameter(FLASH_PARAMETER, 1.0 - ratio)
		if ratio >= 1.0:
			finished.append(raw_sprite)

	for raw_sprite: Variant in finished:
		_active.erase(raw_sprite)
	set_process(not _active.is_empty())

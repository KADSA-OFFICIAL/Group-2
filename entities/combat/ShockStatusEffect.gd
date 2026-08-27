extends Node2D
class_name ShockStatusEffect

# `shock_stun` 동안 적의 몸에 붙는 유지형 표시(#348).
# 지면 링을 만들지 않고, 실제 스프라이트의 불투명 픽셀을 8방향으로 복제해 1px 외곽선을 만든다.

const EFFECT_ID: StringName = &"shock_stun"
const SPARK_FRAME_TIME := 1.0 / 12.0
const OUTLINE_OFFSETS := [
	Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0),
	Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1),
]

var _target: Node = null
var _source: CanvasItem = null
var _outline: Array[Sprite2D] = []
var _source_position := Vector2.ZERO
var _elapsed := 0.0
var _half_size := Vector2(18.0, 24.0)


func _ready() -> void:
	_target = get_parent()
	_source = _visible_sprite(_target)
	if _source == null:
		queue_free()
		return
	_source_position = _source.position
	_source.position.y -= 1.0
	_half_size = _visual_half_size(_source)
	z_index = 10
	_create_outline()


func _exit_tree() -> void:
	if is_instance_valid(_source):
		_source.position = _source_position


func _process(delta: float) -> void:
	if not is_instance_valid(_target) or not StatusEffectSystem.has_effect(_target, EFFECT_ID):
		queue_free()
		return
	_elapsed += delta
	_update_outline_frames()
	queue_redraw()


func _draw() -> void:
	var frame := int(_elapsed / SPARK_FRAME_TIME)
	var points := [
		Vector2(-_half_size.x * 0.55, -_half_size.y * 0.45),
		Vector2(_half_size.x * 0.60, -_half_size.y * 0.05),
		Vector2(-_half_size.x * 0.25, _half_size.y * 0.55),
	]
	for i in points.size():
		if (frame + i) % 2 != 0:
			continue
		var point: Vector2 = points[(i + frame) % points.size()]
		draw_rect(Rect2(point, Vector2(2, 2)), UITheme.LILAC)


func _create_outline() -> void:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 outline_color : source_color;
void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	COLOR = vec4(outline_color.rgb, outline_color.a * alpha);
}
"""
	for offset in OUTLINE_OFFSETS:
		var ghost := Sprite2D.new()
		_copy_current_frame(_source, ghost)
		ghost.position = _source.position + offset
		ghost.z_as_relative = false
		ghost.z_index = _source.z_index - 1
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("outline_color", UITheme.LILAC)
		ghost.material = material
		add_child(ghost)
		_outline.append(ghost)


func _update_outline_frames() -> void:
	for i in _outline.size():
		var ghost := _outline[i]
		_copy_current_frame(_source, ghost)
		ghost.position = _source.position + OUTLINE_OFFSETS[i]


func _visible_sprite(target: Node) -> CanvasItem:
	var animated := target.get_node_or_null("AnimatedSprite2D")
	if animated is AnimatedSprite2D and animated.visible:
		return animated
	var still := target.get_node_or_null("Sprite2D")
	if still is Sprite2D and still.visible:
		return still
	return null


func _visual_half_size(source: CanvasItem) -> Vector2:
	var texture: Texture2D = null
	if source is AnimatedSprite2D:
		var animated := source as AnimatedSprite2D
		if animated.sprite_frames != null:
			texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
	elif source is Sprite2D:
		texture = (source as Sprite2D).texture
	if texture == null:
		return _half_size
	return texture.get_size() * source.scale.abs() * 0.5


func _copy_current_frame(source: CanvasItem, ghost: Sprite2D) -> void:
	if source is AnimatedSprite2D:
		var animated := source as AnimatedSprite2D
		# sprite_frames 가 빌 수 있다 — 워크 시트 없는 캐릭터의 빈 노드다(#425).
		# 근본 원인은 그 노드를 숨겨서 막지만, 여기서도 널을 만지지 않는다.
		if animated.sprite_frames == null:
			return
		ghost.texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		ghost.centered = animated.centered
		ghost.offset = animated.offset
		ghost.flip_h = animated.flip_h
		ghost.flip_v = animated.flip_v
	elif source is Sprite2D:
		var still := source as Sprite2D
		ghost.texture = still.texture
		ghost.centered = still.centered
		ghost.offset = still.offset
		ghost.flip_h = still.flip_h
		ghost.flip_v = still.flip_v
		ghost.hframes = still.hframes
		ghost.vframes = still.vframes
		ghost.frame = still.frame
		ghost.region_enabled = still.region_enabled
		ghost.region_rect = still.region_rect
	ghost.rotation = source.rotation
	ghost.scale = source.scale

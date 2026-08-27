extends Node2D
class_name KnockbackEffect

# 짧은 넉백 경로에 유령 3장을 동시에 고정하고 출발점의 먼지를 흩는다(#348).

const FRAME_TIME := 1.0 / 12.0
const FRAMES := 3
const DURATION := FRAME_TIME * FRAMES

var _elapsed := 0.0
var _direction := Vector2.RIGHT
var _color := Color.WHITE


func setup(target: Node2D, from_global: Vector2, distance: float, color: Color) -> void:
	_direction = from_global.direction_to(target.global_position)
	_color = color
	_capture_afterimages(target, distance)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _capture_afterimages(target: Node2D, distance: float) -> void:
	var source := _visible_sprite(target)
	if source == null:
		return
	var alphas := [0.60, 0.40, 0.20]
	for i in 3:
		var ghost := Sprite2D.new()
		_copy_current_frame(source, ghost)
		ghost.position += _direction * distance * float(i + 1) / 4.0
		ghost.self_modulate = Color(_color.r, _color.g, _color.b, alphas[i])
		ghost.z_index = -1
		add_child(ghost)


func _draw() -> void:
	var frame := mini(int(_elapsed / FRAME_TIME), FRAMES - 1)
	var normal := _direction.orthogonal()
	var dust := UITheme.STONE_GRAY
	dust.a = 0.75 * (1.0 - float(frame) / float(FRAMES))
	for i in 5:
		var spread := float(i - 2) * 4.0
		var back := -_direction * float(3 + frame * 5 + abs(i - 2) * 2)
		var point := back + normal * spread
		var size := 3.0 if (i + frame) % 2 == 0 else 2.0
		draw_circle(point, size, dust)


func _visible_sprite(target: Node) -> CanvasItem:
	var animated := target.get_node_or_null("AnimatedSprite2D")
	if animated is AnimatedSprite2D and animated.visible:
		return animated
	var still := target.get_node_or_null("Sprite2D")
	if still is Sprite2D and still.visible:
		return still
	return null


func _copy_current_frame(source: CanvasItem, ghost: Sprite2D) -> void:
	if source is AnimatedSprite2D:
		var animated := source as AnimatedSprite2D
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
	ghost.position = source.position
	ghost.rotation = source.rotation
	ghost.scale = source.scale

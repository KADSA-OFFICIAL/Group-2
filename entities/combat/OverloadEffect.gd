extends Node2D
class_name OverloadEffect

# 과부하의 5초 로컬 타이머 기반 연출(#348).
# 쿨다운 22초 > 지속 5초라 지속 중 재적용되지 않는다는 데이터 계약을 전제로 한다.

const FRAME_TIME := 1.0 / 12.0
const CAST_DURATION := FRAME_TIME * 3.0
const DISCHARGE_DURATION := FRAME_TIME * 3.0
const WARNING_DURATION := 2.0
const DEFAULT_DURATION := 5.0
const SPARK_POINTS := [
	Vector2(-28, -30), Vector2(31, -18), Vector2(-34, 2),
	Vector2(29, 16), Vector2(-20, 31), Vector2(18, -40),
]

var _duration := DEFAULT_DURATION
var _elapsed := 0.0
var _color := Color.WHITE
var _source: CanvasItem = null
var _glow: Sprite2D = null
var _glow_material: ShaderMaterial = null
var _source_material: Material = null
var _palette_material: ShaderMaterial = null


func setup(duration: float, color: Color) -> void:
	_duration = maxf(duration, FRAME_TIME)
	_color = color


func _ready() -> void:
	z_index = 12
	_source = _visible_sprite(get_parent())
	if _source != null:
		_apply_palette_swap()
		_create_glow()


func _exit_tree() -> void:
	if is_instance_valid(_source) and _source.material == _palette_material:
		_source.material = _source_material


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration + DISCHARGE_DURATION:
		queue_free()
		return
	_update_glow()
	queue_redraw()


func _draw() -> void:
	if _elapsed < CAST_DURATION:
		_draw_cast()
	elif _elapsed < _duration:
		_draw_active()
	else:
		_draw_discharge()


func _draw_cast() -> void:
	var frame := mini(int(_elapsed / FRAME_TIME), 2)
	if frame == 0:
		return
	var progress := float(frame) / 2.0
	var ring := UITheme.CREAM
	ring.a = 1.0 - progress * 0.45
	draw_arc(Vector2.ZERO, lerpf(18.0, 62.0, progress), 0.0, TAU, 32, ring, 2.0, false)


func _draw_active() -> void:
	var frame := int(_elapsed / FRAME_TIME)
	var time_left := _duration - _elapsed
	var spark_count := 6
	if time_left <= WARNING_DURATION:
		spark_count = 4 if time_left > 1.0 else 2

	for i in spark_count:
		if (frame + i * 2) % 3 == 2:
			continue
		var point: Vector2 = SPARK_POINTS[i]
		var spark := UITheme.CREAM if (frame + i) % 3 == 1 else _color
		if (frame + i) % 3 == 1:
			draw_line(point - Vector2(2, 0), point + Vector2(2, 0), spark, 1.0)
			draw_line(point - Vector2(0, 2), point + Vector2(0, 2), spark, 1.0)
		else:
			draw_rect(Rect2(point, Vector2.ONE * 2.0), spark)

	var aura := _color
	aura.a = 0.70 if frame % 2 == 0 else 0.38
	draw_set_transform(Vector2(0, 23), 0.0, Vector2(1.0, 0.34))
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, aura, 2.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_discharge() -> void:
	var local_time := _elapsed - _duration
	var frame := mini(int(local_time / FRAME_TIME), 2)
	var fade := 1.0 - float(frame) / 3.0
	for i in 8:
		var angle := float(i) * TAU / 8.0
		var start := Vector2.from_angle(angle) * 12.0
		var finish := Vector2.from_angle(angle) * lerpf(32.0, 58.0, float(frame + 1) / 3.0)
		var bolt := _color
		bolt.a = fade
		draw_polyline(PackedVector2Array([start, (start + finish) * 0.5 + Vector2(3, -3), finish]), bolt, 2.0, false)


func _create_glow() -> void:
	_glow = Sprite2D.new()
	_copy_current_frame(_source, _glow)
	_glow.position = _source.position
	_glow.z_as_relative = false
	_glow.z_index = _source.z_index + 1
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
render_mode blend_add;
uniform vec4 glow_color : source_color;
void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	COLOR = vec4(glow_color.rgb, glow_color.a * alpha);
}
"""
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = shader
	_glow.material = _glow_material
	add_child(_glow)


func _apply_palette_swap() -> void:
	_source_material = _source.material
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec3 hair_highlight_from;
uniform vec3 hair_highlight_to;
uniform vec3 amber_main_from;
uniform vec3 amber_main_to;
uniform vec3 amber_shadow_from;
uniform vec3 amber_shadow_to;
uniform vec3 amber_deep_from;
uniform vec3 amber_deep_to;
uniform vec3 outfit_dark_from;
uniform vec3 outfit_dark_to;
uniform vec3 outfit_shadow_from;
uniform vec3 outfit_shadow_to;

vec3 swap_exact(vec3 color, vec3 from, vec3 to) {
	return distance(color, from) < 0.012 ? to : color;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 color = tex.rgb;
	color = swap_exact(color, hair_highlight_from, hair_highlight_to);
	color = swap_exact(color, amber_main_from, amber_main_to);
	color = swap_exact(color, amber_shadow_from, amber_shadow_to);
	color = swap_exact(color, amber_deep_from, amber_deep_to);
	color = swap_exact(color, outfit_dark_from, outfit_dark_to);
	color = swap_exact(color, outfit_shadow_from, outfit_shadow_to);
	COLOR = vec4(color, tex.a) * COLOR;
}
"""
	_palette_material = ShaderMaterial.new()
	_palette_material.shader = shader
	_palette_material.set_shader_parameter("hair_highlight_from", Color("F7F3EA"))
	_palette_material.set_shader_parameter("hair_highlight_to", Color.WHITE)
	_palette_material.set_shader_parameter("amber_main_from", Color("D9B26A"))
	_palette_material.set_shader_parameter("amber_main_to", Color("F7F3EA"))
	_palette_material.set_shader_parameter("amber_shadow_from", Color("A8823F"))
	_palette_material.set_shader_parameter("amber_shadow_to", Color("D9B26A"))
	_palette_material.set_shader_parameter("amber_deep_from", Color("6E5526"))
	_palette_material.set_shader_parameter("amber_deep_to", Color("A8823F"))
	_palette_material.set_shader_parameter("outfit_dark_from", Color("3B342B"))
	_palette_material.set_shader_parameter("outfit_dark_to", Color("4A4234"))
	_palette_material.set_shader_parameter("outfit_shadow_from", Color("2E2A24"))
	_palette_material.set_shader_parameter("outfit_shadow_to", Color("3B342B"))
	_source.material = _palette_material


func _update_glow() -> void:
	if not is_instance_valid(_source) or not is_instance_valid(_glow):
		return
	_copy_current_frame(_source, _glow)
	_glow.position = _source.position
	var alpha := 0.16
	if _elapsed < FRAME_TIME:
		alpha = 0.95
	elif _elapsed >= _duration:
		alpha = 0.55 * (1.0 - (_elapsed - _duration) / DISCHARGE_DURATION)
	_glow_material.set_shader_parameter("glow_color", Color(UITheme.CREAM.r, UITheme.CREAM.g, UITheme.CREAM.b, alpha))


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
	ghost.rotation = source.rotation
	ghost.scale = source.scale

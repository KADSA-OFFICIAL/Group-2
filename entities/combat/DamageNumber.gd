extends Label
class_name DamageNumber

# 피해가 결정된 위치에서 숫자만 보여 주는 연출 노드(#297).
# 판정을 다시 묻거나 머리 위치를 계산하면 damage_taken 이 실어 온 결과와 화면이 갈라진다.

const DURATION: float = 0.55
const RISE_DISTANCE: float = 30.0
const NUMBER_SIZE := Vector2(72.0, 28.0)
const FONT_SIZE: int = 20
const FONT_EMBOLDEN: float = 0.45

var _active: bool = false
var _elapsed: float = 0.0
var _hit_position: Vector2 = Vector2.ZERO
var _spawn_order: int = 0


func _ready() -> void:
	custom_minimum_size = NUMBER_SIZE
	size = NUMBER_SIZE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", HUDKit.weight_font(FONT_EMBOLDEN))
	add_theme_font_size_override("font_size", FONT_SIZE)
	# 밝은 스프라이트에서도 숫자 색을 바꾸지 않고 읽히게 팔레트의 잉크색 테두리를 쓴다(#297).
	add_theme_color_override("font_outline_color", UITheme.INK)
	add_theme_constant_override("outline_size", 2)
	visible = false
	set_process(false)


func play(damage: int, hit_position: Vector2, color: Color, spawn_order: int) -> void:
	text = str(damage)
	add_theme_color_override("font_color", color)
	_hit_position = hit_position
	_spawn_order = spawn_order
	_elapsed = 0.0
	_active = true
	modulate.a = 1.0
	_update_position(0.0)
	visible = true
	set_process(true)


func is_active() -> bool:
	return _active


func get_spawn_order() -> int:
	return _spawn_order


func _process(delta: float) -> void:
	_elapsed += delta
	var ratio: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	_update_position(ratio)
	modulate.a = 1.0 - ratio
	if ratio >= 1.0:
		_recycle()


func _update_position(ratio: float) -> void:
	# hit position은 숫자 상자의 중심이다. 머리 기준으로 다시 놓으면 체력 바를 가린다(#297).
	global_position = _hit_position - NUMBER_SIZE * 0.5 + Vector2.UP * RISE_DISTANCE * ratio


func _recycle() -> void:
	_active = false
	visible = false
	set_process(false)

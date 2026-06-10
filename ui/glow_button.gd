## res://ui/glow_button.gd
## HTML 의 정복/출격 CTA 를 그대로 재현하는 드롭인 버튼.
## 그라데이션(주황→핑크) + 외곽 글로우 + 광택 sweep + 아이콘 + 제목/부제.

class_name GlowButton
extends Control

signal pressed

@export var text: String = "정복"
@export var subtitle: String = "CONQUEST"
@export var icon: Texture2D
@export var title_size: int = 30

var _fill: ColorRect
var _title: Label
var _hit: Button


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(220, 84)
	mouse_filter = Control.MOUSE_FILTER_PASS

	_fill = ColorRect.new()
	_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh: Shader = load("res://ui/glow_button.gdshader")
	if sh:
		mat.shader = sh
		mat.set_shader_parameter("col_a", Color("ff8a3d"))
		mat.set_shader_parameter("col_b", Color("ff4d8d"))
		_fill.material = mat
	else:
		_fill.color = Color("ff5e6e")
	add_child(_fill)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hb)

	if icon:
		var ir := TextureRect.new()
		ir.texture = icon
		ir.custom_minimum_size = Vector2(36, 36)
		ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.modulate = Color("ffffff")
		ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ir)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)

	_title = Label.new()
	_title.text = text
	_title.add_theme_font_size_override("font_size", title_size)
	_title.add_theme_color_override("font_color", Color("ffffff"))
	vb.add_child(_title)

	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.add_theme_font_size_override("font_size", 13)
		sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		vb.add_child(sub)

	_hit = Button.new()
	_hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hit.flat = true
	var empty := StyleBoxEmpty.new()
	_hit.add_theme_stylebox_override("normal", empty)
	_hit.add_theme_stylebox_override("hover", empty)
	_hit.add_theme_stylebox_override("pressed", empty)
	_hit.add_theme_stylebox_override("focus", empty)
	_hit.pressed.connect(func(): pressed.emit())
	_hit.mouse_entered.connect(func(): _animate(1.03))
	_hit.mouse_exited.connect(func(): _animate(1.0))
	add_child(_hit)

	resized.connect(_sync_size)
	_sync_size()


func _sync_size() -> void:
	pivot_offset = size * 0.5
	if _fill and _fill.material:
		(_fill.material as ShaderMaterial).set_shader_parameter("size", size)


func _animate(s: float) -> void:
	var t := create_tween().set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "scale", Vector2(s, s), 0.10)

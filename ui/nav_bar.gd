## res://ui/nav_bar.gd
## HTML 하단 네비를 재현하는 드롭인 컴포넌트: 글래스 알약 안에
## [둥근 글래스 아이콘 박스 + 라벨] 항목들. 활성=시안, 강조(가챠)=핑크.

class_name NavBar
extends PanelContainer

signal nav_selected(name: String)

var _entries: Dictionary = {}
var _active: String = ""


func setup(items: Array) -> void:
	add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 26))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	add_child(hb)
	for it in items:
		hb.add_child(_make_item(it))


func _make_item(it: Dictionary) -> Control:
	var highlight: bool = it.get("highlight", false)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(84, 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 5)

	var box := Button.new()
	box.custom_minimum_size = Vector2(64, 64)
	box.icon = load(it["icon_path"]) as Texture2D
	box.expand_icon = true
	box.add_theme_constant_override("icon_max_width", 34)
	box.add_theme_stylebox_override("normal", _box_style(false, highlight))
	box.add_theme_stylebox_override("hover", _box_style(true, highlight))
	box.add_theme_stylebox_override("pressed", _box_style(true, highlight))
	box.pressed.connect(func(): _select(it["name"]))
	col.add_child(box)

	var lbl := Label.new()
	lbl.text = it["label"]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	col.add_child(lbl)

	_entries[it["name"]] = {"box": box, "label": lbl, "highlight": highlight}
	return col


func _box_style(strong: bool, highlight: bool) -> StyleBoxFlat:
	var sb := ThemeFactory.glass_panel(strong, 16)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	if highlight:
		sb.bg_color = ThemeFactory.C_PINK
		sb.border_color = ThemeFactory.C_GOLD
	return sb


func _select(name: String) -> void:
	_active = name
	for n in _entries:
		var e: Dictionary = _entries[n]
		if n == name:
			e["box"].add_theme_stylebox_override("normal", ThemeFactory.accent_box(16))
			e["label"].add_theme_color_override("font_color", ThemeFactory.C_INK)
		else:
			e["box"].add_theme_stylebox_override("normal", _box_style(false, e["highlight"]))
			e["label"].add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	nav_selected.emit(name)


func set_active(name: String) -> void:
	_select(name)

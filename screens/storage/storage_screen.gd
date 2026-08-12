extends Control

# 창고 화면 (메타 UI).
#
# 책임: 보유한 재화를 전부 보여준다. 읽기 전용이다.
#
# 메인화면은 자리가 좁아 주요 재화만 노출한다(CurrencySystem.PRIMARY_CURRENCIES).
# 나머지 재화는 여기서 확인한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   재화 목록·분류 -> CurrencySystem (DEFAULT_CURRENCIES / get_primary_currencies /
#                     get_secondary_currencies)
#   잔액           -> CurrencySystem.get_balance()
#   색             -> UITheme
#
# 어떤 재화가 주요인지 화면에서 고르지 않는다. 재화가 추가되면 자동으로 나타난다.

const CURRENCY_ICON_PATH := "res://assets/sprites/ui/icons/icon_%s.svg"
const BACK_ICON := "res://assets/sprites/ui/icons/icon_back.svg"

# 재화 키 -> 잔액 Label. 잔액이 바뀔 때 해당 라벨만 갱신한다.
var _labels: Dictionary = {}


func _ready() -> void:
	_build()
	CurrencySystem.currency_changed.connect(_on_currency_changed)


func _build() -> void:
	add_child(UITheme.make_background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# 메인화면에 나오는 재화와 그렇지 않은 재화를 나눠 보여준다.
	# 두 목록의 출처는 CurrencySystem 이므로 화면이 분류를 따로 갖지 않는다.
	body.add_child(_build_section("주요 재화", CurrencySystem.get_primary_currencies()))
	body.add_child(_build_section("보관 재화", CurrencySystem.get_secondary_currencies()))


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var back := Button.new()
	back.text = " 뒤로"
	back.icon = _texture(BACK_ICON)
	back.custom_minimum_size = Vector2(0, 40)
	back.add_theme_stylebox_override("normal", UITheme.panel_box())
	back.add_theme_stylebox_override("hover", UITheme.panel_box())
	back.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	back.add_theme_color_override("font_color", UITheme.INK)
	back.pressed.connect(func(): ScreenManager.pop())
	row.add_child(back)

	var title := Label.new()
	title.text = "창고"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	return row


func _build_section(title: String, currency_types: Array) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.add_child(_text(title, 16, UITheme.INK_ON_DARK))

	if currency_types.is_empty():
		section.add_child(_text("없습니다.", 13, UITheme.INK_DIM))
		return section

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(grid)

	for currency_type in currency_types:
		grid.add_child(_make_currency_card(String(currency_type)))
	return section


func _make_currency_card(currency_type: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.panel_box())
	card.custom_minimum_size = Vector2(180, 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var icon := _icon(CURRENCY_ICON_PATH % currency_type, 34)
	if icon != null:
		row.add_child(icon)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)

	# 재화의 표시 이름 체계가 아직 없으므로 키를 그대로 보여준다.
	# (이름이 정해지면 CurrencySystem 쪽에 표시 이름을 두고 여기서 읽는다.)
	box.add_child(_text(currency_type, 13, UITheme.INK_DIM))

	var value := _text(_comma(CurrencySystem.get_balance(currency_type)), 18, UITheme.INK)
	box.add_child(value)
	_labels[currency_type] = value
	return card


func _on_currency_changed(currency_type: String, _amount: int, new_balance: int) -> void:
	var label: Label = _labels.get(currency_type)
	if label != null and is_instance_valid(label):
		label.text = _comma(new_balance)


# ===== 공용 조각 =====

func _text(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _icon(path: String, size: int) -> TextureRect:
	var texture := _texture(path)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func _texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _comma(value: int) -> String:
	var digits := str(value)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i != 0:
			out = "," + out
	return out

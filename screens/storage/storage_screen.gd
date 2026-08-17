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
#   색·조각        -> UITheme / HUDKit
#
# 어떤 재화가 주요인지 화면에서 고르지 않는다. 재화가 추가되면 자동으로 나타난다.

# 재화 키 -> 잔액 Label. 잔액이 바뀔 때 해당 라벨만 갱신한다.
var _labels: Dictionary = {}


func _ready() -> void:
	_build()
	CurrencySystem.currency_changed.connect(_on_currency_changed)


func _build() -> void:
	add_child(HUDKit.make_backdrop())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(HUDKit.make_header("창고", "storage", "icon_storage"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	# 메인화면에 나오는 재화와 그렇지 않은 재화를 나눠 보여준다.
	# 두 목록의 출처는 CurrencySystem 이므로 화면이 분류를 따로 갖지 않는다.
	var primary := _build_section("주요 재화", "primary", CurrencySystem.get_primary_currencies())
	var stored := _build_section("보관 재화", "stored", CurrencySystem.get_secondary_currencies())
	body.add_child(primary)
	body.add_child(stored)

	# 위에서 아래로 차례로 나타난다.
	HUDKit.play_enter([primary, stored])


func _build_section(title_ko: String, title_en: String, currency_types: Array) -> Control:
	var panel := HUDKit.make_panel(title_ko, title_en)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := HUDKit.body_of(panel)

	if currency_types.is_empty():
		body.add_child(HUDKit.label("없습니다.", 13, HUDKit.text_2()))
		return panel

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)

	for currency_type in currency_types:
		grid.add_child(_make_currency_card(String(currency_type)))
	return panel


func _make_currency_card(currency_type: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HUDKit.card())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 72)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var icon := HUDKit.make_icon(UITheme.currency_icon_name(currency_type), 36)
	if icon != null:
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)

	# 재화의 표시 이름 체계가 아직 없으므로 키를 그대로 보여준다.
	# (이름이 정해지면 CurrencySystem 쪽에 표시 이름을 두고 여기서 읽는다.)
	box.add_child(HUDKit.caption(currency_type))

	# 화면을 열 때 0에서 올라간다. 창고는 "얼마나 모았나"를 보는 곳이라 수치가 주인공이다.
	var value := HUDKit.value("", 22)
	box.add_child(value)
	HUDKit.count_up(value, CurrencySystem.get_balance(currency_type))
	_labels[currency_type] = value
	return card


func _on_currency_changed(currency_type: String, amount: int, new_balance: int) -> void:
	var label: Label = _labels.get(currency_type)
	if label != null and is_instance_valid(label):
		# 바뀐 양만큼 올라간다(0부터 다시 세면 잔액이 준 것처럼 보인다).
		HUDKit.count_up(label, new_balance, new_balance - amount)

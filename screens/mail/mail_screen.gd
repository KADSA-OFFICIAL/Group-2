extends Control

# 우편 화면 (메타 UI).
#
# 책임: 우편 목록을 보여주고 수령을 MailSystem 에 위임한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   우편 목록·수령 -> MailSystem (get_all / claim / claim_all)
#   장비 이름      -> EquipmentDatabase
#   재화           -> CurrencySystem (지급은 MailSystem 이 한다)
#   색             -> UITheme
#
# 첨부를 화면에서 지급하지 않는다. claim() 으로 시킬 뿐이다.

const BACK_ICON := "icon_back"
const MAIL_ICON := "icon_mail"

var _list_holder: VBoxContainer
var _claim_all_button: Button


func _ready() -> void:
	_build()
	_refresh()

	# 다른 경로로 우편이 들어오거나 수령돼도 표시가 따라오게 한다.
	EventBus.mail_added.connect(func(_id): _refresh())
	EventBus.mail_claimed.connect(func(_id): _refresh())


# ===== 화면 구성 =====

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
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list_holder = VBoxContainer.new()
	_list_holder.add_theme_constant_override("separation", 10)
	_list_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_holder)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var back := Button.new()
	back.text = " 뒤로"
	back.icon = _texture(BACK_ICON)
	back.expand_icon = true
	back.custom_minimum_size = Vector2(0, 40)
	back.add_theme_stylebox_override("normal", UITheme.panel_box())
	back.add_theme_stylebox_override("hover", UITheme.panel_box())
	back.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	back.add_theme_color_override("font_color", UITheme.INK)
	back.pressed.connect(func(): ScreenManager.pop())
	row.add_child(back)

	var icon := _icon(MAIL_ICON, 24)
	if icon != null:
		row.add_child(icon)

	var title := Label.new()
	title.text = "우편"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	_claim_all_button = Button.new()
	_claim_all_button.text = "모두 받기"
	_claim_all_button.custom_minimum_size = Vector2(120, 40)
	_claim_all_button.add_theme_font_size_override("font_size", 14)
	_claim_all_button.add_theme_color_override("font_color", UITheme.INK)
	_claim_all_button.pressed.connect(_on_claim_all_pressed)
	row.add_child(_claim_all_button)
	return row


# ===== 갱신 =====

func _refresh() -> void:
	if not is_instance_valid(_list_holder):
		return
	_clear(_list_holder)

	var mails := MailSystem.get_all()
	if mails.is_empty():
		_list_holder.add_child(_empty_notice())
	else:
		# 받지 않은 우편을 위로 올린다. 할 일이 먼저 보이는 편이 낫다.
		var unclaimed: Array[Dictionary] = []
		var claimed: Array[Dictionary] = []
		for mail in mails:
			if bool(mail["claimed"]):
				claimed.append(mail)
			else:
				unclaimed.append(mail)
		for mail in unclaimed:
			_list_holder.add_child(_make_mail_card(mail))
		for mail in claimed:
			_list_holder.add_child(_make_mail_card(mail))

	_refresh_claim_all()


func _refresh_claim_all() -> void:
	if not is_instance_valid(_claim_all_button):
		return
	var has := MailSystem.has_unclaimed()
	_claim_all_button.disabled = not has
	_claim_all_button.add_theme_stylebox_override("normal", UITheme.accent_box() if has else UITheme.panel_box_deep())
	_claim_all_button.add_theme_stylebox_override("hover", UITheme.accent_box() if has else UITheme.panel_box_deep())
	_claim_all_button.add_theme_stylebox_override("disabled", UITheme.panel_box_deep())


func _empty_notice() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_text("받은 우편이 없습니다.", 16, UITheme.INK))
	box.add_child(_text("보상·이벤트가 우편으로 들어오면 여기 쌓입니다.", 13, UITheme.INK_DIM))
	return panel


func _make_mail_card(mail: Dictionary) -> Control:
	var claimed := bool(mail["claimed"])

	var card := PanelContainer.new()
	# 수령한 우편은 한 톤 어둡게 두어 남은 것과 구분한다.
	card.add_theme_stylebox_override("panel", UITheme.panel_box_deep() if claimed else UITheme.panel_box())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	title_row.add_child(_text(String(mail["title"]), 16, UITheme.INK))
	if claimed:
		title_row.add_child(_text("수령 완료", 12, UITheme.INK_DIM))

	var body := String(mail["body"])
	if not body.is_empty():
		var body_label := _text(body, 13, UITheme.INK_DIM)
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(body_label)

	var attachment := _attachment_row(mail)
	if attachment != null:
		info.add_child(attachment)

	var button := Button.new()
	button.text = "받기"
	button.custom_minimum_size = Vector2(96, 44)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_stylebox_override("normal", UITheme.panel_box_deep() if claimed else UITheme.accent_box())
	button.add_theme_stylebox_override("hover", UITheme.panel_box_deep() if claimed else UITheme.accent_box())
	button.add_theme_stylebox_override("disabled", UITheme.panel_box_deep())
	button.disabled = claimed
	button.pressed.connect(_on_claim_pressed.bind(int(mail["id"])))
	row.add_child(button)
	return card


# 첨부 표시. 첨부가 없으면 null 을 돌려 줄을 만들지 않는다(빈 줄은 난잡하다).
func _attachment_row(mail: Dictionary) -> Control:
	var currencies: Dictionary = mail.get("currencies", {})
	var equipment: Dictionary = mail.get("equipment", {})
	if currencies.is_empty() and equipment.is_empty():
		return null

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	for currency_type in currencies:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		var icon := _icon(UITheme.currency_icon_name(String(currency_type)), 18)
		if icon != null:
			chip.add_child(icon)
		chip.add_child(_text("x%d" % int(currencies[currency_type]), 13, UITheme.INK))
		row.add_child(chip)

	for raw in equipment:
		# 장비 표시 이름의 출처는 EquipmentDatabase 다.
		var item := EquipmentDatabase.get_equipment(StringName(raw))
		var label := item.display_name if item != null else String(raw)
		row.add_child(_text("%s x%d" % [label, int(equipment[raw])], 13, UITheme.INK))

	return row


# ===== 조작 =====

func _on_claim_pressed(mail_id: int) -> void:
	MailSystem.claim(mail_id)


func _on_claim_all_pressed() -> void:
	MailSystem.claim_all()


# ===== 공용 조각 =====

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _text(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _icon(icon_name: String, size: int) -> TextureRect:
	var texture := _texture(icon_name)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


# 아이콘 **이름**("icon_back")을 받는다. 경로와 확장자 해석은 UITheme 이 한다.
func _texture(icon_name: String) -> Texture2D:
	var path := UITheme.icon_path(icon_name)
	if path.is_empty():
		return null
	return load(path) as Texture2D

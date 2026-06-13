## res://screens/mail/mail.gd
## 우편함 화면 — 수령/전체 수령. 모든 UI 는 _ready() 에서 코드로 생성한다.

extends Control

var _list_root: VBoxContainer
var _empty_label: Label

var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_build_ui()
	_rebuild_list()


# ── UI 빌드 ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# 상단바
	root.add_child(_make_topbar())

	# 스크롤 영역
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 16)
	scroll_margin.add_theme_constant_override("margin_right", 16)
	scroll_margin.add_theme_constant_override("margin_top", 8)
	scroll_margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(scroll_margin)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 0)
	scroll_margin.add_child(inner)

	# 빈 상태 레이블
	_empty_label = Label.new()
	_empty_label.text = "우편함이 비어있어"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 18)
	_empty_label.add_theme_color_override("font_color", Color(ThemeFactory.C_INK, 0.45))
	_empty_label.visible = false
	_empty_label.custom_minimum_size = Vector2(0, 120)
	inner.add_child(_empty_label)

	_list_root = VBoxContainer.new()
	_list_root.add_theme_constant_override("separation", 10)
	_list_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_list_root)

	# 토스트
	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -240.0
	_toast_label.offset_top = -24.0
	_toast_label.offset_right = 240.0
	_toast_label.offset_bottom = 24.0
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 15)
	_toast_label.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	_toast_label.visible = false
	add_child(_toast_label)


func _make_topbar() -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_right", 12)
	mc.add_theme_constant_override("margin_top", 10)
	mc.add_theme_constant_override("margin_bottom", 10)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	mc.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "← 뒤로"
	back_btn.pressed.connect(func(): ScreenManager.pop())
	hbox.add_child(back_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var title := Label.new()
	title.text = "우편함"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ThemeFactory.C_INK)
	hbox.add_child(title)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer2)

	var claim_all_btn := Button.new()
	claim_all_btn.text = "전체 수령"
	claim_all_btn.add_theme_stylebox_override("normal",  ThemeFactory.accent_box(12))
	claim_all_btn.add_theme_stylebox_override("hover",   ThemeFactory.accent_box(12))
	claim_all_btn.add_theme_stylebox_override("pressed", ThemeFactory.accent_box(12))
	claim_all_btn.add_theme_color_override("font_color", ThemeFactory.C_BG0)
	claim_all_btn.pressed.connect(_on_claim_all)
	hbox.add_child(claim_all_btn)

	return mc


# ── 리스트 빌드 ──────────────────────────────────────────────────────────
func _rebuild_list() -> void:
	for child in _list_root.get_children():
		child.queue_free()

	var all_claimed := true
	for mail in GameData.mails:
		if not bool(mail.get("claimed", false)):
			all_claimed = false
		var row := _make_mail_row(mail)
		_list_root.add_child(row)

	_empty_label.visible = all_claimed


func _make_mail_row(mail: Dictionary) -> PanelContainer:
	var claimed: bool = bool(mail.get("claimed", false))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 16))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if claimed:
		panel.modulate = Color(1, 1, 1, 0.5)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# 아이콘
	var icon_lbl := Label.new()
	icon_lbl.text = "✅" if claimed else "✉"
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.custom_minimum_size = Vector2(40, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	# 정보 영역
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vbox)

	var title_lbl := Label.new()
	title_lbl.text = str(mail.get("tt", ""))
	title_lbl.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(title_lbl)

	var from_lbl := Label.new()
	from_lbl.text = "from: %s" % str(mail.get("from", ""))
	from_lbl.add_theme_font_size_override("font_size", 12)
	from_lbl.add_theme_color_override("font_color", Color(ThemeFactory.C_INK, 0.6))
	info_vbox.add_child(from_lbl)

	var days_lbl := Label.new()
	days_lbl.text = "%d일 후 소멸" % int(mail.get("days", 0))
	days_lbl.add_theme_font_size_override("font_size", 12)
	days_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	info_vbox.add_child(days_lbl)

	# 보상 칩들
	var rw_array: Array = mail.get("rw", [])
	if not rw_array.is_empty():
		var rw_row := HBoxContainer.new()
		rw_row.add_theme_constant_override("separation", 4)
		info_vbox.add_child(rw_row)
		for rw in rw_array:
			rw_row.add_child(_make_rw_chip(rw))

	# 수령 버튼
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(80, 36)
	if claimed:
		btn.text = "수령 완료"
		btn.disabled = true
	else:
		btn.text = "수령"
		btn.disabled = false
		btn.add_theme_stylebox_override("normal",  ThemeFactory.accent_box(12))
		btn.add_theme_stylebox_override("hover",   ThemeFactory.accent_box(12))
		btn.add_theme_stylebox_override("pressed", ThemeFactory.accent_box(12))
		btn.add_theme_color_override("font_color", ThemeFactory.C_BG0)
	btn.pressed.connect(_on_claim_mail.bind(mail))
	hbox.add_child(btn)

	return panel


func _make_rw_chip(rw: Dictionary) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 20))

	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	var k: String = str(rw.get("k", ""))
	var a: int = int(rw.get("a", 0))
	match k:
		"gems":
			lbl.text = "💎×%d" % a
			lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
		"gold":
			lbl.text = "🪙×%s" % _comma(a)
			lbl.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
		"stamina":
			lbl.text = "⚡×%d" % a
			lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		"faction_token":
			lbl.text = "🔮×%d" % a
			lbl.add_theme_color_override("font_color", ThemeFactory.C_PINK)
		_:
			lbl.text = "%s×%d" % [k, a]
	chip.add_child(lbl)
	return chip


# ── 수령 처리 ─────────────────────────────────────────────────────────────
func _on_claim_mail(mail: Dictionary) -> void:
	if bool(mail.get("claimed", false)):
		return
	mail["claimed"] = true
	var rw_array: Array = mail.get("rw", [])
	for rw in rw_array:
		GameData.add_currency(str(rw.get("k", "")), int(rw.get("a", 0)))
	var tt: String = str(mail.get("tt", "우편"))
	_toast("'%s' 수령 완료!" % tt)
	_rebuild_list()


func _on_claim_all() -> void:
	var count := 0
	for mail in GameData.mails:
		if bool(mail.get("claimed", false)):
			continue
		mail["claimed"] = true
		var rw_array: Array = mail.get("rw", [])
		for rw in rw_array:
			GameData.add_currency(str(rw.get("k", "")), int(rw.get("a", 0)))
		count += 1
	if count > 0:
		_toast("전체 수령 완료 (%d통)" % count)
	else:
		_toast("수령할 우편이 없어")
	_rebuild_list()


# ── 유틸 ─────────────────────────────────────────────────────────────────
func _comma(v: int) -> String:
	var s := str(v)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i != 0:
			out = "," + out
	return out


func _toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.visible = true
	if _toast_timer and _toast_timer.timeout.is_connected(_hide_toast):
		_toast_timer.timeout.disconnect(_hide_toast)
	_toast_timer = get_tree().create_timer(1.8)
	_toast_timer.timeout.connect(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false

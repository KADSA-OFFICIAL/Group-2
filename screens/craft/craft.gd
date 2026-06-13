## res://screens/craft/craft.gd
## 제조소 화면 — 레시피 목록, 재료 확인, 결과 적용, 제조 큐. 모든 UI 는 _ready() 에서 코드로 생성한다.

extends Control

# ── 레시피 정의 ───────────────────────────────────────────────────────────
const RECIPES = [
	{id="c1", nm="고급 강화서",  ic="📗", cost={book=5,  dust=20}, out="book2",   qty=1},
	{id="c2", nm="정제 마정석",  ic="💎", cost={ore=10,  dust=15}, out="gems",    qty=50},
	{id="c3", nm="무작위 조각",  ic="🧩", cost={book=3,  ore=3},   out="shards",  qty=10, target_roster=true},
	{id="c4", nm="기력 회복제",  ic="⚡", cost={dust=30},          out="stamina", qty=60},
]

# ── 런타임 ────────────────────────────────────────────────────────────────
var _mat_labels: Dictionary = {}   # key → Label
var _queue_row: HBoxContainer

var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_build_ui()


# ── UI 빌드 ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_make_topbar())

	# 재료 표시 행
	var mats_margin := MarginContainer.new()
	mats_margin.add_theme_constant_override("margin_left", 16)
	mats_margin.add_theme_constant_override("margin_right", 16)
	mats_margin.add_theme_constant_override("margin_top", 8)
	mats_margin.add_theme_constant_override("margin_bottom", 4)
	mats_margin.add_child(_make_mats_row())
	root.add_child(mats_margin)

	# 스크롤
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

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll_margin.add_child(content)

	# 레시피 카드들
	for recipe in RECIPES:
		content.add_child(_make_recipe_card(recipe))

	# 제조 큐
	content.add_child(_make_queue_section())

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
	title.text = "제조소"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ThemeFactory.C_INK)
	hbox.add_child(title)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer2)

	return mc


# ── 재료 표시 행 ─────────────────────────────────────────────────────────
func _make_mats_row() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 16))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	var mat_defs := [
		{key="book",  icon="📘", name="강화서"},
		{key="ore",   icon="🔩", name="마정석"},
		{key="dust",  icon="💨", name="분진"},
		{key="book2", icon="📗", name="상급강화서"},
	]

	for md in mat_defs:
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(vbox)

		var icon_lbl := Label.new()
		icon_lbl.text = str(md.get("icon", ""))
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 22)
		vbox.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(md.get("name", ""))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(ThemeFactory.C_INK, 0.65))
		vbox.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = str(GameData.mats.get(str(md.get("key", "")), 0))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 16)
		val_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		vbox.add_child(val_lbl)

		_mat_labels[str(md.get("key", ""))] = val_lbl

	return panel


# ── 레시피 카드 ──────────────────────────────────────────────────────────
func _make_recipe_card(recipe: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 16))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	# 아이콘
	var icon_lbl := Label.new()
	icon_lbl.text = str(recipe.get("ic", ""))
	icon_lbl.add_theme_font_size_override("font_size", 36)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.custom_minimum_size = Vector2(48, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	# 정보
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	var nm_lbl := Label.new()
	nm_lbl.text = str(recipe.get("nm", ""))
	nm_lbl.add_theme_font_size_override("font_size", 16)
	info.add_child(nm_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "재료: %s" % _cost_text(recipe.get("cost", {}))
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Color(ThemeFactory.C_INK, 0.7))
	info.add_child(cost_lbl)

	var out_lbl := Label.new()
	var out_str := _out_text(recipe)
	out_lbl.text = "결과: %s" % out_str
	out_lbl.add_theme_font_size_override("font_size", 13)
	out_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	info.add_child(out_lbl)

	# 제조 버튼
	var btn := Button.new()
	btn.text = "제조"
	btn.custom_minimum_size = Vector2(70, 42)
	btn.add_theme_stylebox_override("normal",  ThemeFactory.accent_box(12))
	btn.add_theme_stylebox_override("hover",   ThemeFactory.accent_box(12))
	btn.add_theme_stylebox_override("pressed", ThemeFactory.accent_box(12))
	btn.add_theme_color_override("font_color", ThemeFactory.C_BG0)
	btn.pressed.connect(_on_craft.bind(recipe))
	hbox.add_child(btn)

	return panel


# ── 제조 큐 섹션 ─────────────────────────────────────────────────────────
func _make_queue_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := Label.new()
	header.text = "최근 제조"
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(ThemeFactory.C_INK, 0.75))
	section.add_child(header)

	_queue_row = HBoxContainer.new()
	_queue_row.add_theme_constant_override("separation", 8)
	_queue_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(_queue_row)

	_refresh_queue_row()
	return section


func _refresh_queue_row() -> void:
	for child in _queue_row.get_children():
		child.queue_free()

	if GameData.craft_queue.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "제조 기록 없음"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(ThemeFactory.C_INK, 0.4))
		_queue_row.add_child(empty_lbl)
		return

	var last3 := GameData.craft_queue.slice(maxi(0, GameData.craft_queue.size() - 3))
	for entry in last3:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 20))
		var lbl := Label.new()
		lbl.text = str(entry)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		chip.add_child(lbl)
		_queue_row.add_child(chip)


# ── 제조 처리 ─────────────────────────────────────────────────────────────
func _on_craft(recipe: Dictionary) -> void:
	var cost: Dictionary = recipe.get("cost", {})

	# 재료 검사
	for mat_key in cost:
		var required: int = int(cost[mat_key])
		var have: int = int(GameData.mats.get(mat_key, 0))
		if have < required:
			_toast("재료 부족 (%s: %d/%d)" % [mat_key, have, required])
			return

	# 재료 차감
	for mat_key in cost:
		GameData.mats[mat_key] = int(GameData.mats.get(mat_key, 0)) - int(cost[mat_key])

	# 결과 적용
	var out: String = str(recipe.get("out", ""))
	var qty: int = int(recipe.get("qty", 1))
	var nm: String = str(recipe.get("nm", ""))
	var toast_msg := ""

	match out:
		"book2":
			GameData.mats["book2"] = int(GameData.mats.get("book2", 0)) + qty
			toast_msg = "%s 제조 완료!" % nm
		"gems":
			GameData.add_currency("gems", qty)
			toast_msg = "%s 제조 완료! (💎+%d)" % [nm, qty]
		"stamina":
			GameData.add_currency("stamina", qty)
			toast_msg = "%s 제조 완료! (⚡+%d)" % [nm, qty]
		"shards":
			# 무작위 캐릭터 선택
			if GameData.roster.is_empty():
				toast_msg = "%s 제조 완료!" % nm
			else:
				var rng := RandomNumberGenerator.new()
				rng.randomize()
				var idx := rng.randi_range(0, GameData.roster.size() - 1)
				var char_entry: Dictionary = GameData.roster[idx]
				var char_entry_mut := char_entry
				char_entry_mut["shards"] = int(char_entry_mut.get("shards", 0)) + qty
				GameData.roster[idx] = char_entry_mut
				toast_msg = "%s 조각 +%d" % [str(char_entry.get("n", "???")), qty]
		_:
			toast_msg = "%s 제조 완료!" % nm

	# 스탯 및 큐 업데이트
	GameData.stats["crafts"] = int(GameData.stats.get("crafts", 0)) + 1
	GameData.craft_queue.append(nm)

	_refresh_mat_labels()
	_refresh_queue_row()
	_toast(toast_msg)


# ── 유틸 ─────────────────────────────────────────────────────────────────
func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for k in cost:
		var icon := _mat_icon(k)
		parts.append("%s%d" % [icon, int(cost[k])])
	return "  ".join(parts)


func _out_text(recipe: Dictionary) -> String:
	var out: String = str(recipe.get("out", ""))
	var qty: int = int(recipe.get("qty", 1))
	if out == "shards":
		return "조각×%d (무작위)" % qty
	var icon := _out_icon(out)
	return "%s%s×%d" % [icon, out, qty]


func _mat_icon(key: String) -> String:
	match key:
		"book":  return "📘"
		"ore":   return "🔩"
		"dust":  return "💨"
		"book2": return "📗"
	return ""


func _out_icon(out: String) -> String:
	match out:
		"book2":   return "📗"
		"gems":    return "💎"
		"stamina": return "⚡"
		"shards":  return "🧩"
	return ""


func _refresh_mat_labels() -> void:
	for key in _mat_labels:
		var lbl: Label = _mat_labels[key] as Label
		if lbl:
			lbl.text = str(GameData.mats.get(key, 0))


func _toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.visible = true
	if _toast_timer and _toast_timer.timeout.is_connected(_hide_toast):
		_toast_timer.timeout.disconnect(_hide_toast)
	_toast_timer = get_tree().create_timer(1.8)
	_toast_timer.timeout.connect(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false

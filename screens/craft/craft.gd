## res://screens/craft/craft.gd
## 제조소 화면. HTML screenCraft 대응 — 레시피 4종, 최대 2슬롯 큐, 실시간 타이머.

extends Control

const RECIPES = [
	{id="c1", ic="🧩", nm="조각 정제",  sec=15,
	 needs={ore=5, gold=50000},          out="shard",   qty=10},
	{id="c2", ic="📕", nm="상급 강화서", sec=8,
	 needs={book=3},                     out="book2",   qty=1},
	{id="c3", ic="⚗️", nm="전투력 영약", sec=12,
	 needs={book2=1, ore=2, gold=200000}, out="pw",     qty=300},
	{id="c4", ic="⚡", nm="기력 물약",  sec=6,
	 needs={dust=20},                    out="stamina", qty=60},
]

const MAX_QUEUE := 2

var _mat_labels: Dictionary = {}
var _queue_vbox: VBoxContainer
var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)
	_build_ui()


func _process(_delta: float) -> void:
	_refresh_queue_display()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_make_topbar())

	var mats_margin := MarginContainer.new()
	mats_margin.add_theme_constant_override("margin_left", 16)
	mats_margin.add_theme_constant_override("margin_right", 16)
	mats_margin.add_theme_constant_override("margin_top", 8)
	mats_margin.add_theme_constant_override("margin_bottom", 4)
	mats_margin.add_child(_make_mats_row())
	root.add_child(mats_margin)

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

	for recipe in RECIPES:
		content.add_child(_make_recipe_card(recipe))

	var q_header := Label.new()
	q_header.text = "제조 큐 (%d/%d 슬롯)" % [GameData.craft_queue.size(), MAX_QUEUE]
	q_header.name = "QueueHeader"
	q_header.add_theme_font_size_override("font_size", 15)
	q_header.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	content.add_child(q_header)

	_queue_vbox = VBoxContainer.new()
	_queue_vbox.add_theme_constant_override("separation", 8)
	_queue_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_queue_vbox)
	_refresh_queue_display()

	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -240.0; _toast_label.offset_top = -24.0
	_toast_label.offset_right = 240.0; _toast_label.offset_bottom = 24.0
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


func _make_mats_row() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 16))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var mat_defs := [
		{key="book",  icon="📘", name="강화서"},
		{key="ore",   icon="🔮", name="마정석"},
		{key="dust",  icon="✨", name="별가루"},
		{key="book2", icon="📕", name="상급강화서"},
		{key="gold",  icon="🪙", name="골드"},
	]

	for md in mat_defs:
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(vbox)

		var icon_lbl := Label.new()
		icon_lbl.text = str(md.get("icon", ""))
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 20)
		vbox.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(md.get("name", ""))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
		vbox.add_child(name_lbl)

		var val_lbl := Label.new()
		var k: String = str(md.get("key", ""))
		if k == "gold":
			val_lbl.text = _comma(GameData.gold)
		else:
			val_lbl.text = str(GameData.mats.get(k, 0))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 14)
		val_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		vbox.add_child(val_lbl)

		_mat_labels[k] = val_lbl

	return panel


func _make_recipe_card(recipe: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 16))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = str(recipe.get("ic", ""))
	icon_lbl.add_theme_font_size_override("font_size", 36)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.custom_minimum_size = Vector2(48, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	var nm_lbl := Label.new()
	nm_lbl.text = str(recipe.get("nm", ""))
	nm_lbl.add_theme_font_size_override("font_size", 16)
	info.add_child(nm_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "재료: %s" % _needs_text(recipe.get("needs", {}))
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	info.add_child(cost_lbl)

	var out_lbl := Label.new()
	out_lbl.text = "결과: %s  (%ds)" % [_out_text(recipe), recipe.get("sec", 0)]
	out_lbl.add_theme_font_size_override("font_size", 13)
	out_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	info.add_child(out_lbl)

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


func _refresh_queue_display() -> void:
	if not is_instance_valid(_queue_vbox):
		return
	for c in _queue_vbox.get_children():
		c.queue_free()

	var now_ms: int = Time.get_ticks_msec()
	var alive: Array = []
	for entry in GameData.craft_queue:
		if entry is Dictionary:
			alive.append(entry)

	if alive.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "제조 큐가 비어 있어"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_FAINT)
		_queue_vbox.add_child(empty_lbl)
		return

	for i in alive.size():
		var entry: Dictionary = alive[i]
		var done_at: int = int(entry.get("done_at", 0))
		var total_ms: int = int(entry.get("total_ms", 1))
		var remaining_ms: int = maxi(0, done_at - now_ms)
		var is_done: bool = remaining_ms <= 0

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_queue_vbox.add_child(row)

		var ic_lbl := Label.new()
		ic_lbl.text = str(entry.get("ic", ""))
		ic_lbl.add_theme_font_size_override("font_size", 22)
		row.add_child(ic_lbl)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var nm_lbl := Label.new()
		nm_lbl.text = str(entry.get("nm", ""))
		nm_lbl.add_theme_font_size_override("font_size", 13)
		info.add_child(nm_lbl)

		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = total_ms
		bar.value = total_ms - remaining_ms
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		info.add_child(bar)

		var time_lbl := Label.new()
		if is_done:
			time_lbl.text = "완료!"
			time_lbl.add_theme_color_override("font_color", ThemeFactory.C_GOOD)
		else:
			time_lbl.text = "%.1fs 남음" % (remaining_ms / 1000.0)
			time_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		time_lbl.add_theme_font_size_override("font_size", 11)
		info.add_child(time_lbl)

		if is_done:
			var collect_btn := Button.new()
			collect_btn.text = "수령"
			collect_btn.add_theme_stylebox_override("normal", ThemeFactory.accent_box(12))
			collect_btn.add_theme_stylebox_override("hover",  ThemeFactory.accent_box(12))
			collect_btn.add_theme_color_override("font_color", ThemeFactory.C_BG0)
			collect_btn.pressed.connect(_on_collect.bind(i))
			row.add_child(collect_btn)


func _on_craft(recipe: Dictionary) -> void:
	if GameData.craft_queue.size() >= MAX_QUEUE:
		_toast("제조 슬롯이 가득 찼어 (%d/%d)" % [GameData.craft_queue.size(), MAX_QUEUE])
		return

	var needs: Dictionary = recipe.get("needs", {})

	for k in needs:
		var required: int = int(needs[k])
		var have: int
		if k == "gold":
			have = GameData.gold
		else:
			have = int(GameData.mats.get(k, 0))
		if have < required:
			_toast("재료 부족 (%s: %d/%d)" % [k, have, required])
			return

	for k in needs:
		if k == "gold":
			GameData.gold -= int(needs[k])
		else:
			GameData.mats[k] = int(GameData.mats.get(k, 0)) - int(needs[k])

	var sec: int = int(recipe.get("sec", 1))
	var entry := {
		"id":       str(recipe.get("id", "")),
		"ic":       str(recipe.get("ic", "")),
		"nm":       str(recipe.get("nm", "")),
		"out":      str(recipe.get("out", "")),
		"qty":      int(recipe.get("qty", 1)),
		"done_at":  Time.get_ticks_msec() + sec * 1000,
		"total_ms": sec * 1000,
	}
	GameData.craft_queue.append(entry)
	GameData.stats["crafts"] = int(GameData.stats.get("crafts", 0)) + 1

	_refresh_mat_labels()
	_toast("제조 시작! (%ds)" % sec)


func _on_collect(queue_index: int) -> void:
	if queue_index >= GameData.craft_queue.size():
		return
	var entry: Dictionary = GameData.craft_queue[queue_index]
	var now_ms: int = Time.get_ticks_msec()
	if int(entry.get("done_at", 0)) > now_ms:
		return

	GameData.craft_queue.remove_at(queue_index)

	var out: String = str(entry.get("out", ""))
	var qty: int = int(entry.get("qty", 1))
	var nm: String = str(entry.get("nm", ""))
	var toast_msg := ""

	match out:
		"book2":
			GameData.mats["book2"] = int(GameData.mats.get("book2", 0)) + qty
			toast_msg = "%s 수령! (📕+%d)" % [nm, qty]
		"stamina":
			GameData.add_currency("stamina", qty)
			toast_msg = "%s 수령! (⚡+%d)" % [nm, qty]
		"shard":
			if GameData.roster.size() > 0:
				var idx := randi() % GameData.roster.size()
				var char_nm: String = GameData.roster[idx].get("n", "?")
				GameData.roster[idx]["shards"] = GameData.roster[idx].get("shards", 0) + qty
				toast_msg = "%s 조각 +%d" % [char_nm, qty]
			else:
				toast_msg = "%s 수령!" % nm
		"pw":
			if GameData.roster.size() > 0:
				var idx := randi() % GameData.roster.size()
				var char_nm: String = GameData.roster[idx].get("n", "?")
				var old_pw: int = int(GameData.roster[idx].get("pw", 0))
				GameData.roster[idx]["pw"] = old_pw + qty
				toast_msg = "%s 전투력 +%d" % [char_nm, qty]
			else:
				toast_msg = "%s 수령!" % nm
		_:
			toast_msg = "%s 수령!" % nm

	_refresh_mat_labels()
	_toast(toast_msg)


func _needs_text(needs: Dictionary) -> String:
	var parts: Array[String] = []
	for k in needs:
		var icon := _mat_icon(k)
		var v: int = int(needs[k])
		if k == "gold":
			parts.append("%s%s" % [icon, _comma(v)])
		else:
			parts.append("%s%d" % [icon, v])
	return "  ".join(parts)


func _out_text(recipe: Dictionary) -> String:
	match str(recipe.get("out", "")):
		"shard":   return "조각 +%d (무작위)" % recipe.get("qty", 0)
		"book2":   return "📕 상급 강화서 +%d" % recipe.get("qty", 0)
		"stamina": return "⚡ 기력 +%d" % recipe.get("qty", 0)
		"pw":      return "⚔ 전투력 +%d (무작위)" % recipe.get("qty", 0)
	return str(recipe.get("out", ""))


func _mat_icon(key: String) -> String:
	match key:
		"book":  return "📘"
		"ore":   return "🔮"
		"dust":  return "✨"
		"book2": return "📕"
		"gold":  return "🪙"
	return ""


func _refresh_mat_labels() -> void:
	for key in _mat_labels:
		var lbl: Label = _mat_labels[key] as Label
		if lbl:
			if key == "gold":
				lbl.text = _comma(GameData.gold)
			else:
				lbl.text = str(GameData.mats.get(key, 0))


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

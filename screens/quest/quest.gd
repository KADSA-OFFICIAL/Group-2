## res://screens/quest/quest.gd
## 퀘스트(튜토리얼 체인) 화면. 순차 잠금 해제 방식.

extends Control

const QUESTS = [
	{id = "q1",  nm = "첫 출석",           cond_desc = "출석 화면에서 오늘의 보상을 받자",            rw = {k = "gems",  a = 50}},
	{id = "q2",  nm = "우편 정리",          cond_desc = "우편함에서 보상을 1통 이상 수령",             rw = {k = "gold",  a = 100000}},
	{id = "q3",  nm = "첫 모집",            cond_desc = "모집에서 새 캐릭터를 뽑아보자 (1회)",          rw = {k = "gems",  a = 100}},
	{id = "q4",  nm = "단련 시작",          cond_desc = "캐릭터를 1회 레벨업",                        rw = {k = "gold",  a = 100000}},
	{id = "q5",  nm = "첫 사냥",            cond_desc = "정복 → 편성 → 전투에서 1회 승리",             rw = {k = "gems",  a = 100}},
	{id = "q6",  nm = "공방 가동",          cond_desc = "제조에서 아무 레시피나 1회 제조 시작",         rw = {k = "gold",  a = 150000}},
	{id = "q7",  nm = "교단 인사",          cond_desc = "교단에서 출석 체크 (토큰 획득)",              rw = {k = "gems",  a = 50}},
	{id = "q8",  nm = "균열 돌파",          cond_desc = "스테이지 33-9 클리어",                       rw = {k = "gems",  a = 200}},
	{id = "q9",  nm = "첫 승급",            cond_desc = "조각을 모아 캐릭터를 1회 승급 (★ 상승)",       rw = {k = "gems",  a = 150}},
	{id = "q10", nm = "새벽의 군주 토벌",   cond_desc = "챕터 보스 스테이지 33-10 클리어",             rw = {k = "gems",  a = 500}},
]

const REWARD_ICONS: Dictionary = {
	"gems": "💎", "gold": "🪙", "stamina": "⚡", "faction_token": "🔮",
}

var _progress_label: Label
var _quest_rows_vbox: VBoxContainer
var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var root_margin := MarginContainer.new()
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_margin.add_theme_constant_override("margin_left", 16)
	root_margin.add_theme_constant_override("margin_right", 16)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(root_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	root_margin.add_child(vbox)

	# ── 상단바 ──
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(top_bar)

	var back_btn := Button.new()
	back_btn.text = "← 뒤로"
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(func(): ScreenManager.pop())
	top_bar.add_child(back_btn)

	var title_label := Label.new()
	title_label.text = "퀘스트"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title_label)

	# ── 체인 이름 + 진행도 ──
	var chain_card := PanelContainer.new()
	chain_card.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 18))
	vbox.add_child(chain_card)

	var chain_vbox := VBoxContainer.new()
	chain_vbox.add_theme_constant_override("separation", 6)
	chain_card.add_child(chain_vbox)

	var chain_name := Label.new()
	chain_name.text = "별빛 수호자의 여정"
	chain_name.add_theme_font_size_override("font_size", 18)
	chain_name.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	chain_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chain_vbox.add_child(chain_name)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 15)
	_progress_label.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chain_vbox.add_child(_progress_label)

	var prog_bar := ProgressBar.new()
	prog_bar.min_value = 0
	prog_bar.max_value = QUESTS.size()
	prog_bar.show_percentage = false
	prog_bar.custom_minimum_size = Vector2(0, 12)
	chain_vbox.add_child(prog_bar)
	# prog_bar value is set in _refresh via _progress_label sibling — store reference
	# Store the bar so _refresh can update it
	prog_bar.name = "ProgressBar"

	# ── 퀘스트 목록 ──
	_quest_rows_vbox = VBoxContainer.new()
	_quest_rows_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(_quest_rows_vbox)

	# ── 토스트 ──
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -240
	_toast_label.offset_right = 240
	_toast_label.offset_top = -28
	_toast_label.offset_bottom = 28
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.visible = false
	add_child(_toast_label)

	_refresh()


func _cond_met(q: Dictionary) -> bool:
	match q.id:
		"q1":  return GameData.attend.get("day", 0) >= 1
		"q2":
			var claimed_count := 0
			for m in GameData.mails:
				if m.get("claimed", false):
					claimed_count += 1
			return claimed_count >= 1
		"q3":  return GameData.stats.get("pulls", 0) >= 1
		"q4":  return GameData.stats.get("levelups", 0) >= 1
		"q5":  return GameData.stats.get("clears", 0) >= 1
		"q6":  return GameData.stats.get("crafts", 0) >= 1
		"q7":  return GameData.guild_checked
		"q8":  return GameData.cleared >= 9
		"q9":  return GameData.stats.get("promos", 0) >= 1
		"q10": return GameData.cleared >= 10
	return false


func _refresh() -> void:
	var done_count := 0
	for q in QUESTS:
		if GameData.quest_claims.has(q.id):
			done_count += 1

	_progress_label.text = "완료: %d / %d" % [done_count, QUESTS.size()]

	# Update progress bar (accessed via chain_card's child)
	# The ProgressBar is a sibling of _progress_label inside chain_vbox -> chain_card
	var chain_card := _progress_label.get_parent().get_parent()
	var pbar := chain_card.find_child("ProgressBar", true, false) as ProgressBar
	if pbar:
		pbar.value = done_count

	_build_quests()


func _build_quests() -> void:
	for c in _quest_rows_vbox.get_children():
		c.queue_free()

	for i in QUESTS.size():
		var q: Dictionary = QUESTS[i]
		var claimed := GameData.quest_claims.has(q.id)
		var prev_claimed := (i == 0) or GameData.quest_claims.has(QUESTS[i - 1].id)
		var locked := not prev_claimed and not claimed
		var cond_ok := _cond_met(q)

		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 14))
		_quest_rows_vbox.add_child(row)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 10)
		row.add_child(row_hbox)

		# 아이콘
		var icon_lbl := Label.new()
		icon_lbl.add_theme_font_size_override("font_size", 22)
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if claimed:
			icon_lbl.text = "✅"
		elif locked:
			icon_lbl.text = "🔒"
		else:
			icon_lbl.text = "🎯"
		row_hbox.add_child(icon_lbl)

		# 정보
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 4)
		row_hbox.add_child(info_vbox)

		var name_lbl := Label.new()
		name_lbl.text = q.nm
		name_lbl.add_theme_font_size_override("font_size", 15)
		if claimed:
			name_lbl.add_theme_color_override("font_color", ThemeFactory.C_GOOD)
		elif locked:
			name_lbl.add_theme_color_override("font_color", ThemeFactory.C_LINE)
		info_vbox.add_child(name_lbl)

		var cond_lbl := Label.new()
		cond_lbl.text = "조건: %s" % q.cond_desc
		cond_lbl.add_theme_font_size_override("font_size", 12)
		cond_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		info_vbox.add_child(cond_lbl)

		var rw_lbl := Label.new()
		rw_lbl.text = "보상: %s×%s" % [REWARD_ICONS.get(q.rw.k, "?"), _comma(q.rw.a)]
		rw_lbl.add_theme_font_size_override("font_size", 12)
		rw_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
		info_vbox.add_child(rw_lbl)

		# 수령 버튼
		var claim_btn := Button.new()
		claim_btn.custom_minimum_size = Vector2(80, 0)
		claim_btn.add_theme_font_size_override("font_size", 14)
		if claimed:
			claim_btn.text = "완료"
			claim_btn.disabled = true
		elif locked:
			claim_btn.text = "🔒"
			claim_btn.disabled = true
		elif cond_ok:
			claim_btn.text = "수령"
			claim_btn.disabled = false
		else:
			claim_btn.text = "진행 중"
			claim_btn.disabled = true
		claim_btn.pressed.connect(_on_claim_quest.bind(q))
		row_hbox.add_child(claim_btn)


func _on_claim_quest(q: Dictionary) -> void:
	if GameData.quest_claims.has(q.id):
		return
	if not _cond_met(q):
		return

	GameData.quest_claims[q.id] = true
	GameData.add_currency(q.rw.k, q.rw.a)
	_toast("%s %s×%s 수령!" % [q.nm, REWARD_ICONS.get(q.rw.k, ""), _comma(q.rw.a)])
	_refresh()


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

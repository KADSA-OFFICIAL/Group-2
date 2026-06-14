## res://screens/battle/battle.gd
## 전투 화면 — 실시간 액션 게임 (HTML 프로토타입 battle section 완전 이식).
## 960×540 SubViewport 위에 Node2D._draw() 로 렌더링.

extends Control

const RESULT_SCENE := preload("res://screens/result/Result.tscn")

# ── 월드 상수 ─────────────────────────────────────────────
const W := 960
const H := 540
const WALL := 26

# ── 역할/무기 스탯 ────────────────────────────────────────
const ROLE_STATS := {
	"공격": {"hp": 160, "spd": 185},
	"방어": {"hp": 310, "spd": 140},
	"지원": {"hp": 210, "spd": 165},
}
const WEAPON_STATS := {
	"bolt":   {"dmg": 13, "rate": 0.26},
	"spread": {"dmg": 9,  "rate": 0.42},
	"melee":  {"dmg": 30, "rate": 0.62, "range": 78},
	"rapid":  {"dmg": 6,  "rate": 0.11},
	"pierce": {"dmg": 26, "rate": 0.80},
	"nova":   {"dmg": 8,  "rate": 0.90},
}

# ── 게임 상태 ─────────────────────────────────────────────
var fighters: Array = []
var active: int = 0
var px: float = W / 2.0
var py: float = H / 2.0
var face := Vector2(1, 0)
var inv: float = 0.0
var dash_cd: float = 0.0
var swap_cd: float = 0.0
var dash_vx: float = 0.0
var dash_vy: float = 0.0

var rooms: Array = []
var room_idx: int = 0
var enemies: Array = []
var bullets: Array = []
var ebullets: Array = []
var parts: Array = []
var boss = null
var portal = null
var spawn_queue: int = 0
var spawn_timer: float = 0.0
var fire_cd: float = 0.0
var over: bool = false
var won: bool = false
var esc_count: int = 0
var esc_timer: float = 0.0
var boss_attack_cd: float = 0.0

# ── 입력 ──────────────────────────────────────────────────
var move_dir := Vector2.ZERO
var aim_dir := Vector2(1, 0)
var want_fire: bool = false

# ── 노드 참조 ─────────────────────────────────────────────
var _game_world: Node2D
var _viewport: SubViewport
var _hud_layer: CanvasLayer
var _boss_bar_bg: Control
var _boss_bar_fill: Control
var _boss_name_lbl: Label
var _active_hp_fill: Control
var _active_hp_lbl: Label
var _active_name_lbl: Label
var _room_lbl: Label
var _slot_panels: Array = []
var _toast_lbl: Label
var _toast_timer: float = 0.0
var _defeat_overlay: Control = null


func _ready() -> void:
	_build_viewport()
	_build_hud()
	_start_game()


# ── 뷰포트 + 게임월드 ────────────────────────────────────
func _build_viewport() -> void:
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	add_child(svc)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(W, H)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	svc.add_child(_viewport)

	_game_world = Node2D.new()
	_game_world.name = "GameWorld"
	_viewport.add_child(_game_world)
	_game_world.draw.connect(_on_draw)


func _on_draw() -> void:
	_render(_game_world)


# ── HUD 구성 ─────────────────────────────────────────────
func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_layer.add_child(root)

	# 상단 방 정보
	var top_bar := PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 44)
	var sb := ThemeFactory.glass_panel(true, 0)
	top_bar.add_theme_stylebox_override("panel", sb)
	root.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	top_bar.add_child(top_hbox)

	var code_lbl := Label.new()
	code_lbl.text = "스테이지 %s" % GameData.battle.get("code", "?")
	code_lbl.add_theme_font_size_override("font_size", 15)
	code_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	code_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(code_lbl)

	_room_lbl = Label.new()
	_room_lbl.text = "방 1"
	_room_lbl.add_theme_font_size_override("font_size", 15)
	_room_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	top_hbox.add_child(_room_lbl)

	var exit_btn := Button.new()
	exit_btn.text = "나가기"
	exit_btn.add_theme_font_size_override("font_size", 13)
	exit_btn.pressed.connect(_on_exit)
	top_hbox.add_child(exit_btn)

	# 보스 HP 바 (숨김 상태로 시작)
	var boss_container := VBoxContainer.new()
	boss_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_container.position = Vector2(-120, 48)
	boss_container.custom_minimum_size = Vector2(240, 36)
	root.add_child(boss_container)
	_boss_bar_bg = boss_container

	_boss_name_lbl = Label.new()
	_boss_name_lbl.add_theme_font_size_override("font_size", 13)
	_boss_name_lbl.add_theme_color_override("font_color", ThemeFactory.C_PINK)
	_boss_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_container.add_child(_boss_name_lbl)

	var boss_track := PanelContainer.new()
	boss_track.custom_minimum_size = Vector2(240, 12)
	boss_container.add_child(boss_track)
	_boss_bar_fill = ColorRect.new()
	_boss_bar_fill.color = ThemeFactory.C_PINK
	_boss_bar_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_track.add_child(_boss_bar_fill)
	boss_container.visible = false

	# 하단 왼쪽: 활성 캐릭터 HP
	var hp_panel := PanelContainer.new()
	hp_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_panel.position = Vector2(8, -80)
	hp_panel.custom_minimum_size = Vector2(220, 68)
	hp_panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 10))
	root.add_child(hp_panel)

	var hp_vbox := VBoxContainer.new()
	hp_vbox.add_theme_constant_override("separation", 4)
	hp_panel.add_child(hp_vbox)

	_active_name_lbl = Label.new()
	_active_name_lbl.add_theme_font_size_override("font_size", 13)
	_active_name_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK)
	hp_vbox.add_child(_active_name_lbl)

	var hp_track := PanelContainer.new()
	hp_track.custom_minimum_size = Vector2(200, 10)
	hp_vbox.add_child(hp_track)
	_active_hp_fill = ColorRect.new()
	_active_hp_fill.color = ThemeFactory.C_GOOD
	_active_hp_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_track.add_child(_active_hp_fill)

	_active_hp_lbl = Label.new()
	_active_hp_lbl.add_theme_font_size_override("font_size", 12)
	_active_hp_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	hp_vbox.add_child(_active_hp_lbl)

	# 슬롯 (최대 5)
	var slots_hbox := HBoxContainer.new()
	slots_hbox.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	slots_hbox.position = Vector2(8, -8)
	slots_hbox.add_theme_constant_override("separation", 4)
	root.add_child(slots_hbox)
	_slot_panels = []
	for _i in 5:
		var sp := PanelContainer.new()
		sp.custom_minimum_size = Vector2(48, 0)
		sp.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 6))
		sp.visible = false
		var sv := VBoxContainer.new()
		sv.name = "VBoxContainer"
		sv.add_theme_constant_override("separation", 2)
		sp.add_child(sv)
		var sl := Label.new()
		sl.add_theme_font_size_override("font_size", 11)
		sl.add_theme_color_override("font_color", ThemeFactory.C_INK)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.name = "NameLbl"
		sv.add_child(sl)
		var sh := ColorRect.new()
		sh.custom_minimum_size = Vector2(40, 4)
		sh.color = ThemeFactory.C_GOOD
		sh.name = "HpBar"
		sv.add_child(sh)
		slots_hbox.add_child(sp)
		_slot_panels.append(sp)

	# 토스트
	_toast_lbl = Label.new()
	_toast_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_lbl.position = Vector2(-100, 60)
	_toast_lbl.custom_minimum_size = Vector2(200, 0)
	_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_lbl.add_theme_font_size_override("font_size", 16)
	_toast_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	_toast_lbl.visible = false
	root.add_child(_toast_lbl)


# ── 게임 시작 ────────────────────────────────────────────
func _start_game() -> void:
	_build_fighters()
	_build_rooms()
	px = W / 2.0
	py = H / 2.0
	over = false
	won = false
	_enter_room(0)


func _build_fighters() -> void:
	fighters.clear()
	var team_ids: Array = GameData.battle.get("team", [])
	var src: Array = []
	for cid in team_ids:
		for c in GameData.roster:
			if c.get("id", "") == str(cid):
				src.append(c)
				break
	if src.is_empty():
		src = [
			{"n": "루나", "role": "공격", "weapon": "bolt",   "lv": 60, "c1": "#ff9ad1", "c2": "#d23f8c"},
			{"n": "미라", "role": "방어", "weapon": "melee",  "lv": 57, "c1": "#b6a8ff", "c2": "#7a4fd1"},
			{"n": "세라", "role": "지원", "weapon": "spread", "lv": 58, "c1": "#7fe9ff", "c2": "#2aa9d8"},
		]
	for c in src:
		var role: String = c.get("role", "공격")
		var rs: Dictionary = ROLE_STATS.get(role, ROLE_STATS["공격"])
		var lv: int = int(c.get("lv", 50))
		var lb: float = 1.0 + lv / 130.0
		var max_hp: int = roundi(rs["hp"] * lb)
		var ws: Dictionary = WEAPON_STATS.get(c.get("weapon", "bolt"), WEAPON_STATS["bolt"])
		fighters.append({
			"n": c.get("n", "?"),
			"role": role,
			"weapon": c.get("weapon", "bolt"),
			"spd": rs["spd"],
			"max_hp": max_hp,
			"hp": float(max_hp),
			"dmg": int(ws.get("dmg", 10)),
			"rate": float(ws.get("rate", 0.3)),
			"range": float(ws.get("range", 78.0)),
			"c1": Color(c.get("c1", "#ffffff")),
			"c2": Color(c.get("c2", "#aaaaaa")),
			"down": false,
		})
	active = 0


func _build_rooms() -> void:
	rooms.clear()
	var n: int = GameData.battle.get("n", 9)
	var is_chapter_boss: bool = n >= 10
	var wave_count: int = 3 if is_chapter_boss else 2
	for i in wave_count:
		rooms.append({"type": "wave", "count": 4 + i + (n / 2)})
	rooms.append({"type": "boss", "boss": "boss" if is_chapter_boss else "mid"})


func _enter_room(idx: int) -> void:
	room_idx = idx
	enemies.clear()
	bullets.clear()
	ebullets.clear()
	parts.clear()
	boss = null
	portal = null
	fire_cd = 0.0
	boss_attack_cd = 0.0
	var r: Dictionary = rooms[idx]
	_room_lbl.text = "방 %d / %d" % [idx + 1, rooms.size()]
	if r["type"] == "wave":
		spawn_queue = int(r["count"])
		spawn_timer = 0.3
	else:
		spawn_queue = 0
		_spawn_boss(r["boss"])
	_show_boss_bar(r["type"] == "boss")
	_show_toast("방 %d 입장!" % (idx + 1))


# ── 적 스폰 ──────────────────────────────────────────────
func _spawn_enemy() -> void:
	var n: int = GameData.battle.get("n", 1)
	var roll := randf()
	var kind: String
	if roll > 0.82:
		kind = "tank"
	elif roll > 0.5:
		kind = "fast"
	else:
		kind = "basic"

	var base := {"basic": {"hp": 26, "spd": 62, "dmg": 8, "r": 13, "c": Color("c77fff")},
				 "fast":  {"hp": 16, "spd": 104, "dmg": 6, "r": 10, "c": Color("ff7fa8")},
				 "tank":  {"hp": 64, "spd": 42, "dmg": 13, "r": 18, "c": Color("7f9aff")}}
	var b: Dictionary = base[kind]
	var hp: int = roundi(b["hp"] * (1.0 + n * 0.05))

	var side := randi_range(0, 3)
	var ex: float
	var ey: float
	match side:
		0: ex = randf_range(WALL, W - WALL); ey = WALL + 1.0
		1: ex = randf_range(WALL, W - WALL); ey = H - WALL - 1.0
		2: ex = WALL + 1.0; ey = randf_range(WALL, H - WALL)
		_: ex = W - WALL - 1.0; ey = randf_range(WALL, H - WALL)

	enemies.append({
		"x": ex, "y": ey,
		"hp": float(hp), "max_hp": float(hp),
		"spd": float(b["spd"]), "dmg": int(b["dmg"]),
		"r": float(b["r"]), "c": b["c"],
		"kind": kind, "hit_cd": 0.0,
	})


func _spawn_boss(btype: String) -> void:
	var n: int = GameData.battle.get("n", 1)
	if btype == "boss":
		boss = {"x": W / 2.0, "y": WALL + 60.0,
				"hp": round(1500.0 * (1.0 + n * 0.06)),
				"max_hp": round(1500.0 * (1.0 + n * 0.06)),
				"spd": 40.0, "dmg": 22, "r": 44.0,
				"c": Color("ff5a5a"), "hit_cd": 0.0, "big": true}
		_boss_name_lbl.text = "새벽의 군주"
	else:
		boss = {"x": W / 2.0, "y": WALL + 60.0,
				"hp": round(650.0 * (1.0 + n * 0.06)),
				"max_hp": round(650.0 * (1.0 + n * 0.06)),
				"spd": 52.0, "dmg": 15, "r": 30.0,
				"c": Color("ff8a5a"), "hit_cd": 0.0, "big": false}
		_boss_name_lbl.text = "중간 보스"
	boss_attack_cd = 2.0


# ── _process ────────────────────────────────────────────
func _process(delta: float) -> void:
	if over:
		return
	_update_input()
	_update_player(delta)
	_update_bullets(delta)
	_update_enemies(delta)
	_update_boss(delta)
	_update_spawn(delta)
	_update_portal(delta)
	_update_benched_regen(delta)
	_update_hud()
	_update_toast(delta)
	_game_world.queue_redraw()


func _update_input() -> void:
	var dx: float = 0.0
	var dy: float = 0.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dx += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dx -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		dy += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		dy -= 1.0
	if dx != 0.0 or dy != 0.0:
		move_dir = Vector2(dx, dy).normalized()
	else:
		move_dir = Vector2.ZERO
	want_fire = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_J)


func _update_player(delta: float) -> void:
	if fighters.is_empty():
		return
	var f: Dictionary = fighters[active]
	var spd: float = f["spd"]

	px += move_dir.x * spd * delta + dash_vx * delta
	py += move_dir.y * spd * delta + dash_vy * delta

	# 대쉬 감속
	if abs(dash_vx) > 20.0 or abs(dash_vy) > 20.0:
		var decay := pow(0.001, delta)
		dash_vx *= decay
		dash_vy *= decay
	else:
		dash_vx = 0.0
		dash_vy = 0.0

	px = clampf(px, WALL + 14.0, W - WALL - 14.0)
	py = clampf(py, WALL + 14.0, H - WALL - 14.0)

	if inv > 0.0:
		inv -= delta
	if dash_cd > 0.0:
		dash_cd -= delta
	if swap_cd > 0.0:
		swap_cd -= delta
	if fire_cd > 0.0:
		fire_cd -= delta

	# 조준 방향 = 마우스 방향
	var mpos := get_viewport().get_mouse_position()
	# viewport 좌표 변환 (SubViewportContainer가 stretch=true이므로 비율 적용)
	var vp_size := get_viewport_rect().size
	var scale_x := float(W) / vp_size.x
	var scale_y := float(H) / vp_size.y
	var wx := mpos.x * scale_x
	var wy := mpos.y * scale_y
	var ad := Vector2(wx - px, wy - py)
	if ad.length() > 4.0:
		aim_dir = ad.normalized()
		face = aim_dir

	# 발사
	if want_fire and fire_cd <= 0.0:
		_fire(f)
		fire_cd = f["rate"]


func _fire(f: Dictionary) -> void:
	var w: String = f["weapon"]
	var dmg: int = f["dmg"]
	match w:
		"bolt":
			bullets.append(_make_bullet(px, py, aim_dir.x, aim_dir.y, dmg, 520.0, 1))
		"spread":
			for off in [-0.25, 0.0, 0.25]:
				var a := atan2(aim_dir.y, aim_dir.x) + off
				bullets.append(_make_bullet(px, py, cos(a), sin(a), dmg, 480.0, 1))
		"melee":
			_melee_hit(dmg, f["range"])
		"rapid":
			var jitter := randf_range(-0.10, 0.10)
			var a := atan2(aim_dir.y, aim_dir.x) + jitter
			bullets.append(_make_bullet(px, py, cos(a), sin(a), dmg, 560.0, 1))
		"pierce":
			bullets.append(_make_bullet(px, py, aim_dir.x, aim_dir.y, dmg, 700.0, 4))
		"nova":
			for i in 10:
				var a := TAU * i / 10.0
				bullets.append(_make_bullet(px, py, cos(a), sin(a), dmg, 420.0, 1))


func _make_bullet(bx: float, by: float, bdx: float, bdy: float, bdmg: int, bspd: float, bpierce: int) -> Dictionary:
	return {"x": bx, "y": by, "dx": bdx, "dy": bdy, "dmg": bdmg, "spd": bspd, "pierce": bpierce, "t": 0.0, "r": 5.0}


func _melee_hit(dmg: int, range_r: float) -> void:
	for e in enemies:
		var d := Vector2(e["x"] - px, e["y"] - py)
		if d.length() < range_r:
			var dot_v := d.normalized().dot(aim_dir)
			if dot_v > 0.35:
				e["hp"] -= dmg
				_add_spark(e["x"], e["y"])
	if boss != null:
		var d := Vector2(boss["x"] - px, boss["y"] - py)
		if d.length() < range_r:
			boss["hp"] -= dmg
			_add_spark(boss["x"], boss["y"])


func _update_bullets(delta: float) -> void:
	var keep: Array = []
	for b in bullets:
		b["x"] += b["dx"] * b["spd"] * delta
		b["y"] += b["dy"] * b["spd"] * delta
		b["t"] += delta
		if b["t"] > 1.0 or b["x"] < 0 or b["x"] > W or b["y"] < 0 or b["y"] > H:
			continue
		# 적 충돌
		var hit := false
		for e in enemies:
			var dx := b["x"] - e["x"]
			var dy := b["y"] - e["y"]
			if dx*dx + dy*dy < (e["r"] + b["r"]) * (e["r"] + b["r"]):
				e["hp"] -= b["dmg"]
				_add_spark(e["x"], e["y"])
				b["pierce"] -= 1
				if b["pierce"] <= 0:
					hit = true
					break
		# 보스 충돌
		if boss != null:
			var dx := b["x"] - boss["x"]
			var dy := b["y"] - boss["y"]
			if dx*dx + dy*dy < (boss["r"] + b["r"]) * (boss["r"] + b["r"]):
				boss["hp"] -= b["dmg"]
				_add_spark(boss["x"], boss["y"])
				b["pierce"] -= 1
				if b["pierce"] <= 0:
					hit = true
		if not hit:
			keep.append(b)
	bullets = keep

	# 적 총알 이동
	var ekeep: Array = []
	for eb in ebullets:
		eb["x"] += eb["dx"] * eb["spd"] * delta
		eb["y"] += eb["dy"] * eb["spd"] * delta
		eb["t"] += delta
		if eb["t"] > 2.0 or eb["x"] < 0 or eb["x"] > W or eb["y"] < 0 or eb["y"] > H:
			continue
		var dx := eb["x"] - px
		var dy := eb["y"] - py
		if dx*dx + dy*dy < (12 + eb["r"]) * (12 + eb["r"]):
			_hit_player(int(eb["dmg"]))
			continue
		ekeep.append(eb)
	ebullets = ekeep

	# 죽은 적 제거
	var prev_count: int = enemies.size()
	var eresult: Array = []
	for e in enemies:
		if e["hp"] > 0:
			eresult.append(e)
		else:
			_add_spark(e["x"], e["y"])
	enemies = eresult
	if enemies.size() < prev_count:
		_check_room_clear()

	# 파티클 업데이트
	var presult: Array = []
	for p in parts:
		p["t"] -= delta
		if p["t"] > 0:
			presult.append(p)
	parts = presult


func _update_enemies(delta: float) -> void:
	for e in enemies:
		if e["hit_cd"] > 0.0:
			e["hit_cd"] -= delta
		var dx := px - e["x"]
		var dy := py - e["y"]
		var dist := sqrt(dx*dx + dy*dy)
		if dist > 0.5:
			e["x"] += (dx / dist) * e["spd"] * delta
			e["y"] += (dy / dist) * e["spd"] * delta
		# 플레이어 접촉
		if dist < e["r"] + 14.0 and e["hit_cd"] <= 0.0:
			_hit_player(int(e["dmg"]))
			e["hit_cd"] = 0.6


func _update_boss(delta: float) -> void:
	if boss == null:
		return
	if boss["hp"] <= 0:
		_add_spark(boss["x"], boss["y"])
		boss = null
		_check_room_clear()
		return
	# 추적
	var dx := px - boss["x"]
	var dy := py - boss["y"]
	var dist := sqrt(dx*dx + dy*dy)
	if dist > 0.5:
		boss["x"] += (dx / dist) * boss["spd"] * delta
		boss["y"] += (dy / dist) * boss["spd"] * delta
	# 접촉 데미지
	if dist < boss["r"] + 14.0 and boss["hit_cd"] <= 0.0:
		_hit_player(int(boss["dmg"]))
		boss["hit_cd"] = 0.6
	if boss["hit_cd"] > 0.0:
		boss["hit_cd"] -= delta
	# 원거리 공격
	boss_attack_cd -= delta
	var interval := 1.5 if boss["big"] else 2.0
	var count := 14 if boss["big"] else 8
	if boss_attack_cd <= 0.0:
		for i in count:
			var a := TAU * i / float(count)
			ebullets.append({"x": boss["x"], "y": boss["y"],
							  "dx": cos(a), "dy": sin(a),
							  "spd": 180.0, "dmg": boss["dmg"],
							  "r": 6.0, "t": 0.0})
		boss_attack_cd = interval


func _update_spawn(delta: float) -> void:
	if spawn_queue <= 0:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_queue -= 1
		spawn_timer = 0.6
	_check_room_clear()


func _check_room_clear() -> void:
	if spawn_queue > 0:
		return
	if not enemies.is_empty():
		return
	if boss != null:
		return
	if portal != null:
		return
	if room_idx >= rooms.size() - 1:
		_victory()
	else:
		portal = {"x": W / 2.0, "y": WALL + 34.0, "r": 26.0}
		_show_toast("클리어! 포탈로 이동하세요")


func _update_portal(_delta: float) -> void:
	if portal == null:
		return
	var dx := px - portal["x"]
	var dy := py - portal["y"]
	if sqrt(dx*dx + dy*dy) < portal["r"] + 14.0:
		portal = null
		_enter_room(room_idx + 1)


func _update_benched_regen(delta: float) -> void:
	for i in fighters.size():
		if i != active and not fighters[i]["down"]:
			var f: Dictionary = fighters[i]
			f["hp"] = minf(f["hp"] + f["max_hp"] * 0.04 * delta, float(f["max_hp"]))


func _hit_player(dmg: int) -> void:
	if inv > 0.0:
		return
	var f: Dictionary = fighters[active]
	f["hp"] -= dmg
	inv = 0.35
	if f["hp"] <= 0:
		f["hp"] = 0.0
		f["down"] = true
		# 다음 살아있는 캐릭터 찾기
		var found := false
		for i in fighters.size():
			if not fighters[i]["down"]:
				_swap_to(i)
				found = true
				break
		if not found:
			_defeat()


func _swap_to(i: int) -> void:
	active = i
	swap_cd = 0.7
	inv = 0.3
	_show_toast("교대: %s" % fighters[i]["n"])


func _victory() -> void:
	won = true
	over = true
	var reco: int = GameData.battle.get("reco", 1)
	var my_pw: int = GameData.combat_power
	var stars: int
	if my_pw >= reco:
		stars = 3
	elif my_pw >= reco * 0.8:
		stars = 2
	else:
		stars = 1
	GameData.battle["result"] = true
	GameData.battle["stars"] = stars
	GameData.battle["won"] = true
	GameData.stats["clears"] = GameData.stats.get("clears", 0) + 1
	get_tree().create_timer(0.25).timeout.connect(func():
		ScreenManager.push(RESULT_SCENE)
	)


func _defeat() -> void:
	over = true
	won = false
	GameData.battle["result"] = false
	GameData.battle["stars"] = 0
	GameData.battle["won"] = false
	if _defeat_overlay == null:
		_show_defeat_overlay()


func _show_defeat_overlay() -> void:
	_defeat_overlay = PanelContainer.new()
	_defeat_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_defeat_overlay.position = Vector2(-130, -60)
	_defeat_overlay.custom_minimum_size = Vector2(260, 120)
	_defeat_overlay.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 16))
	_hud_layer.get_child(0).add_child(_defeat_overlay)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	_defeat_overlay.add_child(vb)

	var lbl := Label.new()
	lbl.text = "전멸..."
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", ThemeFactory.C_BAD)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl)

	var btn := Button.new()
	btn.text = "결과 보기"
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func():
		ScreenManager.push(RESULT_SCENE)
	)
	vb.add_child(btn)


# ── HUD 업데이트 ─────────────────────────────────────────
func _update_hud() -> void:
	if fighters.is_empty():
		return
	var f: Dictionary = fighters[active]
	_active_name_lbl.text = "%s (%s/%s)" % [f["n"], f["role"], f["weapon"]]
	var hp_ratio: float = f["hp"] / float(f["max_hp"]) if f["max_hp"] > 0 else 0.0
	_active_hp_fill.scale.x = clampf(hp_ratio, 0.0, 1.0)
	_active_hp_lbl.text = "%d / %d" % [int(f["hp"]), f["max_hp"]]

	# 슬롯
	for i in _slot_panels.size():
		var sp: PanelContainer = _slot_panels[i]
		if i >= fighters.size():
			sp.visible = false
			continue
		sp.visible = true
		var fi: Dictionary = fighters[i]
		var nl: Label = sp.get_node("VBoxContainer/NameLbl")
		nl.text = fi["n"]
		var hb: ColorRect = sp.get_node("VBoxContainer/HpBar")
		var hr: float = fi["hp"] / float(fi["max_hp"]) if fi["max_hp"] > 0 else 0.0
		hb.scale.x = clampf(hr, 0.0, 1.0)
		# 테두리 색
		var border_color: Color
		if i == active:
			border_color = ThemeFactory.C_CYAN
		elif fi["down"]:
			border_color = ThemeFactory.C_BAD
		else:
			border_color = ThemeFactory.C_LINE
		var sb2 := ThemeFactory.glass_panel(i == active, 6)
		sb2.border_color = border_color
		sp.add_theme_stylebox_override("panel", sb2)

	# 보스 바
	if boss != null:
		_boss_bar_bg.visible = true
		var br: float = boss["hp"] / float(boss["max_hp"]) if boss["max_hp"] > 0 else 0.0
		_boss_bar_fill.scale.x = clampf(br, 0.0, 1.0)
	else:
		_boss_bar_bg.visible = false


func _show_boss_bar(show: bool) -> void:
	_boss_bar_bg.visible = show


func _show_toast(msg: String) -> void:
	_toast_lbl.text = msg
	_toast_lbl.visible = true
	_toast_timer = 2.0


func _update_toast(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_lbl.visible = false


# ── 파티클 ────────────────────────────────────────────────
func _add_spark(x: float, y: float) -> void:
	for _i in 4:
		var a := randf() * TAU
		parts.append({"x": x, "y": y,
					   "dx": cos(a) * randf_range(30, 80),
					   "dy": sin(a) * randf_range(30, 80),
					   "t": randf_range(0.15, 0.4),
					   "max_t": 0.4,
					   "c": Color(1.0, randf_range(0.5, 1.0), 0.2)})


# ── 렌더링 ────────────────────────────────────────────────
func _render(gw: Node2D) -> void:
	# 배경
	gw.draw_rect(Rect2(0, 0, W, H), Color("15102a"))
	# 그리드
	var grid_c := Color(120.0/255, 90.0/255, 200.0/255, 0.10)
	var step := 48
	var x_pos := step
	while x_pos < W:
		gw.draw_line(Vector2(x_pos, 0), Vector2(x_pos, H), grid_c)
		x_pos += step
	var y_pos := step
	while y_pos < H:
		gw.draw_line(Vector2(0, y_pos), Vector2(W, y_pos), grid_c)
		y_pos += step
	# 벽 (내부 플레이 영역)
	gw.draw_rect(Rect2(WALL, WALL, W - 2*WALL, H - 2*WALL),
				 Color(190.0/255, 170.0/255, 1.0, 0.10), false, 1.5)

	# 포탈
	if portal != null:
		gw.draw_circle(Vector2(portal["x"], portal["y"]), portal["r"], Color(0.0, 1.0, 0.9, 0.5))
		gw.draw_circle(Vector2(portal["x"], portal["y"]), portal["r"] * 0.6, Color(0.0, 0.9, 1.0, 0.8))

	# 파티클
	for p in parts:
		var ratio: float = p["t"] / p["max_t"]
		var pc: Color = p["c"]
		pc.a = ratio
		gw.draw_circle(Vector2(p["x"], p["y"]), 3.0 * ratio, pc)

	# 적 총알
	for eb in ebullets:
		gw.draw_circle(Vector2(eb["x"], eb["y"]), eb["r"], Color(1.0, 0.55, 0.1, 0.9))

	# 적
	for e in enemies:
		var ec: Color = e["c"]
		var ep := Vector2(e["x"], e["y"])
		var er: float = e["r"]
		match e["kind"]:
			"tank":
				gw.draw_rect(Rect2(ep.x - er, ep.y - er, er*2, er*2), ec)
			"fast":
				var pts := PackedVector2Array([
					ep + Vector2(0, -er),
					ep + Vector2(er * 0.8, er * 0.7),
					ep + Vector2(-er * 0.8, er * 0.7),
				])
				gw.draw_colored_polygon(pts, ec)
			_:
				gw.draw_circle(ep, er, ec)
		# HP 바 (체력이 최대가 아닐 때)
		if e["hp"] < e["max_hp"]:
			var bar_w: float = er * 2
			var hp_ratio: float = e["hp"] / e["max_hp"]
			gw.draw_rect(Rect2(ep.x - er, ep.y + er + 2, bar_w, 3), Color(0.3, 0.3, 0.3))
			gw.draw_rect(Rect2(ep.x - er, ep.y + er + 2, bar_w * hp_ratio, 3), Color(0.3, 1.0, 0.4))

	# 보스
	if boss != null:
		var bp := Vector2(boss["x"], boss["y"])
		var br: float = boss["r"]
		# 글로우
		gw.draw_circle(bp, br * 1.4, Color(boss["c"].r, boss["c"].g, boss["c"].b, 0.25))
		gw.draw_circle(bp, br, boss["c"])
		# HP 바
		if boss["hp"] < boss["max_hp"]:
			var bw: float = br * 2.2
			var bhr: float = boss["hp"] / float(boss["max_hp"])
			gw.draw_rect(Rect2(bp.x - bw/2, bp.y + br + 3, bw, 5), Color(0.3, 0.3, 0.3))
			gw.draw_rect(Rect2(bp.x - bw/2, bp.y + br + 3, bw * bhr, 5), ThemeFactory.C_PINK)

	# 플레이어 총알
	for b in bullets:
		gw.draw_circle(Vector2(b["x"], b["y"]), b["r"], Color(0.2, 0.95, 1.0, 0.9))

	# 플레이어
	if not fighters.is_empty():
		var f: Dictionary = fighters[active]
		var pp := Vector2(px, py)
		var blink_ok: bool = inv <= 0.0 or (fmod(inv * 10.0, 2.0) < 1.0)
		if blink_ok:
			# 그라데이션 원 (간략화: 외부 + 내부)
			gw.draw_circle(pp, 14.0, f["c2"])
			gw.draw_circle(pp, 10.0, f["c1"])
		# 조준선
		var aim_end := pp + aim_dir * 36.0
		gw.draw_line(pp, aim_end, Color(1.0, 1.0, 1.0, 0.5), 1.5)
		gw.draw_circle(aim_end, 3.0, Color(1.0, 1.0, 1.0, 0.7))


# ── 입력 이벤트 ──────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if over:
		return
	# 스왑 (숫자키 1-5)
	for i in 5:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_1 + i:
				if i < fighters.size() and not fighters[i]["down"]:
					_swap_to(i)
	# 대쉬 (스페이스)
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if dash_cd <= 0.0:
			var dir := move_dir if move_dir.length() > 0.1 else aim_dir
			dash_vx = dir.x * 620.0
			dash_vy = dir.y * 620.0
			dash_cd = 1.0
	# ESC 두 번 → 나가기
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		esc_count += 1
		if esc_count >= 2:
			_on_exit()
		else:
			_show_toast("ESC 한 번 더 누르면 나갑니다")
			get_tree().create_timer(1.5).timeout.connect(func():
				esc_count = 0
			)


func _on_exit() -> void:
	over = true
	ScreenManager.pop()

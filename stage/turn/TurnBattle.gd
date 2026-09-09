extends Node2D

# 턴제 전투 화면 (#450).
#
# 설계서 PART 5 의 **Phase 0 — 감각 검증**에 해당하는 화면이다.
#
# > 사각형 도형만으로 아군 2 vs 적 2 전투 / AV 타임라인 / 3버튼 / 공명 5핍 /
# > 인성치 + 자물쇠 + 격파 판정 / **약점 격파 연출 9단계 완성** ← 도형이어도 좋으니 이건 제대로
# >
# > Phase 0에서 격파 순간이 짜릿하지 않으면 전체 설계를 재검토하라.
# > 아트를 입혀도 재미가 생기지 않는다.
#
# 그래서 이 화면은 **도형과 트윈만 쓴다.** Spine 애니메이션·컷인 일러스트·패럴랙스
# 배경은 Phase 3의 일이고, 여기서 검증할 것은 로직과 **타격 감각**이다.
#
# 이 파일이 하는 일: 로직(`TurnBattleManager`)이 즉시 계산을 끝낸 뒤 쌓아 둔
# 연출 큐(`PresentationQueue`)를 순차 재생한다. 로직과 연출이 분리되어 있어서
# **배속이 재생 시간을 나누기만 하면 된다.**
#
# 실행: 이 씬을 F6으로 실행한다.
#
# 참고: docs/turn-combat-design.md §연출

## **저작된 스테이지를 읽어 전투를 만든다.** 껐을 때만 아래 `party_ids`/`enemy_ids` 를 쓴다.
##
## 켜면: `StageSystem` 의 현재 스테이지에서 웨이브별 적을 뽑고, `forced_party` 를 적용하고,
## 승패를 `EventBus.stage_completed` / `stage_failed` 로 알려 결과 화면·진행도와 이어진다.
## 즉 **출격 흐름이 그대로 턴제 전투로 이어진다** (#472).
@export var use_stage: bool = true

## 이 전투에 출전할 파티. 비우면 편성 파티 → 로스터 순으로 채운다.
@export var party_ids: Array[StringName] = []
## 이 전투의 적. `use_stage` 가 꺼져 있을 때만 쓴다. 비우면 기본 조우를 만든다.
@export var enemy_ids: Array[StringName] = []
## 결정론적 RNG 시드. 0이면 시간으로 정한다.
@export var battle_seed: int = 0
## 선공(1) / 일반(0) / 피습(-1).
@export var ambush: int = 0

var battle := TurnBattleManager.new()
var hud: TurnBattleHUD = null

## 유닛별 도형. `unit_id` -> Node2D.
var _shapes: Dictionary = {}
## 화면 전체를 덮는 플래시·암전 레이어.
var _flash: ColorRect = null
var _flash_layer: CanvasLayer = null
## 데미지 숫자를 띄우는 레이어.
var _numbers: Node2D = null
## 격파 타이포그래피.
var _banner: Label = null

## 연출을 재생 중인가. 재생 중에는 다음 턴으로 넘어가지 않는다.
var _playing: bool = false
## 이 전투가 물고 있는 스테이지. `use_stage` 가 켜져 있을 때만 채워진다.
var _stage: StageData = null
## 스테이지의 웨이브 정의. 번호 -> `StageWave`. `stage_wave_started` 에 실어 보낸다.
var _waves: Array[StageWave] = []
## 승패를 이미 알렸는가. 결과 화면이 두 번 뜨는 것을 막는다.
var _outcome_reported: bool = false
## 카메라 흔들림 상태.
var _shake_amount: float = 0.0
var _shake_time: float = 0.0
var _camera_home := Vector2.ZERO

var _camera: Camera2D = null


func _ready() -> void:
	name = "TurnBattle"
	_build_scene()

	# 출격(스테이지 선택 → 편성 → 출격)이 이 신호를 쏜다. 실시간 `Stage1_1` 과 같은 규약이라
	# 출격 화면은 어느 전장이 떠 있는지 몰라도 된다.
	if use_stage:
		StageSystem.stage_requested.connect(_on_stage_requested)

	_start_battle()


# 다른 스테이지로 출격했다. 전투를 그 스테이지로 다시 만든다.
func _on_stage_requested(_stage_id: StringName) -> void:
	_restart()


# 전투를 처음부터 다시 만든다. 도형과 연출 잔여물을 치우고 새로 시작한다.
func _restart() -> void:
	for child in _numbers.get_children():
		child.queue_free()
	for id in _shapes:
		var shape: Node2D = _shapes[id]
		if shape != null:
			shape.queue_free()
	_shapes.clear()

	var stale := _flash_layer.get_node_or_null("ResultSummary")
	if stale != null:
		stale.queue_free()

	battle = TurnBattleManager.new()
	_outcome_reported = false
	_start_battle()


func _tuning() -> TurnCombatTuning:
	return TurnCombatConfig.tuning


# ===== 화면 구성 (Scene) =====

func _build_scene() -> void:
	# 배경 — Phase 0이므로 단색 + 지면선만 둔다. 패럴랙스 5레이어는 Phase 3다.
	var background := ColorRect.new()
	background.color = Color("11141C")
	background.size = Vector2(1280, 720)
	background.z_index = -100
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var ground := ColorRect.new()
	ground.color = Color("1A2030")
	ground.position = Vector2(0, 300)
	ground.size = Vector2(1280, 420)
	ground.z_index = -99
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	# 중앙 충돌선 — 아군과 적을 가르는 기준선.
	var divider := ColorRect.new()
	divider.color = Color(1, 1, 1, 0.05)
	divider.position = Vector2(636, 180)
	divider.size = Vector2(2, 380)
	divider.z_index = -98
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)

	_camera = Camera2D.new()
	_camera.position = Vector2(640, 360)
	_camera_home = _camera.position
	add_child(_camera)

	_numbers = Node2D.new()
	_numbers.z_index = 50
	add_child(_numbers)

	# HUD (CanvasLayer 위에 둬야 카메라 흔들림에 함께 흔들리지 않는다).
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)

	hud = TurnBattleHUD.new()
	hud_layer.add_child(hud)
	hud.action_chosen.connect(_on_action_chosen)
	hud.ultimate_requested.connect(_on_ultimate_requested)
	hud.speed_changed.connect(_on_speed_changed)
	hud.auto_toggled.connect(_on_auto_toggled)

	# 플래시 / 암전 레이어는 HUD 위에 온다 — 격파 순간에는 UI까지 덮어야 한다.
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 20
	add_child(_flash_layer)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = Vector2(1280, 720)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_flash)

	_banner = Label.new()
	_banner.text = ""
	_banner.modulate = Color(1, 1, 1, 0)
	_banner.position = Vector2(300, 300)
	_banner.add_theme_font_size_override("font_size", 84)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_banner)


# ===== 전투 개시 (Start) =====

func _start_battle() -> void:
	_stage = StageSystem.get_current_stage() if use_stage else null
	_waves.clear()

	# 강제 파티는 파티를 뽑기 **전에** 적용해야 한다 — `PartySystem` 에서 읽어 오므로
	# 순서가 뒤집히면 강제 편성이 다음 전투에나 반영된다.
	if _stage != null and not _stage.forced_party.is_empty():
		PartySystem.set_party(_stage.forced_party)

	var party := _resolve_party()
	var waves := _resolve_waves()

	if party.is_empty() or waves.is_empty():
		push_error("TurnBattle: 파티나 적을 구성할 수 없습니다.")
		return

	var use_seed := battle_seed
	if use_seed == 0:
		use_seed = int(Time.get_unix_time_from_system())

	# 첫 웨이브로 시작하고 나머지는 전투에 맡긴다. 아군 상태는 웨이브 사이에 이어진다.
	battle.pending_waves = waves.slice(1)
	battle.on_wave_started = _on_wave_started
	battle.start(party, waves[0], ambush, use_seed)
	hud.battle = battle

	_build_shapes()

	# 준비 페이즈는 아직 화면이 없다 — 기본 준비(오의 게이지 50%)만 쓰고 넘어간다.
	# 준비 페이즈 UI는 별도 이슈다(Non-goals).
	battle.use_prep("energy")
	battle.begin_battle()

	_play()


func _resolve_party() -> Array[CharacterData]:
	var out: Array[CharacterData] = []

	var ids := party_ids
	if ids.is_empty():
		# `PartySystem` 이 편성한 파티를 우선 쓴다 — 편성이 전투에 이어지는 것이 정상이다.
		for member in PartySystem.get_members():
			if member is CharacterData and member.is_turn_ready():
				out.append(member)
		if out.size() >= 1:
			# 턴제는 4인이므로 부족하면 로스터에서 채운다.
			for id in CharacterDatabase.get_playable_ids():
				if out.size() >= TurnCombat.ALLY_RANK_COUNT:
					break
				var extra: CharacterData = CharacterDatabase.get_character(id)
				if extra != null and extra.is_turn_ready() and not out.has(extra):
					out.append(extra)
			return out
		ids = []
		for id in CharacterDatabase.get_playable_ids():
			ids.append(id)

	for id in ids:
		if out.size() >= TurnCombat.ALLY_RANK_COUNT:
			break
		var character: CharacterData = CharacterDatabase.get_character(id)
		if character != null and character.is_turn_ready():
			out.append(character)
	return out


# 이 전투의 웨이브들. 각 원소가 그 웨이브의 적 목록이다.
#
# 번역은 `TurnStageEncounter` 가 한다 — 노드 없이 호출되므로 헤드리스에서 직접 검증된다.
# 반환 타입이 `Array[Array[EnemyData]]` 가 아닌 이유: GDScript 는 중첩 타입 배열을 지원하지 않는다.
func _resolve_waves() -> Array:
	var out: Array = []

	if _stage != null:
		for entry in TurnStageEncounter.waves_for(_stage):
			out.append(entry["enemies"])
			_waves.append(entry["wave"])
		if not out.is_empty():
			return out
		push_warning("TurnBattle: 스테이지 %s 에서 적을 뽑을 수 없어 기본 조우로 대체합니다."
			% _stage.stage_id)

	var fallback := TurnStageEncounter.fallback_enemies(enemy_ids)
	if fallback.is_empty():
		return out
	_waves.append(null)
	return [fallback]


# 웨이브가 놓였다. 스테이지 도메인의 신호로 옮겨 쏜다.
#
# 전투는 `StageWave` 를 모르고 번호만 알린다 — 그 경계를 지켜야 전투를 스테이지 없이도
# 굴릴 수 있다(헤드리스 테스트와 `use_stage = false` 가 그렇게 쓴다).
func _on_wave_started(index: int, total: int) -> void:
	if _stage == null:
		return
	var wave: StageWave = _waves[index] if index < _waves.size() else null
	EventBus.stage_wave_started.emit(String(_stage.stage_id), index, total, wave)


# 유닛마다 도형을 하나 만든다. Phase 0은 도형으로 감각을 검증한다.
func _build_shapes() -> void:
	for unit in battle.units:
		var shape := Node2D.new()
		shape.z_index = 10

		var body := ColorRect.new()
		var tint := Color("C8402F")
		if unit.is_ally() and unit.character != null:
			tint = unit.character.tint
		body.color = tint
		body.size = Vector2(56, 84) if unit.is_ally() else Vector2(62, 78)
		body.position = -body.size * Vector2(0.5, 1.0)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape.add_child(body)

		# 접지 그림자 — 없으면 캐릭터가 떠 보인다 (설계서 §4.10.2).
		var shadow := ColorRect.new()
		shadow.color = Color(0, 0, 0, 0.32)
		shadow.size = Vector2(60, 12)
		shadow.position = Vector2(-30, -6)
		shadow.z_index = -1
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape.add_child(shadow)

		# 원소 문양 — 색맹 대응으로 색과 형태를 함께 쓴다.
		var glyph := Label.new()
		glyph.text = TurnCombat.element_glyph(unit.element)
		glyph.add_theme_font_size_override("font_size", 22)
		glyph.modulate = TurnCombat.element_color(unit.element)
		glyph.position = Vector2(-10, -112)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape.add_child(glyph)

		add_child(shape)
		_shapes[unit.unit_id] = shape

	_sync_shapes()


# 도형을 랭크 위치로 옮긴다. 밀치기·끌기가 실제로 눈에 보여야 위치 전술이 성립한다.
func _sync_shapes(animated: bool = false) -> void:
	for unit in battle.units:
		var shape: Node2D = _shapes.get(unit.unit_id)
		if shape == null:
			continue
		if not unit.alive:
			shape.visible = false
			continue

		var target := hud.unit_position(unit)
		if animated and not shape.position.is_equal_approx(target):
			var tween := create_tween()
			tween.tween_property(shape, "position", target, _scaled(0.25)) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		else:
			shape.position = target

		# 격파 상태는 도형을 기울여 비틀거림을 표현한다.
		shape.rotation = deg_to_rad(9.0) if unit.is_broken else 0.0
		# 행동 중인 유닛을 살짝 키운다 (턴 대기 강조).
		shape.scale = Vector2(1.08, 1.08) if unit == battle.active_unit else Vector2.ONE


# ===== 진행 (Drive) =====

# 전투를 진행하고 연출을 재생한다.
#
# 로직은 이미 끝나 있다 — 여기서는 큐를 비우고, 아군 차례가 오면 입력을 기다린다.
func _play() -> void:
	if _playing:
		return
	_playing = true

	while true:
		await _drain_presentation()
		_sync_shapes(true)
		hud.refresh()

		if battle.is_over():
			await _show_result()
			break

		if battle.phase == TurnBattleManager.Phase.AWAITING_INPUT:
			break  # 입력 대기 — 제한시간 없음.

		if battle.phase == TurnBattleManager.Phase.TURN_START \
				or battle.phase == TurnBattleManager.Phase.TURN_END:
			battle.advance()
			continue

		break

	_playing = false


# 연출 큐를 순차 재생한다.
#
# **배속은 여기서만 적용된다.** 로직은 배속을 모른다.
func _drain_presentation() -> void:
	var queue := battle.presentation
	if queue == null:
		return

	while not queue.is_empty():
		var entry := queue.pop()
		var event: int = entry["event"]
		var data: Dictionary = entry["data"]

		match event:
			PresentationQueue.Event.SKILL_CAST:
				await _play_cast(data)

			PresentationQueue.Event.HIT:
				await _play_hit(data)

			PresentationQueue.Event.LOCK_CLEARED:
				await _play_lock(data)

			PresentationQueue.Event.NULLIFIED:
				await _play_nullified(data)

			PresentationQueue.Event.BREAK:
				await _play_break(data)

			PresentationQueue.Event.ULTIMATE_CUTIN:
				await _play_cutin(data)

			PresentationQueue.Event.DEATH:
				await _play_death(data)

			PresentationQueue.Event.CYCLE_START:
				await _play_banner("%d CYCLE" % int(data.get("cycle", 1)),
					TurnCombat.COLOR_TOUGHNESS, 0.35, 44)

			_:
				pass

		hud.refresh()


func _play_cast(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	var shape: Node2D = _shapes.get(unit.unit_id) if unit != null else null
	if shape == null:
		return

	# 시전자가 앞으로 살짝 나갔다 돌아온다. 3D 모션의 2D 대체다.
	var direction := 1.0 if unit.is_ally() else -1.0
	var home := shape.position
	var tween := create_tween()
	tween.tween_property(shape, "position", home + Vector2(direction * 26.0, 0),
		_scaled(0.10)).set_ease(Tween.EASE_OUT)
	tween.tween_property(shape, "position", home, _scaled(0.14)).set_ease(Tween.EASE_IN)
	await tween.finished


# 타격 피드백. 규격표(§4.10.5)의 수치를 그대로 쓴다.
func _play_hit(data: Dictionary) -> void:
	var ctx: DamageContext = data.get("context")
	if ctx == null:
		return

	var feedback: Dictionary = data.get("feedback", {})
	var style: Dictionary = data.get("number", {})
	var target_shape: Node2D = _shapes.get(ctx.target.unit_id)

	# 히트스톱 — 인간의 지각에서 "묵직함"의 90%가 여기서 나온다.
	await _hitstop(int(feedback.get("hitstop_frames", 2)))

	# 넉백 — 방향성 있는 흔들림이 무작위보다 훨씬 좋다.
	if target_shape != null:
		var knock := float(feedback.get("knockback_px", 0.0))
		var direction := -1.0 if ctx.target.is_ally() else 1.0
		var home := target_shape.position
		var tween := create_tween()
		tween.tween_property(target_shape, "position",
			home + Vector2(direction * knock, 0), _scaled(0.06))
		tween.tween_property(target_shape, "position", home, _scaled(0.12))
		# 피격 명멸.
		var body := target_shape.get_child(0)
		if body is ColorRect:
			var original: Color = body.color
			var flash_tween := create_tween()
			flash_tween.tween_property(body, "color", Color.WHITE, _scaled(0.04))
			flash_tween.tween_property(body, "color", original, _scaled(0.12))

	_shake(float(feedback.get("shake_px", 0.0)), float(feedback.get("shake_time", 0.0)))
	_screen_flash(Color.WHITE, float(feedback.get("flash", 0.0)), 0.12)
	_spawn_number(ctx, style)

	await _wait(0.10)


func _play_lock(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	var lock: TurnLock = data.get("lock")
	if unit == null or lock == null:
		return

	var feedback: Dictionary = data.get("feedback", {})
	await _hitstop(int(feedback.get("hitstop_frames", 3)))
	_shake(float(feedback.get("shake_px", 3.0)), float(feedback.get("shake_time", 0.1)))
	_screen_flash(lock.color(), float(feedback.get("flash", 0.15)), 0.10)

	# 해제된 자물쇠 문양이 위로 튀어오르며 사라진다.
	# 음정(`data["pitch"]`)은 사운드가 붙을 때 그대로 쓴다 — 상승 음계 설계다.
	var label := Label.new()
	label.text = lock.glyph()
	label.modulate = lock.color()
	label.add_theme_font_size_override("font_size", 30)
	label.position = hud.unit_position(unit) + Vector2(-8, -120)
	label.z_index = 60
	_numbers.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position",
		label.position + Vector2(0, -40), _scaled(0.5))
	tween.tween_property(label, "modulate:a", 0.0, _scaled(0.5))
	tween.chain().tween_callback(label.queue_free)

	await _wait(0.08)


func _play_nullified(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	if unit == null:
		return
	# 적 행동이 무산됐다 — 자물쇠를 전부 열었다. 가장 통쾌한 순간이므로 크게 알린다.
	await _play_banner("NULLIFIED", TurnCombat.COLOR_ULT_READY, 0.5, 58)


# ===== 약점 격파 9단계 (설계서 §4.10.7) =====
#
# **이 9단계가 게임의 첫인상을 결정한다.**
# 단계 목록은 `PresentationQueue.break_steps()`가 데이터로 돌려주고, 여기서는 재생만 한다 —
# 단계를 늘릴 때 재생기를 고치지 않아도 되게 하려는 것이다.
func _play_break(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	var color: Color = data.get("color", Color.WHITE)
	var ctx: DamageContext = data.get("context")
	var steps: Array = data.get("steps", [])
	var shape: Node2D = _shapes.get(unit.unit_id) if unit != null else null

	for step in steps:
		var index := int(step.get("step", 0))
		var duration := float(step.get("duration", 0.0))

		match index:
			1:
				pass  # 감지 — 즉시.

			2:
				# 전 게임 정지 12프레임.
				await _hitstop(12)

			3:
				# 인성치 바 파열 + 유리 파편.
				_shake(20.0, 0.45)
				_spawn_shards(unit, color)
				await _wait(duration)

			4:
				# 시간 감속 0.25초 @ 0.15배속.
				Engine.time_scale = float(step.get("time_scale", 0.15))
				await _wait_real(duration)
				Engine.time_scale = 1.0

			5:
				# 화면 전체 원소 색 플래시 70% -> 0%.
				_screen_flash(color, 0.70, duration)
				await _wait(duration * 0.5)

			6:
				# 원소별 전용 대형 이펙트. Phase 0은 도형 파티클로 대체한다.
				_spawn_element_burst(unit, color)
				await _wait(duration * 0.5)

			7:
				# "BREAK!" 타이포그래피가 화면을 가로지른다.
				await _play_banner("BREAK!", color, duration, 96)

			8:
				# 적 비틀거림 + 붉은 실루엣 명멸.
				if shape != null:
					var tween := create_tween()
					tween.tween_property(shape, "rotation", deg_to_rad(14.0), _scaled(0.12))
					tween.tween_property(shape, "rotation", deg_to_rad(6.0), _scaled(0.12))
					tween.tween_property(shape, "rotation", deg_to_rad(9.0), _scaled(0.10))
				await _wait(duration * 0.5)

			9:
				# 격파 데미지 대형 숫자 + 상태이상 아이콘 부착.
				if ctx != null:
					var style := battle.presentation.number_style_for(ctx)
					_spawn_number(ctx, style)
				_spawn_status_badge(unit, int(data.get("status", 0)), color)
				await _wait(duration * 0.4)

	hud.refresh()


func _play_cutin(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	var skill: SkillData = data.get("skill")
	if unit == null or skill == null:
		return

	var color := TurnCombat.element_color(unit.element)

	# 0.00s 암전.
	_screen_flash(Color.BLACK, 0.9, 0.08)
	await _wait(0.08)

	# 0.08s 스피드라인 — Phase 0은 색 띠로 대체한다.
	_screen_flash(color, 0.45, 0.12)

	# 0.45s 키네틱 타이포그래피. **글자 자체가 연출이 되면 3D 카메라가 없어도 강렬하다.**
	await _play_banner("%s / %s" % [unit.display_name, skill.display_name], color, 0.55, 52)

	# 1.10s 오의 모션 — 시전자를 크게 키웠다 되돌린다.
	var shape: Node2D = _shapes.get(unit.unit_id)
	if shape != null:
		var tween := create_tween()
		tween.tween_property(shape, "scale", Vector2(1.35, 1.35), _scaled(0.18)) \
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(shape, "scale", Vector2.ONE, _scaled(0.22))
	_camera_zoom(1.6, 0.25)
	await _wait(0.25)
	_camera_zoom(1.0, 0.25)


func _play_death(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	var shape: Node2D = _shapes.get(unit.unit_id) if unit != null else null
	if shape == null:
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(shape, "modulate:a", 0.0, _scaled(0.35))
	tween.tween_property(shape, "rotation", deg_to_rad(-70.0), _scaled(0.35))
	await tween.finished
	shape.visible = false


func _show_result() -> void:
	var summary := battle.result_summary()
	var victory := bool(summary["victory"])

	# **승패를 스테이지 도메인으로 알린다.** 이 신호로 결과 화면(`stage_result_launcher`)과
	# 진행도·보상(`StageProgress`)이 굴러간다 — 실시간 `Stage1_1` 과 같은 규약이라
	# 그 두 시스템은 어느 전장이 떠 있었는지 몰라도 된다.
	#
	# `stage_started` 는 **쏘지 않는다.** 그 신호로 `TutorialSystem` 이 활성화되는데,
	# 저작된 튜토리얼 단계의 진행 조건이 대시·처형 같은 **실시간 행동**이라 턴제에서는
	# 영원히 충족되지 않고 진행 불가로 멈춘다 (#472 Consequences 1).
	if _stage != null and not _outcome_reported:
		_outcome_reported = true
		var stage_name := String(_stage.stage_id)
		if victory:
			EventBus.stage_completed.emit(stage_name)
		else:
			EventBus.stage_failed.emit(stage_name)

	await _play_banner("VICTORY" if victory else "DEFEAT",
		TurnCombat.COLOR_ULT_READY if victory else TurnCombat.COLOR_DANGER, 1.2, 88)

	# 전투 결과 요약 — 캐릭터별 딜량 / 격파 횟수 / 사이클 수 (설계서 §11.4).
	var lines: Array[String] = []
	lines.append("%d/%d 웨이브  ·  %d 사이클  ·  %d턴  ·  격파 %d회  ·  자물쇠 %d개 해제  ·  무산 %d회"
		% [int(summary["waves"]), int(summary["wave_total"]),
			int(summary["cycles"]), int(summary["turns"]), int(summary["breaks"]),
			int(summary["locks_cleared"]), int(summary["nullified"])])
	var damage: Dictionary = summary["damage"]
	for name_key in damage:
		lines.append("%s  %d" % [name_key, int(damage[name_key])])

	var panel := Label.new()
	panel.name = "ResultSummary"
	panel.text = "\n".join(lines)
	panel.add_theme_font_size_override("font_size", 20)
	panel.position = Vector2(420, 250)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(panel)

	print("[TurnBattle] " + "\n".join(lines))


# ===== 입력 (Input) =====

func _on_action_chosen(skill: SkillData, target: TurnUnit) -> void:
	if battle.phase != TurnBattleManager.Phase.AWAITING_INPUT:
		return
	var result := battle.act(skill, target)
	if not bool(result["ok"]):
		print("[TurnBattle] 행동 실패: %s" % result["reason"])
		hud.refresh()
		return
	_play()


func _on_ultimate_requested(unit: TurnUnit) -> void:
	# **오의는 턴 순서와 무관하게 언제든 발동한다.** 입력 대기 중이 아니어도 받는다.
	var result := battle.use_ultimate(unit)
	if not bool(result["ok"]):
		print("[TurnBattle] 오의 실패: %s" % result["reason"])
		return
	_play()


func _on_speed_changed(new_speed: float) -> void:
	# **로직을 건드리지 않는다.** 연출 큐의 재생 시간만 나눈다.
	if battle.presentation != null:
		battle.presentation.speed = new_speed


func _on_auto_toggled(enabled: bool) -> void:
	battle.auto_battle = enabled
	if enabled and battle.phase == TurnBattleManager.Phase.AWAITING_INPUT:
		# 자동으로 켜면 대기 중인 턴부터 바로 굴린다.
		battle.advance()
		_play()


# ===== 연출 원시 함수 (Primitives) =====

# 히트스톱. 프레임 수만큼 게임 전체를 정지시킨다.
func _hitstop(frames: int) -> void:
	if frames <= 0:
		return
	var seconds := float(frames) / 60.0
	Engine.time_scale = 0.0001
	await _wait_real(seconds)
	Engine.time_scale = 1.0


# 카메라 흔들림. 진폭·지속의 2파라미터에 감쇠를 준다.
func _shake(amount: float, duration: float) -> void:
	if amount <= 0.0 or duration <= 0.0:
		return
	_shake_amount = amount
	_shake_time = _scaled(duration)


func _screen_flash(color: Color, strength: float, duration: float) -> void:
	if strength <= 0.0 or _flash == null:
		return
	_flash.color = Color(color.r, color.g, color.b, strength)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, _scaled(duration))


func _camera_zoom(target: float, duration: float) -> void:
	if _camera == null:
		return
	var tween := create_tween()
	tween.tween_property(_camera, "zoom", Vector2(target, target), _scaled(duration)) \
		.set_ease(Tween.EASE_OUT)


func _play_banner(text: String, color: Color, duration: float, size: int) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.add_theme_font_size_override("font_size", size)
	_banner.modulate = Color(color.r, color.g, color.b, 0)
	# 비스듬한 각도 — 설계서 §4.10.4 의 타이포그래피 규격(-8° ~ -12°).
	_banner.rotation = deg_to_rad(-9.0)
	_banner.pivot_offset = Vector2.ZERO
	_banner.position = Vector2(360, 320)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_banner, "modulate:a", 1.0, _scaled(duration * 0.25))
	tween.tween_property(_banner, "position",
		_banner.position + Vector2(60, -14), _scaled(duration))
	tween.chain().tween_property(_banner, "modulate:a", 0.0, _scaled(duration * 0.35))
	await tween.finished


# 데미지 숫자. 규격표(§4.10.6)의 색·크기·애니메이션을 쓴다.
func _spawn_number(ctx: DamageContext, style: Dictionary) -> void:
	if _numbers == null or ctx.target == null:
		return

	var label := Label.new()
	label.text = str(ctx.final_damage())
	if not String(style.get("label", "")).is_empty():
		label.text = "%s\n%s" % [String(style["label"]), label.text]
	label.modulate = style.get("color", Color.WHITE)
	label.add_theme_font_size_override("font_size",
		int(20.0 * float(style.get("scale", 1.0))))
	label.position = hud.unit_position(ctx.target) + Vector2(
		randf_range(-18.0, 18.0), -96.0)
	label.z_index = 60
	_numbers.add_child(label)

	var tween := create_tween()
	# 치명타는 스케일 팝(0 -> 1.3 -> 1.0).
	if ctx.is_crit or ctx.is_break_damage:
		label.scale = Vector2.ZERO
		tween.tween_property(label, "scale", Vector2(1.3, 1.3), _scaled(0.09))
		tween.tween_property(label, "scale", Vector2.ONE, _scaled(0.07))
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -46),
		_scaled(0.7))
	tween.tween_property(label, "modulate:a", 0.0, _scaled(0.7))
	tween.chain().tween_callback(label.queue_free)


# 인성치 바 파열의 유리 파편.
func _spawn_shards(unit: TurnUnit, color: Color) -> void:
	var origin := hud.unit_position(unit) + Vector2(0, -80)
	for i in 18:
		var shard := ColorRect.new()
		shard.color = color
		shard.size = Vector2(randf_range(3, 8), randf_range(3, 8))
		shard.position = origin
		shard.z_index = 55
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_numbers.add_child(shard)

		var angle := TAU * float(i) / 18.0 + randf_range(-0.2, 0.2)
		var distance := randf_range(60.0, 150.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "position",
			origin + Vector2.RIGHT.rotated(angle) * distance, _scaled(0.5))
		tween.tween_property(shard, "modulate:a", 0.0, _scaled(0.5))
		tween.tween_property(shard, "rotation", randf_range(-6.0, 6.0), _scaled(0.5))
		tween.chain().tween_callback(shard.queue_free)


# 원소별 대형 이펙트. Phase 0은 방사형 링으로 대체한다 (전용 이펙트는 Phase 3).
func _spawn_element_burst(unit: TurnUnit, color: Color) -> void:
	var origin := hud.unit_position(unit) + Vector2(0, -44)
	for i in 3:
		var ring := ColorRect.new()
		ring.color = Color(color.r, color.g, color.b, 0.45)
		ring.size = Vector2(24, 24)
		ring.position = origin - ring.size * 0.5
		ring.pivot_offset = ring.size * 0.5
		ring.z_index = 54
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_numbers.add_child(ring)

		var tween := create_tween()
		tween.tween_interval(_scaled(0.06 * float(i)))
		tween.set_parallel(true)
		tween.tween_property(ring, "scale", Vector2(9, 9), _scaled(0.45))
		tween.tween_property(ring, "modulate:a", 0.0, _scaled(0.45))
		tween.tween_property(ring, "rotation", randf_range(-1.2, 1.2), _scaled(0.45))
		tween.chain().tween_callback(ring.queue_free)


# 상태이상 아이콘 부착 애니메이션 (격파 9단계의 마지막).
func _spawn_status_badge(unit: TurnUnit, status: int, color: Color) -> void:
	var label := Label.new()
	label.text = "[%s]" % TurnCombat.break_status_name(status)
	label.modulate = color
	label.add_theme_font_size_override("font_size", 22)
	label.position = hud.unit_position(unit) + Vector2(-30, -140)
	label.scale = Vector2(2.2, 2.2)
	label.z_index = 60
	_numbers.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, _scaled(0.25)) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "position",
		label.position + Vector2(0, 44), _scaled(0.35))
	tween.chain().tween_property(label, "modulate:a", 0.0, _scaled(0.4))
	tween.chain().tween_callback(label.queue_free)


# ===== 시간 (Timing) =====

# 배속이 적용된 지속시간.
func _scaled(duration: float) -> float:
	if battle.presentation == null:
		return duration
	return battle.presentation.scaled(duration)


# 배속을 반영해 기다린다.
func _wait(duration: float) -> void:
	var scaled := _scaled(duration)
	if scaled <= 0.0:
		return
	await get_tree().create_timer(scaled).timeout


# `Engine.time_scale`을 무시하고 실제 시간으로 기다린다.
# 히트스톱과 슬로모션은 `time_scale`을 건드리므로 일반 타이머로는 풀리지 않는다.
func _wait_real(duration: float) -> void:
	var scaled := _scaled(duration)
	if scaled <= 0.0:
		return
	await get_tree().create_timer(scaled, true, false, true).timeout


func _process(delta: float) -> void:
	if _camera == null:
		return

	if _shake_time > 0.0:
		_shake_time -= delta
		# 감쇠 — 진폭이 시간에 따라 줄어든다.
		var decay := maxf(_shake_time, 0.0)
		_camera.position = _camera_home + Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)) * decay * 6.0
		if _shake_time <= 0.0:
			_camera.position = _camera_home
	elif not _camera.position.is_equal_approx(_camera_home):
		_camera.position = _camera_home

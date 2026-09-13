extends Node

# 연출을 **켠 채** 저작된 스테이지를 끝까지 굴려 본다 — 전투가 멈추는지 잡는 테스트.
#
# ## 왜 따로 있어야 하나
#
# `VerifyTurnStageBattle` 은 같은 일을 하면서 **연출을 끈다.** 그 파일의 주석이 이유를
# 적어 두었다: *"연출을 끄면 큐가 비어 재생 대기가 사라지고 전투가 즉시 끝난다."*
# 빠르고 결정적이라 좋은 선택이지만, **그래서 연출 계층에서 멈추는 것을 절대 못 잡는다.**
#
# 실제로 그런 일이 있었다 — 화면에는 "웨이브 3/3 · 적 행동 중" 이 25초 넘게 멈춰 있고
# 적은 보이지 않는데 데미지 숫자만 떴다. 로직 검증 438개와 연동 검증 135개가 전부
# 통과하는 상태였다. 로직은 멀쩡하고 연출이 물고 있었다는 뜻이다.
#
# ## 무엇을 보나
#
# 1. **끝나는가** — 제한 시간 안에 `stage_completed` 또는 `stage_failed` 가 나오는가
# 2. **진행하는가** — 진행 지문(사이클·생존 수·총 HP·행동 유닛)이 변하는가.
#    끝나지 않아도 **멈춘 순간**을 잡는 것이 목적이다
# 3. **보이는가** — 살아 있는 유닛의 몸이 화면에 있는가.
#    죽지 않은 적이 숨겨지면 "안 보이는데 계속 때리는" 상태가 된다
# 4. **시간이 돌아왔는가** — `Engine.time_scale` 이 1.0 인가.
#    히트스톱(0.0001)·격파 슬로모션(0.15) 이 복구되지 않으면 게임이 굳는다 (#495)
#
# 실행:
#   godot --headless --path . res://tests/combat/VerifyBattleSoak.tscn

## 전투 하나에 허용하는 실제 시간(초). 넉넉히 준다 — 느려서 실패하면 안 된다.
const TIMEOUT_SECONDS: float = 150.0

## 진행 지문이 이만큼 변하지 않으면 멈춘 것으로 본다(초).
## 연출 한 조각이 길어야 1초 남짓이므로 그 몇 배를 준다.
const STALL_SECONDS: float = 12.0

## 지문을 재는 간격(초).
const SAMPLE_SECONDS: float = 0.5

var _failures: Array[String] = []
var _checks: int = 0
var _finished: bool = false
var _outcome: String = ""


func _ready() -> void:
	await get_tree().process_frame

	EventBus.stage_completed.connect(func(_n): _finish("completed"))
	EventBus.stage_failed.connect(func(_n): _finish("failed"))

	await _soak()

	if _failures.is_empty():
		print("PASS: 전투 소크 검증 %d개 통과 (결과 %s)" % [_checks, _outcome])
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: 전투 소크 %d/%d 실패" % [_failures.size(), _checks])
		get_tree().quit(1)


func _finish(outcome: String) -> void:
	if _finished:
		return
	_finished = true
	_outcome = outcome


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("실패: " + message)


# 웨이브가 가장 많은 스테이지를 고른다. 웨이브 전환이 멈춤이 가장 잘 나는 자리다.
func _pick_stage() -> StringName:
	var best: StringName = &""
	var best_waves := 0
	for id in StageDatabase.get_ordered_ids():
		var stage: StageData = StageDatabase.get_stage(id)
		if stage == null:
			continue
		var waves := TurnStageEncounter.waves_for(stage).size()
		if waves > best_waves:
			best_waves = waves
			best = id
	return best


func _soak() -> void:
	var target := _pick_stage()
	_expect(not String(target).is_empty(), "굴려 볼 스테이지를 찾아야 한다")
	if String(target).is_empty():
		return

	# **연출을 켠다.** 이 테스트의 전부다.
	var tuning := TurnCombatConfig.tuning
	var was_enabled: bool = tuning.presentation_enabled
	var was_speed: float = tuning.presentation_speed
	tuning.presentation_enabled = true
	# 실제 시간을 줄이려고 빠르게 돌린다. 멈춤은 배속과 무관하게 재현된다.
	tuning.presentation_speed = 3.0

	StageSystem.request_stage(target)

	var scene: PackedScene = load("res://stage/turn/TurnBattle.tscn")
	var node := scene.instantiate()
	node.set("use_stage", true)
	node.set("battle_seed", 20260914)
	add_child(node)

	# **자동 전투를 `await` 전에 켠다.**
	#
	# `auto_battle` 은 턴이 **시작될 때만** 확인된다(`TurnBattleManager` 416~426).
	# 아군 턴이 `AWAITING_INPUT` 로 들어간 뒤에 켜면 재개되지 않고 입력을 계속 기다린다
	# — 입력 제한시간이 없는 것이 설계다. 프레임을 넘기고 켜면 첫 아군 턴을 놓쳐
	# **멈춤이 아닌 것을 멈춤으로 잡는다**(처음 돌렸을 때 실제로 그랬다).
	var battle = node.get("battle")
	if battle != null:
		battle.auto_battle = true

	await get_tree().process_frame
	await get_tree().process_frame

	battle = node.get("battle")
	_expect(battle != null, "전투가 만들어져야 한다")
	if battle != null:
		battle.auto_battle = true
	if battle == null:
		_restore(tuning, was_enabled, was_speed)
		node.queue_free()
		return

	var elapsed := 0.0
	var since_change := 0.0
	var last_print := ""
	var stalled := false

	while not _finished and elapsed < TIMEOUT_SECONDS:
		await get_tree().create_timer(SAMPLE_SECONDS, true, false, true).timeout
		elapsed += SAMPLE_SECONDS

		# 아군 턴 입력 대기는 **멈춤이 아니다**(입력 제한시간이 없는 것이 설계다).
		# 자동 전투가 켜져 있어도 `auto_battle` 은 턴이 시작될 때만 확인되므로,
		# 이미 대기로 들어간 턴은 테스트가 대신 굴려 준다.
		if battle.phase == TurnBattleManager.Phase.AWAITING_INPUT and battle.auto_battle:
			battle.advance()
			node.call("_play")

		var print_now := _fingerprint(battle)
		if print_now == last_print:
			since_change += SAMPLE_SECONDS
			if since_change >= STALL_SECONDS:
				stalled = true
				break
		else:
			since_change = 0.0
			last_print = print_now

	_expect(not stalled,
		"전투가 %.0f초 동안 진행하지 않았다 — 멈춤이다.\n%s"
		% [STALL_SECONDS, _dump(battle, node)])
	_expect(_finished,
		"전투가 %.0f초 안에 끝나야 한다 (결과 신호가 없었다).\n%s"
		% [TIMEOUT_SECONDS, _dump(battle, node)])

	# 살아 있는데 화면에서 사라진 유닛이 없어야 한다.
	_check_alive_units_visible(battle, node)

	# 히트스톱·슬로모션이 복구됐는가 (#495).
	_expect(is_equal_approx(Engine.time_scale, 1.0),
		"Engine.time_scale 이 1.0 으로 복구돼야 한다 (실제 %.5f)" % Engine.time_scale)

	_restore(tuning, was_enabled, was_speed)
	node.queue_free()
	await get_tree().process_frame


func _restore(tuning, enabled: bool, speed: float) -> void:
	tuning.presentation_enabled = enabled
	tuning.presentation_speed = speed
	Engine.time_scale = 1.0


# 전투가 "움직이고 있는가" 를 한 줄로 요약한다. 이 값이 안 변하면 멈춘 것이다.
func _fingerprint(battle) -> String:
	var alive_allies := 0
	var alive_enemies := 0
	var total_hp := 0
	for unit in battle.units:
		if unit.alive:
			if unit.is_ally():
				alive_allies += 1
			else:
				alive_enemies += 1
			total_hp += unit.current_hp
	var active := "-"
	if battle.active_unit != null:
		active = String(battle.active_unit.unit_id)
	var cycle := 0
	if battle.timeline != null:
		cycle = battle.timeline.current_cycle()
	var queued := 0
	if battle.presentation != null:
		queued = battle.presentation.events.size()
	return "c%d a%d e%d hp%d u%s q%d" % [cycle, alive_allies, alive_enemies,
		total_hp, active, queued]


# 살아 있는 유닛의 몸이 화면에 있어야 한다.
#
# 죽지 않았는데 숨겨지면 "적이 안 보이는데 데미지 숫자만 뜨는" 상태가 된다.
func _check_alive_units_visible(battle, node) -> void:
	var shapes: Dictionary = node.get("_shapes")
	if shapes == null:
		return
	for unit in battle.units:
		if not unit.alive:
			continue
		var shape = shapes.get(unit.unit_id)
		_expect(shape != null,
			"살아 있는 %s 의 몸이 있어야 한다" % unit.unit_id)
		if shape == null:
			continue
		_expect(shape.visible,
			"살아 있는 %s 가 화면에 보여야 한다 — 숨겨지면 때릴 수는 있는데 안 보인다"
			% unit.unit_id)
		_expect(shape.modulate.a > 0.05,
			"살아 있는 %s 가 투명하면 안 된다 (알파 %.2f)" % [unit.unit_id, shape.modulate.a])


# 실패했을 때 **무엇을 보고 있었는지** 남긴다. 이게 없으면 재현부터 다시 해야 한다.
func _dump(battle, node) -> String:
	var lines: Array[String] = []
	lines.append("  time_scale=%.5f" % Engine.time_scale)
	if battle.presentation != null:
		lines.append("  presentation: enabled=%s speed=%.2f queued=%d"
			% [battle.presentation.enabled, battle.presentation.speed,
				battle.presentation.events.size()])
	if battle.timeline != null:
		lines.append("  cycle=%d" % battle.timeline.current_cycle())
	var active := "-"
	if battle.active_unit != null:
		active = "%s(ally=%s alive=%s)" % [battle.active_unit.unit_id,
			battle.active_unit.is_ally(), battle.active_unit.alive]
	lines.append("  active_unit=%s" % active)
	lines.append("  phase=%s auto_battle=%s is_over=%s"
		% [battle.phase, battle.auto_battle, battle.is_over()])
	lines.append("  node: _stage=%s _outcome_reported=%s _playing=%s"
		% [node.get("_stage"), node.get("_outcome_reported"), node.get("_playing")])

	var shapes: Dictionary = node.get("_shapes")
	for unit in battle.units:
		var shape = shapes.get(unit.unit_id) if shapes != null else null
		var seen := "없음"
		if shape != null:
			seen = "visible=%s alpha=%.2f" % [shape.visible, shape.modulate.a]
		lines.append("  %s ally=%s alive=%s hp=%d %s"
			% [unit.unit_id, unit.is_ally(), unit.alive, unit.current_hp, seen])
	return "\n".join(lines)

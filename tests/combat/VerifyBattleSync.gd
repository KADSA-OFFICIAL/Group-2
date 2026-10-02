extends Node

# 전투 로직과 연출이 어긋나지 않는지, 오의가 어느 경로로든 컷인과 함께 나오는지 검증 (#542).
#
# 플레이 영상에서 본 것: 1웨이브에서 스킬을 눌러도 반응이 없다가 갑자기 "웨이브 2/2" 로 바뀌고,
# 파티 카드가 사라지고(로직상 전멸), 1웨이브 적 그림은 그대로 서 있고, 보스는 보이지 않았다.
# 다시 출격하면 그 상태로 멈춰 있었다. 오의도 나오지 않았다.
#
#   1) 턴 단위 진행 — `step_by_turn` 이면 `advance()` 한 번이 한 턴만 진행한다.
#   2) 오의 컷인 — 자동 전투 · 스킬 목록(`act`) · 초상 배지(`use_ultimate`) 어느 경로든
#      오의 시전 바로 앞에 `ULTIMATE_CUTIN` 이 **한 번** 있다.
#   3) 자동 전환 — 아군 턴 도중 자동을 켜면 그 아군의 턴을 건너뛰지 않고 대신 진행한다.
#   4) 화면 재시작 — 로직이 앞서 끝난 전투를 재시작해도 옛 전투의 승패 신호가 나오지 않고,
#      새 전투가 진행된다. 웨이브가 바뀌면 지난 웨이브의 몸이 남지 않는다.
#
# 실행:
#   godot --headless --path . res://tests/combat/VerifyBattleSync.tscn

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_verify_step_by_turn()
	_verify_ultimate_cutins_auto()
	_verify_ultimate_cutin_manual()
	_verify_auto_act()
	await _verify_screen_restart()

	if _failures.is_empty():
		print("PASS: 전투 동기화 검증 %d개 통과" % _checks)
		get_tree().quit(0)
	else:
		for f in _failures:
			push_error(f)
		print("FAIL: 전투 동기화 %d/%d 실패" % [_failures.size(), _checks])
		get_tree().quit(1)


func _expect(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append("실패: " + message)


# 연출 큐를 켠 채(로직만) 스테이지 전투를 만든다. 화면 없이 큐에 무엇이 쌓이는지 본다.
func _make_battle(stage_id: StringName, seed: int, auto: bool, step: bool = false) -> TurnBattleManager:
	var stage := StageDatabase.get_stage(stage_id)
	var waves := []
	for entry in TurnStageEncounter.waves_for(stage):
		waves.append(entry["enemies"])
	var party: Array[CharacterData] = []
	for id in [&"mina", &"taehee", &"seola", &"arin"]:
		party.append(CharacterDatabase.get_character(id))
	var b := TurnBattleManager.new()
	b.pending_waves = waves.slice(1)
	b.auto_battle = auto
	# `begin_battle()` 이 바로 `advance()` 를 부르므로 진행 방식은 그 전에 정한다.
	b.step_by_turn = step
	b.start(party, waves[0], false, seed)
	# 연출을 켠다 — 큐에 쌓인 것을 읽어야 한다.
	b.presentation.enabled = true
	b.use_prep("energy")
	b.begin_battle()
	return b


func _drain(b: TurnBattleManager) -> Array:
	var out := []
	while not b.presentation.is_empty():
		out.append(b.presentation.pop())
	return out


func _verify_step_by_turn() -> void:
	var b := _make_battle(&"stage_1_2", 7, true, true)
	var calls := 0
	var max_jump := 0
	while not b.is_over() and calls < 2000:
		var before := int(b.stats["turns"])
		b.advance()
		_drain(b)
		max_jump = maxi(max_jump, int(b.stats["turns"]) - before)
		calls += 1
	_expect(b.is_over(), "턴 단위 진행으로도 전투가 끝나야 한다")
	_expect(max_jump <= 1, "턴 단위 진행이면 advance() 한 번이 한 턴만 진행해야 한다 (최대 %d턴)" % max_jump)
	_expect(calls > 10, "턴 단위 진행이면 advance() 를 여러 번 불러야 끝난다 (%d번)" % calls)


# 자동 전투: 아군 오의 시전마다 바로 앞에 같은 유닛의 컷인이 하나.
func _verify_ultimate_cutins_auto() -> void:
	var ult_casts := 0
	var cutins := 0
	var paired := 0
	for seed in [3, 11, 29]:
		var b := _make_battle(&"stage_1_3", seed, true)
		b.advance()
		var events := _drain(b)
		var last_cutin_unit: TurnUnit = null
		for entry in events:
			var event: int = entry["event"]
			var data: Dictionary = entry["data"]
			if event == PresentationQueue.Event.ULTIMATE_CUTIN:
				cutins += 1
				last_cutin_unit = data.get("unit")
			elif event == PresentationQueue.Event.SKILL_CAST:
				var skill: SkillData = data.get("skill")
				var unit: TurnUnit = data.get("unit")
				if skill != null and unit != null and unit.is_ally() and skill.is_turn_ultimate():
					ult_casts += 1
					if last_cutin_unit == unit:
						paired += 1
				last_cutin_unit = null
	_expect(ult_casts > 0, "자동 전투에서 오의가 나와야 한다")
	_expect(paired == ult_casts, "자동 전투의 오의 %d번 모두 컷인이 앞서야 한다 (짝 %d)" % [ult_casts, paired])
	_expect(cutins == ult_casts, "컷인 수(%d)와 오의 수(%d)가 같아야 한다(중복 없음)" % [cutins, ult_casts])


# 수동: 스킬 목록(act)과 초상 배지(use_ultimate) 모두 컷인이 정확히 하나.
func _verify_ultimate_cutin_manual() -> void:
	for path in ["act", "badge"]:
		var b := _make_battle(&"stage_1_1", 5, false)
		b.advance()
		_drain(b)
		_expect(b.phase == TurnBattleManager.Phase.AWAITING_INPUT, "%s: 아군 입력 대기에 들어와야 한다" % path)
		var unit := b.active_unit
		var ult := unit.character.get_turn_ultimate()
		unit.energy = unit.get_energy_max()
		var result: Dictionary
		if path == "act":
			result = b.act(ult, null if not ult.needs_target_pick() else b.ranks.valid_targets(unit, ult)[0])
		else:
			result = b.use_ultimate(unit)
		_expect(bool(result.get("ok", false)), "%s: 게이지가 차 있으면 오의가 나가야 한다: %s" % [path, result.get("reason", "")])
		var cutins := 0
		for entry in _drain(b):
			if int(entry["event"]) == PresentationQueue.Event.ULTIMATE_CUTIN:
				cutins += 1
		_expect(cutins == 1, "%s 로 쓴 오의에 컷인이 한 번 나와야 한다 (%d번)" % [path, cutins])

	# 게이지가 모자라면 컷인도 없다.
	var b2 := _make_battle(&"stage_1_1", 5, false)
	b2.advance()
	_drain(b2)
	var u2 := b2.active_unit
	u2.energy = 0
	var r2 := b2.act(u2.character.get_turn_ultimate(), null)
	var stray := 0
	for entry in _drain(b2):
		if int(entry["event"]) == PresentationQueue.Event.ULTIMATE_CUTIN:
			stray += 1
	_expect(not bool(r2.get("ok", true)) and stray == 0, "게이지가 모자란 오의는 실패하고 컷인도 없어야 한다")


func _verify_auto_act() -> void:
	var b := _make_battle(&"stage_1_1", 5, false, true)
	while b.phase != TurnBattleManager.Phase.AWAITING_INPUT and not b.is_over():
		b.advance()
	var unit := b.active_unit
	var log_before := b.battle_log.size()
	b.auto_battle = true
	b.auto_act()
	var acted := false
	for i in range(log_before, b.battle_log.size()):
		if b.battle_log[i].begins_with(unit.display_name + " 이(가) 「"):
			acted = true
	_expect(acted, "아군 턴 도중 자동을 켜면 그 아군(%s)이 행동해야 한다(건너뛰지 않는다)" % unit.display_name)


# 화면: 로직이 앞서 끝난 전투를 재시작해도 옛 전투의 결과가 새 전투 위로 나오지 않는다.
func _verify_screen_restart() -> void:
	var tuning := TurnCombatConfig.tuning
	var was_enabled: bool = tuning.presentation_enabled
	var was_speed: float = tuning.presentation_speed
	tuning.presentation_enabled = true
	tuning.presentation_speed = 3.0

	var outcomes := []
	var on_done := func(n): outcomes.append(n)
	EventBus.stage_completed.connect(on_done)
	EventBus.stage_failed.connect(on_done)

	StageSystem.request_stage(&"stage_test")
	var node: Node = load("res://stage/turn/TurnBattle.tscn").instantiate()
	node.set("use_stage", true)
	node.set("battle_seed", 4242)
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame

	# 예전 동작을 흉내 낸다: 한 번에 끝까지 돌려 로직을 연출보다 멀리 앞서게 만든다.
	var old = node.get("battle")
	old.step_by_turn = false
	old.auto_battle = true
	if old.phase == TurnBattleManager.Phase.AWAITING_INPUT:
		old.advance()
		node.call("_play")
	_expect(old.is_over(), "준비: 옛 전투의 로직이 앞서 끝나 있어야 한다")
	await get_tree().create_timer(0.5, true, false, true).timeout

	# 재시작(출격·재도전이 부르는 것과 같다).
	node.call("_restart")
	var fresh = node.get("battle")
	_expect(fresh != old, "재시작하면 새 전투가 만들어져야 한다")
	_expect(fresh.step_by_turn, "화면의 전투는 턴 단위로 진행해야 한다")
	fresh.auto_battle = true
	if fresh.phase == TurnBattleManager.Phase.AWAITING_INPUT:
		fresh.auto_act()
		node.call("_play")

	var turns_start := int(fresh.stats["turns"])
	var stale_seen := false
	for i in range(24):
		await get_tree().create_timer(0.5, true, false, true).timeout
		if fresh.phase == TurnBattleManager.Phase.AWAITING_INPUT and not bool(node.get("_playing")):
			fresh.auto_act()
			node.call("_play")
		# 지난 웨이브의 몸이 남지 않는다: 몸이 있는 유닛은 모두 지금 전투에 있다.
		var shapes: Dictionary = node.get("_shapes")
		var present := {}
		for unit in fresh.units:
			present[unit.unit_id] = true
		for id in shapes:
			if not present.has(id) and fresh.presentation.is_empty():
				stale_seen = true

	_expect(outcomes.is_empty(), "재시작한 뒤 옛 전투의 승패 신호가 나오면 안 된다: %s" % str(outcomes))
	_expect(int(fresh.stats["turns"]) > turns_start, "재시작한 새 전투가 진행되어야 한다")
	_expect(not stale_seen, "연출이 따라잡은 시점에는 지난 웨이브의 몸이 남아 있으면 안 된다")

	EventBus.stage_completed.disconnect(on_done)
	EventBus.stage_failed.disconnect(on_done)
	tuning.presentation_enabled = was_enabled
	tuning.presentation_speed = was_speed
	node.queue_free()
	await get_tree().process_frame

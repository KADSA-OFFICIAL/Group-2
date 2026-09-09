extends Node

# 저작된 스테이지가 **턴제 조우로 풀리는지** 검증 (#472).
#
# 왜 필요한가 (#438 의 교훈과 같다): 번역 코드(`TurnStageEncounter`)와 웨이브 시스템이
# 다 만들어져 있어도, **저작된 스테이지에서 출발해 적까지 풀어 보지 않으면** 연결이
# 끊긴 것을 알 수 없다. 적 씬에서 `EnemyData` 를 못 꺼내면 그 웨이브는 조용히 비워지고,
# 화면에는 웨이브 번호만 올라가면서 아무 일도 일어나지 않는다.
#
# 그래서 대응표를 검사하지 않고 **`StageDatabase` 에서 출발해** 적 정의까지 풀어 본다.
#
# 실행:
#   godot --headless --path . res://tests/combat/VerifyTurnStageBattle.tscn

var _failures: Array[String] = []
var _checks: int = 0

## 전투 중 관측한 EventBus 신호.
var _seen_stage_started: Array[String] = []
var _seen_completed: Array[String] = []
var _seen_failed: Array[String] = []
var _seen_waves: Array[int] = []


func _ready() -> void:
	await get_tree().process_frame

	EventBus.stage_started.connect(func(name_text): _seen_stage_started.append(String(name_text)))
	EventBus.stage_completed.connect(func(name_text): _seen_completed.append(String(name_text)))
	EventBus.stage_failed.connect(func(name_text): _seen_failed.append(String(name_text)))
	EventBus.stage_wave_started.connect(
		func(_name_text, index, _total, _wave): _seen_waves.append(int(index)))

	_test_enemy_scene_resolution()
	_test_authored_stages_resolve()
	_test_wave_sequencing()
	_test_wave_preserves_party_state()
	await _test_stage_battle_lifecycle()

	if _failures.is_empty():
		print("PASS: 턴제 스테이지 연동 검증 %d개 통과" % _checks)
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: %d/%d 실패" % [_failures.size(), _checks])
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("실패: " + message)


# ===== 적 씬 -> EnemyData =====

func _test_enemy_scene_resolution() -> void:
	# 저작된 적 씬 전부가 정의를 내놓아야 한다. 하나라도 못 풀면 그 적이 나오는
	# 웨이브가 통째로 비워진다.
	var scenes := {
		"VelociraptorBeastfolk": "res://entities/enemies/VelociraptorBeastfolk.tscn",
		"VelociraptorBeastfolk2": "res://entities/enemies/VelociraptorBeastfolk2.tscn",
		"MammothBeastfolk": "res://entities/enemies/MammothBeastfolk.tscn",
		"Seoa": "res://entities/enemies/Seoa.tscn",
		"MammothBoss": "res://entities/enemies/MammothBoss.tscn",
		"PterosaurQueen": "res://entities/enemies/PterosaurQueen.tscn",
	}

	for label in scenes:
		var path: String = scenes[label]
		_expect(ResourceLoader.exists(path), "%s 씬이 있어야 한다: %s" % [label, path])
		if not ResourceLoader.exists(path):
			continue

		var scene: PackedScene = load(path)
		var data := TurnStageEncounter.enemy_data_of(scene)
		_expect(data != null,
			"%s 씬에서 EnemyData 를 꺼낼 수 있어야 한다 — 못 꺼내면 그 웨이브가 비워진다" % label)
		if data == null:
			continue

		_expect(not String(data.enemy_id).is_empty(),
			"%s 의 enemy_id 가 비어 있으면 안 된다" % label)
		_expect(data.validate_turn().is_empty(),
			"%s 의 턴제 저작이 유효해야 한다: %s" % [label, ", ".join(data.validate_turn())])
		_expect(not data.turn_skills.is_empty(),
			"%s 에 턴제 행동표가 있어야 한다" % label)

	# 캐시가 같은 값을 돌려줘야 한다 (두 번째 호출이 null 이 되면 웨이브가 비워진다).
	var first := TurnStageEncounter.enemy_data_of(
		load("res://entities/enemies/VelociraptorBeastfolk.tscn"))
	var second := TurnStageEncounter.enemy_data_of(
		load("res://entities/enemies/VelociraptorBeastfolk.tscn"))
	_expect(first == second, "적 씬 해석 캐시가 같은 정의를 돌려줘야 한다")

	_expect(TurnStageEncounter.enemy_data_of(null) == null, "null 씬은 null 이어야 한다")


# ===== 저작된 스테이지 =====

func _test_authored_stages_resolve() -> void:
	var ids := StageDatabase.get_ordered_ids()
	_expect(ids.size() >= 5, "저작된 스테이지가 5개 이상이어야 한다 (실제 %d)" % ids.size())

	for id in ids:
		var stage: StageData = StageDatabase.get_stage(id)
		_expect(stage != null, "%s 를 조회할 수 있어야 한다" % id)
		if stage == null:
			continue

		var waves := TurnStageEncounter.waves_for(stage)
		_expect(not waves.is_empty(),
			"%s 가 최소 1개 웨이브로 풀려야 한다 — 0개면 전투를 열 수 없다" % id)

		var total_enemies := 0
		for entry in waves:
			var enemies: Array[EnemyData] = entry["enemies"]
			_expect(not enemies.is_empty(),
				"%s 의 웨이브에 적이 있어야 한다 (빈 웨이브는 버려져야 한다)" % id)
			_expect(enemies.size() <= TurnCombat.ENEMY_RANK_COUNT,
				"%s 의 웨이브 적이 랭크 수(%d)를 넘으면 안 된다 (실제 %d)"
					% [id, TurnCombat.ENEMY_RANK_COUNT, enemies.size()])
			for enemy in enemies:
				_expect(enemy != null, "%s 의 웨이브에 빈 적이 있으면 안 된다" % id)
			total_enemies += enemies.size()

		# 저작된 웨이브 수와 풀린 웨이브 수가 크게 다르면 무언가 버려진 것이다.
		if not stage.waves.is_empty():
			_expect(waves.size() == stage.waves.size(),
				"%s 의 웨이브 %d개가 전부 풀려야 한다 (실제 %d) — 차이가 있으면 적을 못 뽑은 웨이브가 있다"
					% [id, stage.waves.size(), waves.size()])

		print("  %s (%s) → %d웨이브 / 적 %d체%s"
			% [id, stage.display_name, waves.size(), total_enemies,
				"  [점령 조건 있음 → 전멸로 대체]" if stage.requires_capture() else ""])


# ===== 웨이브 진행 =====

func _test_wave_sequencing() -> void:
	var party := _party([&"mina", &"harang", &"seola", &"gangji"])
	var wave_a := _enemies([&"velociraptor_beastfolk"])
	var wave_b := _enemies([&"velociraptor_beastfolk_2"])
	var wave_c := _enemies([&"mammoth_beastfolk"])

	var announced: Array[int] = []

	var battle := TurnBattleManager.new()
	battle.auto_battle = true
	battle.cycle_limit = 60
	battle.pending_waves = [wave_b, wave_c]
	battle.on_wave_started = func(index: int, _total: int) -> void: announced.append(index)
	battle.start(party, wave_a, 0, 5150)
	battle.presentation.enabled = false

	_expect(battle.wave_total == 3, "전체 웨이브 수가 3이어야 한다 (실제 %d)" % battle.wave_total)
	_expect(battle.wave_index == 0, "첫 웨이브는 0번이어야 한다")
	_expect(battle.enemies().size() == 1, "첫 웨이브의 적만 놓여야 한다")

	battle.begin_battle()
	var guard := 0
	while not battle.is_over() and guard < 4000:
		guard += 1
		battle.advance()

	_expect(battle.is_over(), "웨이브 전투가 끝나야 한다 (진행 %d회)" % guard)
	_expect(battle.phase == TurnBattleManager.Phase.VICTORY,
		"3웨이브를 전부 정리하면 승리여야 한다 (실제 %s)"
			% TurnBattleManager.Phase.keys()[battle.phase])
	_expect(battle.wave_index == 2,
		"마지막 웨이브 번호는 2여야 한다 (실제 %d)" % battle.wave_index)
	_expect(announced == [0, 1, 2],
		"웨이브가 0 → 1 → 2 순으로 알려져야 한다 (실제 %s)" % str(announced))

	var summary := battle.result_summary()
	_expect(int(summary["waves"]) == 3 and int(summary["wave_total"]) == 3,
		"결과 요약에 웨이브 3/3 이 실려야 한다")

	# **중간 웨이브에서 승리 신호가 나가면 안 된다.** 나가면 결과 화면이 웨이브마다 뜬다.
	_expect(_seen_completed.is_empty(),
		"매니저만 돌린 전투는 stage_completed 를 쏘지 않아야 한다 (화면이 쏜다)")


func _test_wave_preserves_party_state() -> void:
	# 웨이브 사이에 아군 HP·오의 게이지가 **이어져야** 한다. 회복시켜 주면 웨이브가
	# 그냥 별개 전투 여러 개가 되고, 웨이브 구조의 의미가 사라진다.
	#
	# 스냅샷을 루프에서 폴링하지 않고 `on_wave_started` 콜백에서 뜨는 이유:
	# 자동 전투에서는 `advance()` 한 번이 전투 전체를 굴린다(입력 대기가 없으므로).
	# 밖에서 관측할 틈이 없다.
	var party := _party([&"mina", &"harang"])
	var snapshot: Dictionary = {}
	var enemy_ids_at_wave2: Array[StringName] = []

	var battle := TurnBattleManager.new()
	battle.auto_battle = true
	battle.cycle_limit = 60
	battle.pending_waves = [_enemies([&"velociraptor_beastfolk_2"])]
	battle.on_wave_started = func(index: int, _total: int) -> void:
		if index != 1:
			return
		for unit in battle.allies():
			snapshot[unit.unit_id] = [unit.current_hp, unit.energy, unit.get_max_hp()]
		for unit in battle.units:
			if unit.is_enemy():
				enemy_ids_at_wave2.append(unit.unit_id)
	battle.start(party, _enemies([&"velociraptor_beastfolk"]), 0, 8899)
	battle.presentation.enabled = false
	battle.begin_battle()

	_expect(battle.is_over(), "웨이브 전투가 끝나야 한다")
	_expect(not snapshot.is_empty(),
		"두 번째 웨이브에 도달해야 한다 (첫 웨이브에서 패배했다면 시드를 다시 잡을 것)")
	if snapshot.is_empty():
		return

	# 두 번째 웨이브가 시작될 때 아군이 **1웨이브의 흔적을 갖고 있어야** 한다.
	# HP 가 전원 만피이고 오의가 전원 0이면 초기화된 것이다.
	var carried := false
	for id in snapshot:
		var before: Array = snapshot[id]
		if int(before[0]) < int(before[2]) or int(before[1]) > 0:
			carried = true
	_expect(carried,
		"웨이브가 넘어갈 때 아군의 HP·오의가 이어져야 한다 — 초기화되면 웨이브가 별개 전투가 된다")

	# 적은 새 유닛으로 교체되어야 한다. id 가 겹치면 타임라인이 앞 웨이브의 AV 를 쓴다.
	_expect(not enemy_ids_at_wave2.is_empty(), "두 번째 웨이브에 적이 놓여야 한다")
	for id in enemy_ids_at_wave2:
		_expect(String(id).contains("#w"),
			"두 번째 웨이브의 적 id 에 웨이브 번호가 들어가야 한다: %s" % id)


# ===== 전투 화면 연동 =====

# 실제 `TurnBattle` 씬을 띄워 스테이지 연동 전체를 굴린다.
#
# 여기서만 확인할 수 있는 것: `stage_completed` 가 나가고 **`stage_started` 는 나가지 않는다**.
# 후자가 나가면 `TutorialSystem` 이 활성화되고, 그 단계 조건이 대시·처형 같은 실시간
# 행동이라 턴제에서는 영원히 충족되지 않아 **진행 불가로 멈춘다** (#472 Consequences 1).
func _test_stage_battle_lifecycle() -> void:
	# 연출을 끄면 큐가 비어 재생 대기가 사라지고 전투가 즉시 끝난다.
	var was_enabled := TurnCombatConfig.tuning.presentation_enabled
	TurnCombatConfig.tuning.presentation_enabled = false

	_seen_stage_started.clear()
	_seen_completed.clear()
	_seen_failed.clear()
	_seen_waves.clear()

	# 웨이브가 여러 개인 스테이지를 고른다 — 웨이브 신호까지 확인할 수 있다.
	var target: StringName = &""
	for id in StageDatabase.get_ordered_ids():
		var stage: StageData = StageDatabase.get_stage(id)
		if stage != null and TurnStageEncounter.waves_for(stage).size() >= 1:
			target = id
			break
	_expect(not String(target).is_empty(), "연동을 확인할 스테이지를 찾아야 한다")
	if String(target).is_empty():
		TurnCombatConfig.tuning.presentation_enabled = was_enabled
		return

	StageSystem.request_stage(target)
	_expect(StageSystem.get_current_id() == target,
		"StageSystem 이 요청한 스테이지를 현재 스테이지로 잡아야 한다")

	var scene: PackedScene = load("res://stage/turn/TurnBattle.tscn")
	_expect(scene != null, "TurnBattle.tscn 을 로드할 수 있어야 한다")
	if scene == null:
		TurnCombatConfig.tuning.presentation_enabled = was_enabled
		return

	var node := scene.instantiate()
	node.set("use_stage", true)
	node.set("battle_seed", 20260909)
	add_child(node)

	await get_tree().process_frame
	await get_tree().process_frame

	var battle = node.get("battle")
	_expect(battle != null, "전투 화면이 전투를 만들어야 한다")
	if battle == null:
		node.queue_free()
		TurnCombatConfig.tuning.presentation_enabled = was_enabled
		return

	_expect(battle.enemies().size() >= 1,
		"스테이지에서 뽑은 적이 놓여야 한다 (실제 %d체)" % battle.enemies().size())
	_expect(battle.allies().size() >= 1,
		"파티가 놓여야 한다 (실제 %d명)" % battle.allies().size())
	_expect(not _seen_waves.is_empty(),
		"첫 웨이브에 stage_wave_started 가 나가야 한다")

	# 강제 파티가 저작된 스테이지면 그 파티가 적용되어야 한다.
	var stage: StageData = StageDatabase.get_stage(target)
	if stage != null and not stage.forced_party.is_empty():
		var names: Array[StringName] = []
		for unit in battle.allies():
			if unit.character != null:
				names.append(unit.character.character_id)
		for forced in stage.forced_party:
			_expect(names.has(forced),
				"강제 파티 %s 가 편성되어야 한다 (실제 %s)" % [forced, str(names)])

	# 자동 전투로 끝까지 굴린다.
	battle.auto_battle = true
	battle.cycle_limit = 60
	var guard := 0
	while not battle.is_over() and guard < 4000:
		guard += 1
		battle.advance()

	_expect(battle.is_over(), "스테이지 전투가 끝나야 한다 (진행 %d회)" % guard)

	# 승패 신호는 화면이 쏜다. 매니저를 직접 돌렸으므로 화면의 `_play()` 를 한 번 태운다.
	node.call("_show_result")
	await get_tree().process_frame

	var reported := _seen_completed.size() + _seen_failed.size()
	_expect(reported == 1,
		"승패 신호가 정확히 한 번 나가야 한다 (실제 %d회) — 여러 번이면 결과 화면이 겹친다"
			% reported)
	_expect(_seen_completed.has(String(target)) or _seen_failed.has(String(target)),
		"승패 신호에 스테이지 id 가 실려야 한다 (%s)" % target)

	# **가장 중요한 검사.**
	_expect(_seen_stage_started.is_empty(),
		"턴제 전투는 stage_started 를 쏘지 않아야 한다 — 쏘면 실시간 튜토리얼이 활성화되어 진행 불가로 멈춘다 (실제 %s)"
			% str(_seen_stage_started))
	_expect(not TutorialSystem.is_active(),
		"턴제 전투에서 실시간 튜토리얼이 활성화되면 안 된다")

	# 같은 신호를 두 번 쏘지 않는다.
	node.call("_show_result")
	await get_tree().process_frame
	_expect(_seen_completed.size() + _seen_failed.size() == 1,
		"승패는 한 번만 알려야 한다 (결과 화면이 두 번 뜨는 것을 막는다)")

	print("  스테이지 연동: %s → %d웨이브 알림, 승패 %s"
		% [target, _seen_waves.size(),
			"승리" if not _seen_completed.is_empty() else "패배"])

	# 종료 전에 노드를 실제로 치운다 — `queue_free()` 직후 quit 하면 Godot 이
	# "resources still in use" 를 ERROR 로 찍어 검증 실패처럼 보인다.
	node.queue_free()
	await get_tree().process_frame
	TurnCombatConfig.tuning.presentation_enabled = was_enabled


# ===== 헬퍼 =====

func _party(ids: Array) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for id in ids:
		var character: CharacterData = CharacterDatabase.get_character(id)
		if character != null:
			out.append(character)
	return out


func _enemies(ids: Array) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for id in ids:
		var enemy: EnemyData = EnemyDatabase.get_enemy(id)
		if enemy != null:
			out.append(enemy)
	return out

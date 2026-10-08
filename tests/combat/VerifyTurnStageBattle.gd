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
	_test_level_bonus_units()
	_test_level_bonus_manager()
	_test_stage_level_bonus_field()
	_test_chapter2_stages()
	_test_chapter3_stages()
	_test_themed_enemies()
	await _test_stage_battle_lifecycle()
	await _test_stage_level_bonus_reaches_battle()

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
		# 테마 적(#568) — 못 꺼내면 2-3 · 하늘 스테이지의 웨이브가 통째로 비워진다.
		"WaterDragonBeastfolk": "res://entities/enemies/WaterDragonBeastfolk.tscn",
		"WaterDragonChief": "res://entities/enemies/WaterDragonChief.tscn",
		"PterosaurBeastfolk": "res://entities/enemies/PterosaurBeastfolk.tscn",
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

	_check_hud_below_meta_screens(node)

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


# ===== 스테이지별 적 레벨 보정 (#565) =====
#
# **이 검사들이 잡는 것**: 보정이 한 곳에서만 빠지는 회귀다. 적 유닛을 만드는 곳이 둘
# (`start()` 1파, `_advance_wave()` 2파 이후)이고, 파티 레벨 계산이 또 따로 있다. 한 곳이
# 빠지면 **전투는 정상으로 돌아가는데** 2파 적만 보정을 못 받거나 방어 계수가 어긋난다.

func _test_level_bonus_units() -> void:
	# 보정 0 은 기존과 같아야 한다 — 이 필드가 없는 스테이지가 전부 이쪽이다.
	for id in EnemyDatabase.get_all_ids():
		var data: EnemyData = EnemyDatabase.get_enemy(id)
		if data == null:
			continue
		var plain := TurnUnit.from_enemy(data, 1)
		var zero := TurnUnit.from_enemy(data, 1, "", 0)
		_expect(plain.level == data.turn_level and zero.level == data.turn_level,
			"%s: 보정 0 이면 유닛 레벨이 turn_level(%d)과 같아야 한다 (실제 %d)"
				% [id, data.turn_level, zero.level])
		_expect(zero.get_max_hp() == data.get_turn_hp() and plain.get_max_hp() == data.get_turn_hp(),
			"%s: 보정 0 이면 유닛 HP 가 get_turn_hp() 와 같아야 한다 (회귀)" % id)

	# 보정 5.
	var mammoth: EnemyData = EnemyDatabase.get_enemy(&"mammoth_beastfolk")
	var base := TurnUnit.from_enemy(mammoth, 1, "", 0)
	var boosted := TurnUnit.from_enemy(mammoth, 1, "", 5)
	var level := mammoth.turn_level + 5
	_expect(boosted.level == level,
		"보정 5 면 유닛 레벨이 turn_level + 5(%d)여야 한다 (실제 %d)" % [level, boosted.level])
	_expect(boosted.get_max_hp() == mammoth.get_turn_hp_at(level),
		"보정 5 의 HP 는 get_turn_hp_at(%d) 와 같아야 한다 (실제 %d)"
			% [level, boosted.get_max_hp()])
	_expect(boosted.get_max_hp() > base.get_max_hp(),
		"보정 5 의 HP 가 보정 0 보다 커야 한다 (%d vs %d)" % [boosted.get_max_hp(), base.get_max_hp()])
	_expect(boosted.get_attack() > base.get_attack() and boosted.get_defense() > base.get_defense(),
		"보정 5 의 공격력·방어력도 보정 0 보다 커야 한다")
	_expect(absi(boosted.get_attack() - mammoth.get_turn_attack_at(level)) <= 2,
		"역산한 근력이 보정 레벨의 목표 공격력을 만들어야 한다 (%d vs %d)"
			% [boosted.get_attack(), mammoth.get_turn_attack_at(level)])
	_expect(absi(boosted.get_defense() - mammoth.get_turn_defense_at(level)) <= 2,
		"역산한 방어력이 보정 레벨의 목표 방어력을 만들어야 한다 (%d vs %d)"
			% [boosted.get_defense(), mammoth.get_turn_defense_at(level)])

	# 위임: 레벨을 받는 형태에 turn_level 을 넘기면 기존 함수와 같다.
	_expect(mammoth.get_turn_hp_at(mammoth.turn_level) == mammoth.get_turn_hp()
			and mammoth.get_turn_attack_at(mammoth.turn_level) == mammoth.get_turn_attack()
			and mammoth.get_turn_defense_at(mammoth.turn_level) == mammoth.get_turn_defense(),
		"get_turn_*_at(turn_level) 은 get_turn_*() 과 같아야 한다")

	# 같은 정의로 보정을 달리해 두 번 만들어도 저작 리소스가 오염되지 않는다.
	var again := TurnUnit.from_enemy(mammoth, 1, "", 0)
	_expect(again.get_max_hp() == base.get_max_hp(),
		"보정 유닛을 만든 뒤에도 보정 0 유닛의 HP 가 그대로여야 한다 (저작 리소스 오염 없음)")

	# 레벨은 1 미만으로 내려가지 않는다.
	var floored := TurnUnit.from_enemy(mammoth, 1, "", -1000)
	_expect(floored.level == 1, "레벨은 1 미만으로 내려가면 안 된다 (실제 %d)" % floored.level)

	# 절대 지정은 레벨과 무관하다 — 손으로 맞춘 보스가 보정에 흔들리면 안 된다.
	var fixed := EnemyData.new()
	fixed.enemy_id = &"verify_fixed_boss"
	fixed.display_name = "고정 보스"
	fixed.tier = TurnCombat.EnemyTier.BOSS
	fixed.turn_level = 25
	fixed.turn_hp_override = 777777
	fixed.turn_attack_override = 600
	fixed.turn_defense_override = 1234
	fixed.stats = PlayerStats.new()
	var fixed_base := TurnUnit.from_enemy(fixed, 1, "", 0)
	var fixed_boosted := TurnUnit.from_enemy(fixed, 1, "", 5)
	_expect(fixed_boosted.level == 30, "절대 지정 적도 레벨 자체는 보정을 받는다 (실제 %d)" % fixed_boosted.level)
	_expect(fixed_boosted.get_max_hp() == 777777 and fixed_base.get_max_hp() == 777777,
		"turn_hp_override 가 있으면 보정과 무관하게 그 HP 여야 한다 (실제 %d)" % fixed_boosted.get_max_hp())
	_expect(absi(fixed_boosted.get_attack() - 600) <= 2 and absi(fixed_boosted.get_defense() - 1234) <= 2,
		"turn_attack/defense_override 도 보정과 무관해야 한다 (공격 %d · 방어 %d)"
			% [fixed_boosted.get_attack(), fixed_boosted.get_defense()])


func _test_level_bonus_manager() -> void:
	var raptor: EnemyData = EnemyDatabase.get_enemy(&"velociraptor_beastfolk")
	var mammoth: EnemyData = EnemyDatabase.get_enemy(&"mammoth_beastfolk")
	var seoa: EnemyData = EnemyDatabase.get_enemy(&"seoa")
	var bonus := 5

	var wave2_levels: Array[int] = []
	var wave2_hp: Array[int] = []

	var battle := TurnBattleManager.new()
	battle.auto_battle = true
	battle.cycle_limit = 60
	battle.enemy_level_bonus = bonus
	battle.pending_waves = [[mammoth, seoa]]
	battle.on_wave_started = func(index: int, _total: int) -> void:
		if index != 1:
			return
		for unit in battle.enemies():
			wave2_levels.append(unit.level)
			wave2_hp.append(unit.get_max_hp())
	battle.start(_party([&"mina", &"harang", &"seola", &"gangji"]), [raptor, mammoth], 0, 5150)
	battle.presentation.enabled = false

	# 1파: 적 레벨과 파티 레벨(자동)이 모두 보정을 포함한다.
	var top := maxi(raptor.turn_level, mammoth.turn_level) + bonus
	for unit in battle.enemies():
		_expect(unit.level == unit.enemy.turn_level + bonus,
			"1파 %s 의 레벨은 turn_level + %d 여야 한다 (실제 %d)"
				% [unit.display_name, bonus, unit.level])
	for unit in battle.allies():
		_expect(unit.level == top,
			"파티 레벨(자동)은 1파 (turn_level + 보정) 최고값 %d 여야 한다 (%s 실제 %d)"
				% [top, unit.display_name, unit.level])

	battle.begin_battle()
	var guard := 0
	while not battle.is_over() and guard < 4000:
		guard += 1
		battle.advance()

	# 2파: `_advance_wave()` 로 놓인 적도 보정을 받는다.
	_expect(wave2_levels.size() == 2,
		"2파에 도달해 적 2체가 놓여야 한다 (실제 %d체) — 1파에서 졌다면 시드를 다시 잡을 것"
			% wave2_levels.size())
	if wave2_levels.size() == 2:
		_expect(wave2_levels.has(mammoth.turn_level + bonus) and wave2_levels.has(seoa.turn_level + bonus),
			"2파 적도 turn_level + %d 이어야 한다 (실제 %s)" % [bonus, str(wave2_levels)])
		_expect(wave2_hp.has(mammoth.get_turn_hp_at(mammoth.turn_level + bonus)),
			"2파 매머드 HP 가 보정 레벨의 HP 여야 한다 (실제 %s)" % str(wave2_hp))

	# 파티 레벨은 **1파 기준**이다 — 2파가 더 높아져도 아군 레벨이 따라 오르지 않는다(기존 규칙 유지).
	for unit in battle.allies():
		_expect(unit.level == top,
			"파티 레벨은 웨이브가 넘어가도 1파 기준 %d 로 유지되어야 한다 (실제 %d)" % [top, unit.level])

	# 기본값 0: 설정하지 않은 전투는 기존과 같다.
	var plain := TurnBattleManager.new()
	_expect(plain.enemy_level_bonus == 0, "enemy_level_bonus 의 기본값은 0 이어야 한다")
	plain.start(_party([&"mina"]), [mammoth], 0, 1)
	_expect(plain.enemies()[0].level == mammoth.turn_level
			and plain.allies()[0].level == mammoth.turn_level,
		"보정을 주지 않으면 적·파티 레벨이 turn_level 그대로여야 한다")


func _test_stage_level_bonus_field() -> void:
	# 기존 스테이지는 보정이 0 이다 — 전투 결과가 그대로여야 한다.
	for id in [&"stage_1_1", &"stage_1_2", &"stage_1_3", &"stage_2_1", &"stage_test"]:
		var stage: StageData = StageDatabase.get_stage(id)
		_expect(stage != null, "%s 를 조회할 수 있어야 한다" % id)
		if stage != null:
			_expect(stage.turn_level_bonus == 0,
				"%s 의 turn_level_bonus 는 0 이어야 한다 (실제 %d)" % [id, stage.turn_level_bonus])

	# validate() 는 음수를 거부하고 0 이상은 받아들인다.
	var source: StageData = StageDatabase.get_stage(&"stage_1_1")
	var probe := source.duplicate(true) as StageData
	_expect(probe.validate().is_empty(), "복제한 기준 스테이지는 유효해야 한다: %s" % str(probe.validate()))
	probe.turn_level_bonus = -1
	var problems := probe.validate()
	var rejected := false
	for problem in problems:
		if problem.contains("turn_level_bonus"):
			rejected = true
	_expect(rejected, "음수 turn_level_bonus 는 validate() 가 거부해야 한다 (실제 %s)" % str(problems))
	probe.turn_level_bonus = 8
	_expect(probe.validate().is_empty(), "turn_level_bonus 8 은 유효해야 한다: %s" % str(probe.validate()))


# 2챕터 저작(#566): 설계(#564)의 레벨 곡선대로 적이 서는가.
# 보정 값 자체를 검사하는 이유: .tres 의 숫자 하나가 틀리면 전투는 정상으로 돌아가는데
# 난이도 곡선만 조용히 어긋난다(표는 사람이 읽어야 알 수 있다).
func _test_chapter2_stages() -> void:
	# 스테이지 -> [보정, 웨이브별 {적 id: 기대 레벨}]
	var expected := {
		&"stage_2_2": {"bonus": 3, "waves": [
			{&"velociraptor_beastfolk": 23, &"velociraptor_beastfolk_2": 23, &"seoa": 25},
			{&"mammoth_beastfolk": 25, &"seoa": 25}]},
		&"stage_2_3": {"bonus": 5, "waves": [
			{&"water_dragon_beastfolk": 26, &"seoa": 27},
			{&"water_dragon_chief": 30}]},
	}
	for id in expected:
		var stage: StageData = StageDatabase.get_stage(id)
		_expect(stage != null and stage.validate().is_empty(),
			"%s 가 로드되고 validate() 문제가 없어야 한다" % id)
		if stage == null:
			continue
		_expect(stage.chapter == 2 and stage.type == StageData.Type.BATTLE,
			"%s 는 2챕터 소탕(BATTLE) 이어야 한다" % id)
		_expect(stage.spawns.is_empty(), "%s 는 웨이브만 쓴다(spawns 비움)" % id)
		_expect(stage.forced_party.is_empty(), "%s 에 강제 파티를 두지 않는다" % id)
		_expect(stage.turn_level_bonus == int(expected[id]["bonus"]),
			"%s 의 turn_level_bonus 는 %d 여야 한다 (실제 %d)"
				% [id, int(expected[id]["bonus"]), stage.turn_level_bonus])

		var waves := TurnStageEncounter.waves_for(stage)
		var want: Array = expected[id]["waves"]
		_expect(waves.size() == want.size(),
			"%s 의 웨이브는 %d개여야 한다 (실제 %d)" % [id, want.size(), waves.size()])
		for w in mini(waves.size(), want.size()):
			var enemies: Array[EnemyData] = waves[w]["enemies"]
			_expect(enemies.size() <= TurnCombat.ENEMY_RANK_COUNT,
				"%s %d파 적이 랭크 수를 넘으면 안 된다" % [id, w + 1])
			for enemy in enemies:
				var unit := TurnUnit.from_enemy(enemy, 1, "", stage.turn_level_bonus)
				var level_want: int = int(want[w].get(enemy.enemy_id, -1))
				_expect(unit.level == level_want,
					"%s %d파 %s 의 레벨은 %d 여야 한다 (실제 %d)"
						% [id, w + 1, enemy.enemy_id, level_want, unit.level])

	# 2-3 의 2파만 보스다. 보스 타일 · 보스곡의 근거(`StageWave.is_boss`)가 저작되어 있어야 한다.
	var boss_stage: StageData = StageDatabase.get_stage(&"stage_2_3")
	if boss_stage != null and boss_stage.waves.size() == 2:
		_expect(not boss_stage.waves[0].is_boss and boss_stage.waves[1].is_boss,
			"2-3 은 2파만 is_boss 여야 한다")
	var normal_stage: StageData = StageDatabase.get_stage(&"stage_2_2")
	if normal_stage != null:
		for wave in normal_stage.waves:
			_expect(not wave.is_boss, "2-2 에는 보스 웨이브가 없다")

	# 보상: 철 장비 재료가 실제로 들어온다.
	var rewards := {
		&"stage_1_3": {"gold": 180, "protein": 200, "stone": 110, "coal": 2},
		&"stage_2_1": {"gold": 110, "protein": 120, "stone": 70, "iron_ore": 4, "coal": 1},
		&"stage_2_2": {"gold": 160, "protein": 160, "iron_ore": 6, "coal": 2, "tin": 6},
		&"stage_2_3": {"gold": 280, "protein": 280, "iron_ore": 10, "coal": 4, "copper": 6},
	}
	for id in rewards:
		var stage: StageData = StageDatabase.get_stage(id)
		if stage == null:
			continue
		var want: Dictionary = rewards[id]
		_expect(stage.clear_rewards.size() == want.size(),
			"%s 보상은 재화 %d종이어야 한다 (실제 %d종: 결과 화면 칩 수)"
				% [id, want.size(), stage.clear_rewards.size()])
		for key in want:
			_expect(int(stage.clear_rewards.get(key, -1)) == int(want[key]),
				"%s 보상 %s 은 %d 여야 한다 (실제 %s)"
					% [id, key, int(want[key]), str(stage.clear_rewards.get(key))])


# 3챕터 저작(#567): 설계(#564)의 레벨 곡선 · 웨이브 구성 · 보스 규칙 · 보상.
func _test_chapter3_stages() -> void:
	# 스테이지 -> [보정, 웨이브별 {적 id: 기대 레벨}, 웨이브별 적 수]
	var expected := {
		&"stage_3_1": {"bonus": 6, "counts": [4, 3], "waves": [
			{&"pterosaur_beastfolk": 27, &"velociraptor_beastfolk": 26, &"seoa": 28},
			{&"mammoth_beastfolk": 28, &"seoa": 28, &"velociraptor_beastfolk_2": 26}]},
		&"stage_3_2": {"bonus": 7, "counts": [3, 3, 4], "waves": [
			{&"velociraptor_beastfolk": 27, &"pterosaur_beastfolk": 28, &"seoa": 29},
			{&"mammoth_beastfolk": 29, &"velociraptor_beastfolk_2": 27, &"pterosaur_beastfolk": 28},
			{&"seoa": 29, &"mammoth_beastfolk": 29, &"velociraptor_beastfolk": 27,
				&"pterosaur_beastfolk": 28}]},
		&"stage_3_3": {"bonus": 9, "counts": [4, 2], "waves": [
			{&"mammoth_beastfolk": 31, &"seoa": 31, &"pterosaur_beastfolk": 30},
			{&"pterosaur_queen": 34, &"pterosaur_beastfolk": 30}]},
	}
	for id in expected:
		var stage: StageData = StageDatabase.get_stage(id)
		_expect(stage != null and stage.validate().is_empty(),
			"%s 가 로드되고 validate() 문제가 없어야 한다" % id)
		if stage == null:
			continue
		_expect(stage.chapter == 3 and stage.type == StageData.Type.BATTLE,
			"%s 는 3챕터 소탕(BATTLE) 이어야 한다 (점령 타입은 턴제에서 쉬워진다)" % id)
		_expect(stage.spawns.is_empty(), "%s 는 웨이브만 쓴다(spawns 비움)" % id)
		_expect(stage.forced_party.is_empty(), "%s 에 강제 파티를 두지 않는다" % id)
		_expect(stage.turn_level_bonus == int(expected[id]["bonus"]),
			"%s 의 turn_level_bonus 는 %d 여야 한다 (실제 %d)"
				% [id, int(expected[id]["bonus"]), stage.turn_level_bonus])

		var waves := TurnStageEncounter.waves_for(stage)
		var want: Array = expected[id]["waves"]
		var counts: Array = expected[id]["counts"]
		_expect(waves.size() == want.size(),
			"%s 의 웨이브는 %d개여야 한다 (실제 %d)" % [id, want.size(), waves.size()])
		for w in mini(waves.size(), want.size()):
			var enemies: Array[EnemyData] = waves[w]["enemies"]
			_expect(enemies.size() == int(counts[w]),
				"%s %d파 적은 %d체여야 한다 (실제 %d)" % [id, w + 1, int(counts[w]), enemies.size()])
			for enemy in enemies:
				var unit := TurnUnit.from_enemy(enemy, 1, "", stage.turn_level_bonus)
				var level_want: int = int(want[w].get(enemy.enemy_id, -1))
				_expect(unit.level == level_want,
					"%s %d파 %s 의 레벨은 %d 여야 한다 (실제 %d)"
						% [id, w + 1, enemy.enemy_id, level_want, unit.level])

	# **하늘 챕터의 BOSS 등급은 3-3 2파에만 둔다.** `TurnBattle._boss_music()` 이 하늘 컨셉의
	# 보스 웨이브에 최종 보스곡을 건다 — 3-1 · 3-2 에 보스를 넣으면 최종곡이 미리 나온다.
	for id in [&"stage_3_1", &"stage_3_2", &"stage_3_3"]:
		var stage: StageData = StageDatabase.get_stage(id)
		if stage == null:
			continue
		var boss_waves: Array[int] = []
		var boss_tiers: Array[int] = []
		for w in stage.waves.size():
			if stage.waves[w].is_boss:
				boss_waves.append(w)
		var encounter := TurnStageEncounter.waves_for(stage)
		for w in encounter.size():
			for enemy in encounter[w]["enemies"]:
				if enemy.tier == TurnCombat.EnemyTier.BOSS:
					boss_tiers.append(w)
		if id == &"stage_3_3":
			_expect(boss_waves == [1] and boss_tiers == [1],
				"3-3 은 2파만 is_boss · BOSS 등급이어야 한다 (is_boss %s, BOSS 등급 %s)"
					% [str(boss_waves), str(boss_tiers)])
		else:
			_expect(boss_waves.is_empty() and boss_tiers.is_empty(),
				"%s 에는 보스 웨이브도 BOSS 등급도 없어야 한다 — 최종 보스곡이 미리 나온다 (is_boss %s, BOSS 등급 %s)"
					% [id, str(boss_waves), str(boss_tiers)])

	# 보상: 후다만티움이 들어오고, 재화는 5종 이하(결과 화면 칩).
	var rewards := {
		&"stage_3_1": {"gold": 240, "protein": 240, "iron_ore": 3, "coal": 3, "hudamantium": 4},
		&"stage_3_2": {"gold": 320, "protein": 320, "iron_ore": 4, "coal": 4, "hudamantium": 6},
		&"stage_3_3": {"gold": 480, "protein": 480, "iron_ore": 6, "coal": 6, "hudamantium": 10},
	}
	for id in rewards:
		var stage: StageData = StageDatabase.get_stage(id)
		if stage == null:
			continue
		var want: Dictionary = rewards[id]
		_expect(stage.clear_rewards.size() == want.size() and want.size() <= 5,
			"%s 보상은 재화 %d종(5종 이하)이어야 한다 (실제 %d종)"
				% [id, want.size(), stage.clear_rewards.size()])
		for key in want:
			_expect(int(stage.clear_rewards.get(key, -1)) == int(want[key]),
				"%s 보상 %s 은 %d 여야 한다 (실제 %s)"
					% [id, key, int(want[key]), str(stage.clear_rewards.get(key))])

	# 새 챕터의 첫 스테이지는 앞 챕터 보스보다 덜 준다 (2-1 < 1-3, 3-1 < 2-3).
	var boss_prev: StageData = StageDatabase.get_stage(&"stage_2_3")
	var first: StageData = StageDatabase.get_stage(&"stage_3_1")
	if boss_prev != null and first != null:
		_expect(int(first.clear_rewards.get("gold", 0)) < int(boss_prev.clear_rewards.get("gold", 0)),
			"3-1 의 gold 는 2-3 보다 적어야 한다 — 새 챕터 첫 스테이지가 앞 챕터 보스보다 주면 보스를 도는 편이 낫다")


# 테마 적 3종(#568): 정의 · 약점 구성 · 스테이지 교체.
#
# 보스 셋(1-3 매머드 우두머리 · 2-3 수룡 우두머리 · 3-3 여왕)의 약점이 겹치지 않아야 한다 —
# 겹치면 같은 캐릭터 쌍이 세 보스를 다 푼다. 보스마다 편성을 바꿀 이유를 만드는 것이 설계 의도다.
func _test_themed_enemies() -> void:
	var spec := {
		&"water_dragon_beastfolk": {"tier": TurnCombat.EnemyTier.MINION, "level": 21,
			"element": TurnCombat.Element.CRYO, "physical": TurnCombat.PhysicalType.BLUNT,
			"weak": [TurnCombat.Element.VOLT, TurnCombat.Element.CORROSION],
			"weak_physical": [TurnCombat.PhysicalType.BLUNT], "ranks": [1, 2]},
		&"water_dragon_chief": {"tier": TurnCombat.EnemyTier.BOSS, "level": 25,
			"element": TurnCombat.Element.CRYO, "physical": TurnCombat.PhysicalType.BLUNT,
			"weak": [TurnCombat.Element.CORROSION, TurnCombat.Element.IMPACT],
			"weak_physical": [TurnCombat.PhysicalType.BLUNT, TurnCombat.PhysicalType.SLASH],
			"ranks": [1]},
		&"pterosaur_beastfolk": {"tier": TurnCombat.EnemyTier.MINION, "level": 21,
			"element": TurnCombat.Element.GALE, "physical": TurnCombat.PhysicalType.PIERCE,
			"weak": [TurnCombat.Element.CRYO, TurnCombat.Element.IMPACT],
			"weak_physical": [TurnCombat.PhysicalType.BLUNT], "ranks": [2, 3]},
	}
	for id in spec:
		_expect(EnemyDatabase.has_enemy(id), "%s 가 EnemyDatabase 에 로드되어야 한다" % id)
		var enemy: EnemyData = EnemyDatabase.get_enemy(id)
		if enemy == null:
			continue
		_expect(enemy.validate().is_empty(),
			"%s 의 validate() 문제가 없어야 한다: %s" % [id, ", ".join(enemy.validate())])
		_expect(enemy.validate_turn().is_empty(),
			"%s 의 validate_turn() 문제가 없어야 한다: %s" % [id, ", ".join(enemy.validate_turn())])
		var want: Dictionary = spec[id]
		_expect(enemy.tier == want["tier"], "%s 의 등급이 설계와 같아야 한다" % id)
		_expect(enemy.turn_level == int(want["level"]),
			"%s 의 turn_level 은 %d 여야 한다 (실제 %d)" % [id, int(want["level"]), enemy.turn_level])
		_expect(int(enemy.turn_element) == int(want["element"])
				and int(enemy.turn_physical_type) == int(want["physical"]),
			"%s 의 원소 / 물리가 설계와 같아야 한다" % id)
		var weak: Array[int] = []
		for e in enemy.weak_elements:
			weak.append(int(e))
		var weak_want: Array[int] = []
		for e in want["weak"]:
			weak_want.append(int(e))
		_expect(weak == weak_want, "%s 의 약점 원소가 설계와 같아야 한다 (실제 %s)" % [id, str(weak)])
		var weak_phys: Array[int] = []
		for p in enemy.weak_physical:
			weak_phys.append(int(p))
		var weak_phys_want: Array[int] = []
		for p in want["weak_physical"]:
			weak_phys_want.append(int(p))
		_expect(weak_phys == weak_phys_want, "%s 의 약점 물리가 설계와 같아야 한다 (실제 %s)" % [id, str(weak_phys)])
		var ranks: Array[int] = []
		for r in enemy.preferred_ranks:
			ranks.append(int(r))
		var ranks_want: Array[int] = []
		for r in want["ranks"]:
			ranks_want.append(int(r))
		_expect(ranks == ranks_want, "%s 의 선호 랭크가 설계와 같아야 한다 (실제 %s)" % [id, str(ranks)])
		_expect(not enemy.turn_skills.is_empty(), "%s 에 턴제 행동표가 있어야 한다" % id)
		# 아트가 없어도 서야 한다 — 도형 플레이스홀더(tint)가 있어야 전장에 보인다.
		_expect(enemy.sprite_texture != null and enemy.tint.a > 0.0,
			"%s 는 도형 플레이스홀더(sprite_texture · tint)로 설 수 있어야 한다" % id)

		# 턴제 유닛으로 변환되어 HP 가 레벨 · 등급 파생값과 같다.
		var unit := TurnUnit.from_enemy(enemy, 1)
		_expect(unit.get_max_hp() == enemy.get_turn_hp() and unit.max_toughness > 0,
			"%s 가 턴제 유닛으로 변환되어야 한다 (HP %d)" % [id, unit.get_max_hp()])

	var chief: EnemyData = EnemyDatabase.get_enemy(&"water_dragon_chief")
	if chief != null:
		_expect(chief.toughness == 200 and is_equal_approx(chief.break_resistance, 0.3),
			"수룡 수인 우두머리의 인성치는 200, 격파 저항은 0.3 이어야 한다")
		_expect(chief.turn_skills.size() == 4,
			"수룡 수인 우두머리는 공용 스킬 넷(돌진 · 쓸어치기 · 밀치기 · 전멸기)을 쓴다 (실제 %d)"
				% chief.turn_skills.size())

	# 보스 셋의 약점 원소는 서로 겹치지 않는다.
	var boss_ids: Array[StringName] = [&"mammoth_boss", &"water_dragon_chief", &"pterosaur_queen"]
	var seen := {}
	for id in boss_ids:
		var boss: EnemyData = EnemyDatabase.get_enemy(id)
		if boss == null:
			continue
		_expect(boss.tier == TurnCombat.EnemyTier.BOSS, "%s 는 보스 등급이어야 한다" % id)
		for e in boss.weak_elements:
			_expect(not seen.has(int(e)),
				"보스 셋의 약점이 겹치면 안 된다 — %s 의 약점 %s 이 다른 보스와 같다"
					% [id, TurnCombat.element_name(int(e))])
			seen[int(e)] = id

	# 스테이지 교체: 2-3 은 더 이상 매머드 우두머리를 쓰지 않고, 하늘 스테이지는 익룡 수인이 선다.
	var used := {}
	for sid in [&"stage_2_3", &"stage_3_1", &"stage_3_2", &"stage_3_3"]:
		var stage: StageData = StageDatabase.get_stage(sid)
		var ids := {}
		if stage != null:
			for entry in TurnStageEncounter.waves_for(stage):
				for enemy in entry["enemies"]:
					ids[enemy.enemy_id] = true
		used[sid] = ids
	_expect(not used[&"stage_2_3"].has(&"mammoth_boss") and used[&"stage_2_3"].has(&"water_dragon_chief")
			and used[&"stage_2_3"].has(&"water_dragon_beastfolk"),
		"2-3 은 수룡 수인 무리 + 수룡 수인 우두머리여야 한다 (매머드 우두머리는 1-3 의 보스다)")
	for sid in [&"stage_3_1", &"stage_3_2", &"stage_3_3"]:
		_expect(used[sid].has(&"pterosaur_beastfolk"),
			"%s 에 익룡 수인이 서야 한다 (하늘 챕터의 테마 적)" % sid)


# 전투 화면이 스테이지의 보정을 매니저까지 전달하는가. 위 검사들은 매니저에 값을 직접
# 넣었으므로 **화면 -> 매니저** 연결은 여기서만 확인된다.
func _test_stage_level_bonus_reaches_battle() -> void:
	var was_enabled := TurnCombatConfig.tuning.presentation_enabled
	TurnCombatConfig.tuning.presentation_enabled = false

	var source: StageData = StageDatabase.get_stage(&"stage_1_1")
	var probe := source.duplicate(true) as StageData
	probe.stage_id = &"verify_level_bonus_stage"
	probe.turn_level_bonus = 4
	StageDatabase._stages[probe.stage_id] = probe

	var previous := StageSystem.get_current_id()
	StageSystem.request_stage(probe.stage_id)

	var scene: PackedScene = load("res://stage/turn/TurnBattle.tscn")
	var node := scene.instantiate()
	node.set("use_stage", true)
	node.set("battle_seed", 20260909)
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame

	var battle = node.get("battle")
	_expect(battle != null, "보정 스테이지에서도 전투 화면이 전투를 만들어야 한다")
	if battle != null:
		_expect(int(battle.enemy_level_bonus) == 4,
			"전투 화면이 스테이지의 turn_level_bonus(4)를 매니저에 넘겨야 한다 (실제 %d)"
				% int(battle.enemy_level_bonus))
		var enemies: Array = battle.enemies()
		_expect(not enemies.is_empty(), "스테이지의 적이 놓여야 한다")
		for unit in enemies:
			_expect(unit.level == unit.enemy.turn_level + 4,
				"화면이 만든 적 %s 의 레벨이 turn_level + 4 여야 한다 (실제 %d)"
					% [unit.display_name, unit.level])

	node.queue_free()
	await get_tree().process_frame
	StageDatabase._stages.erase(probe.stage_id)
	StageSystem.request_stage(previous)
	TurnCombatConfig.tuning.presentation_enabled = was_enabled


# 전투 UI 가 메타 화면(메인화면/편성/결과)보다 **아래**에 있어야 한다.
#
# 왜 검사하는가: 전투 HUD 를 `ScreenManager.SCREEN_LAYER` 와 같은 번호(10)에 두었더니
# 로비 화면 위로 전투 UI 가 그대로 겹쳐 보였다. 번호가 같으면 트리 순서가 앞뒤를 정하고,
# ScreenManager 는 autoload 라 메인 씬보다 먼저 붙어 아래로 깔린다. 눈으로만 잡히는
# 종류의 회귀라 여기서 번호를 붙잡아 둔다.
#
# 상수만 보지 않고 **만들어진 CanvasLayer** 를 훑는 이유: 상수가 맞아도 대입을 빠뜨리면
# 같은 증상이 그대로 돌아온다.
func _check_hud_below_meta_screens(node: Node) -> void:
	var layers: Array[int] = []
	for child in node.get_children():
		if child is CanvasLayer:
			layers.append((child as CanvasLayer).layer)

	_expect(layers.size() >= 2,
		"전투 화면이 HUD·플래시 CanvasLayer 를 만들어야 한다 (실제 %d개)" % layers.size())
	for value in layers:
		_expect(value < ScreenManager.SCREEN_LAYER,
			"전투 UI 레이어(%d)는 메타 화면 레이어(%d)보다 낮아야 한다 — 같거나 높으면 로비에 전투 UI 가 겹쳐 보인다"
				% [value, ScreenManager.SCREEN_LAYER])


# ===== 헬퍼 =====

# 로스터의 **사본**을 성장 배수 1.0 으로 고정해 돌려준다. `PlayerProfile` 이 세이브의 삼각근
# Lv. 을 원본에 넣어 두므로(#563 이후 전투 유닛까지 간다), 원본을 쓰면 검사 결과가 실행하는
# 사람의 세이브에 따라 달라진다.
func _party(ids: Array) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for id in ids:
		var source: CharacterData = CharacterDatabase.get_character(id)
		if source == null:
			continue
		var copy := source.duplicate(true) as CharacterData
		copy.get_stats().set_growth_multiplier(1.0)
		out.append(copy)
	return out


func _enemies(ids: Array) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for id in ids:
		var enemy: EnemyData = EnemyDatabase.get_enemy(id)
		if enemy != null:
			out.append(enemy)
	return out

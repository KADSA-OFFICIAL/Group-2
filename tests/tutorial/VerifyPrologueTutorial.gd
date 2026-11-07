extends Node

# 첫 플레이 프롤로그(#594) 검증.
#
# 저작본을 읽기만 하면 "대본은 맞는데 전투에서는 안 넘어가는" 단계를 잡을 수 없다(#472 에서
# 실시간 안내가 턴제에서 영원히 멈춘 것이 그 예다). 그래서 **실제 TurnBattleManager 로
# 저작된 시퀀스를 끝까지 재생한다** — TurnBattle 화면이 하는 배선(행동자 당기기·읽는 동안
# 멈춤·궁극기 단계의 게이지 충전)을 그대로 흉내 내고, 각 단계가 시킨 조작만으로 넘어가는지 본다.
#
# 세이브: 테스트가 끝나면 손댄 제공자 상태를 되돌린다(종료 시 SaveSystem 이 파일을 쓴다).
#
# 실행:
#   godot --headless --path . res://tests/tutorial/VerifyPrologueTutorial.tscn

const STAGE_ID := &"stage_1_1"
const CHAPTER_ID := &"prologue"
const EXPECTED_STEPS := [
	&"timeline", &"basic_attack", &"weakness_lock", &"skill_resonance",
	&"intent_break", &"first_ultimate", &"free_battle",
]

var _failures: Array[String] = []
var _checks: int = 0
var _snapshot: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	# 부팅 때 뜬 화면·전투와 섞이지 않게 상태를 잡아 둔다.
	_snapshot = SaveSystem.collect_save_data()

	_test_sequence_data()
	_test_story_chapter()
	_test_realtime_sequence_untouched()
	_test_timeline_forced_next()
	_test_hp_floor()
	_test_full_guided_battle()
	_test_not_shown_again()
	_test_prologue_needed()
	await _test_story_player_flow()

	_restore()
	if _failures.is_empty():
		print("PASS: 프롤로그 튜토리얼 검증 %d개 통과" % _checks)
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


func _restore() -> void:
	for key in _snapshot:
		if not SaveSystem.has_provider(key):
			continue
		var provider: Object = SaveSystem._providers.get(key)
		if provider != null and provider.has_method("from_save_dict"):
			provider.call("from_save_dict", _snapshot[key])


func _set_tutorial_fresh() -> void:
	TutorialSystem.from_save_dict({"completed": []})


# ===== 저작본 =====

func _test_sequence_data() -> void:
	var seq := TutorialSystem.get_turn_sequence(STAGE_ID)
	_expect(seq != null, "1-1 턴제 시퀀스가 로드된다")
	if seq == null:
		return
	_expect(seq.combat == TutorialSequenceData.Combat.TURN, "턴제 시퀀스로 표시돼 있다")
	_expect(seq.validate().is_empty(), "시퀀스 무결성: %s" % [seq.validate()])
	_expect(seq.sequence_key() == &"turn/stage_1_1", "완료 키가 실시간과 겹치지 않는다")
	_expect(seq.ally_hp_floor >= 1, "프롤로그 전투는 지지 않는다(ally_hp_floor)")

	var ids: Array = []
	for step in seq.steps:
		ids.append(step.step_id)
	_expect(ids == EXPECTED_STEPS, "7단계 순서: %s" % [ids])

	var encounter := _encounter_ids()
	for step in seq.steps:
		# 화자는 스토리와 같은 해석으로 풀려야 한다(이름표가 비면 누가 말하는지 모른다).
		if not String(step.speaker_id).is_empty():
			var probe := StoryLineData.new()
			probe.character_id = step.speaker_id
			_expect(probe.get_character() != null, "화자 해석: %s" % step.speaker_id)
		if not String(step.actor_id).is_empty():
			var c := CharacterDatabase.get_character(step.actor_id)
			_expect(c != null and c.playable, "행동자는 전투 로스터: %s" % step.actor_id)
			if c != null and not String(step.skill_id).is_empty():
				var found := false
				for s in c.turn_skills:
					if s != null and s.skill_id == step.skill_id:
						found = true
				_expect(found, "%s 의 키트에 %s 가 있다" % [step.actor_id, step.skill_id])
		if not String(step.target_id).is_empty():
			_expect(encounter.has(step.target_id), "1-1 조우에 대상 %s 가 있다" % step.target_id)
	for key in seq.scripted_locks:
		_expect(encounter.has(StringName(String(key))), "자물쇠를 걸 적이 1-1 에 있다: %s" % key)


func _encounter_ids() -> Array:
	var battle := _new_battle(1)
	var out: Array = []
	for u in battle.units:
		out.append(u.unit_id)
	return out


func _test_story_chapter() -> void:
	var chapter := StoryDatabase.get_chapter(CHAPTER_ID)
	_expect(chapter != null, "프롤로그 챕터가 로드된다")
	if chapter == null:
		return
	var battles := 0
	for line in chapter.lines:
		if line.kind == StoryLineData.Kind.BATTLE:
			battles += 1
			_expect(line.stage_id == STAGE_ID, "전투 줄이 1-1 을 가리킨다")
		if not String(line.character_id).is_empty():
			_expect(line.get_character() != null, "대사 화자 해석: %s" % line.character_id)
	_expect(battles == 1, "전투 줄은 하나다(오프닝/마무리 경계)")
	_expect(chapter.number < 1, "목록에서 챕터 1 앞에 온다")


func _test_realtime_sequence_untouched() -> void:
	# 실시간 1-1 안내는 그대로 남아 있어야 한다(Non-goal) — 같은 stage_id 라 버려지면 안 된다.
	_expect(TutorialSystem.has_sequence(STAGE_ID), "실시간 1-1 시퀀스가 여전히 로드된다")


# ===== 전투 보조 장치 =====

func _test_timeline_forced_next() -> void:
	var battle := _new_battle(594)
	battle.begin_battle()
	# 첫 입력 대기가 누구든, 다음 턴은 지정한 아군이어야 한다(속도가 가장 느린 강지로 확인).
	var guard := 0
	while battle.phase != TurnBattleManager.Phase.AWAITING_INPUT and guard < 20:
		guard += 1
		battle.advance()
	battle.timeline.forced_next_id = &"gangji"
	battle.act(battle.active_unit.character.get_turn_basic(), battle.enemies()[0])
	guard = 0
	while battle.phase != TurnBattleManager.Phase.AWAITING_INPUT and guard < 20:
		guard += 1
		battle.advance()
	_expect(battle.active_unit != null and battle.active_unit.unit_id == &"gangji",
		"forced_next_id 로 다음 행동자를 정한다")
	_expect(String(battle.timeline.forced_next_id).is_empty(), "한 번 쓰면 비워진다")


func _test_hp_floor() -> void:
	var battle := _new_battle(594, 1)
	var ally := battle.find_unit(&"harang")
	var enemy := battle.enemies()[0]
	var ctx := DamageContext.new()
	ctx.source = enemy
	ctx.target = ally
	ctx.hp_damage = 999999
	battle.pipeline._step_apply(ctx)
	_expect(ally.current_hp == 1 and ally.alive and not ctx.killed, "HP 하한 1 이면 쓰러지지 않는다")

	var normal := _new_battle(594)
	var victim := normal.find_unit(&"harang")
	var ctx2 := DamageContext.new()
	ctx2.source = enemy
	ctx2.target = victim
	ctx2.hp_damage = 999999
	normal.pipeline._step_apply(ctx2)
	_expect(not victim.alive, "하한이 없으면 평소대로 쓰러진다")


# ===== 끝까지 재생 =====

func _test_full_guided_battle() -> void:
	_set_tutorial_fresh()
	var battle := _new_battle_for_tutorial()
	_expect(TutorialSystem.is_turn_active(), "turn_stage_started 로 안내가 켜진다")
	if not TutorialSystem.is_turn_active():
		return

	var seen: Array = []
	var shown_actor: Dictionary = {}
	var auto_skips := 0
	var guard := 0
	# 람다는 지역 변수를 값으로 잡으므로 배열에 담는다.
	var broke: Array = []
	var on_break := func(unit, _el):
		if unit != null and unit.unit_id == &"mammoth_beastfolk#1":
			broke.append(true)
	EventBus.turn_weakness_broken.connect(on_break)

	while not battle.is_over() and guard < 400:
		guard += 1
		if battle.phase != TurnBattleManager.Phase.AWAITING_INPUT:
			battle.advance()
			continue
		var active := battle.active_unit
		if TutorialSystem.is_turn_active() and TutorialSystem.turn_ready_point(active.unit_id):
			auto_skips += 1
			print("[auto-skip] active=%s step=%s pending=%s" % [active.unit_id,
				TutorialSystem.get_current_step().step_id, TutorialSystem.is_turn_step_pending()])
			battle.auto_act()
			continue

		if TutorialSystem.is_holding_turn_battle():
			var step := TutorialSystem.get_current_step()
			seen.append(step.step_id)
			shown_actor[step.step_id] = active.unit_id
			# 읽는 중에는 아무 조작도 받지 않는다.
			_expect(not TutorialSystem.allows_turn_input("action", active.unit_id,
				active.character.get_turn_basic()), "읽는 중 행동 차단 (%s)" % step.step_id)
			if step.advance == TutorialStepData.Advance.TURN_ULTIMATE:
				var caster := battle.find_unit(step.actor_id)
				caster.energy = caster.get_energy_max()   # TurnBattle 이 하는 일
			TutorialSystem.confirm()
			continue

		if not TutorialSystem.is_turn_active():
			battle.auto_act()
			continue

		var step := TutorialSystem.get_current_step()
		match step.advance:
			TutorialStepData.Advance.TURN_ULTIMATE:
				# 다른 행동은 막혀 있어야 한다.
				_expect(not TutorialSystem.allows_turn_input("action", active.unit_id,
					active.character.get_turn_basic()), "궁극기 단계에서 평타 차단")
				_expect(TutorialSystem.allows_turn_input("action", active.unit_id,
					battle.find_unit(step.actor_id).character.get_turn_ultimate()), "목록의 궁극기 항목도 허용")
				_expect(TutorialSystem.allows_turn_input("ultimate", step.actor_id),
					"궁극기 단계에서 %s 궁극기 허용" % step.actor_id)
				_expect(TutorialSystem.is_showcase_action(step.actor_id,
					battle.find_unit(step.actor_id).character.get_turn_ultimate()), "첫 궁극기는 강조 연출")
				var r := battle.use_ultimate(battle.find_unit(step.actor_id))
				_expect(bool(r["ok"]), "첫 궁극기 발동: %s" % r.get("reason", ""))
			TutorialStepData.Advance.TURN_VICTORY:
				_expect(TutorialSystem.allows_turn_input("control"), "자유 전투에서 배속·자동 해금")
				battle.auto_act()
			_:
				_expect(not TutorialSystem.allows_turn_input("control"), "안내 중 배속·자동 잠금 (%s)" % step.step_id)
				_expect(active.unit_id == step.actor_id, "%s 단계는 %s 의 차례다 (실제 %s)"
					% [step.step_id, step.actor_id, active.unit_id])
				var skill := _skill_of(active, step.skill_id)
				var wrong := active.character.get_turn_ultimate()
				_expect(not TutorialSystem.allows_turn_input("action", active.unit_id, wrong),
					"%s 단계에서 다른 행동 차단" % step.step_id)
				var target := battle.find_unit(step.target_id)
				_expect(TutorialSystem.allows_turn_input("action", active.unit_id, skill),
					"%s 단계에서 시킨 행동 허용" % step.step_id)
				var r := battle.act(skill, target)
				_expect(bool(r["ok"]), "%s 행동 성공: %s" % [step.step_id, r.get("reason", "")])

	_expect(seen == EXPECTED_STEPS, "7단계가 순서대로 떴다: %s" % [seen])
	_expect(auto_skips == 0, "엉뚱한 아군의 차례가 끼어들지 않았다 (%d회)" % auto_skips)
	_expect(shown_actor.get(&"timeline") == &"harang", "첫 화면은 하랑의 차례다")
	EventBus.turn_weakness_broken.disconnect(on_break)
	_expect(not broke.is_empty(), "강지의 강타로 매머드가 격파됐다")
	_expect(battle.phase == TurnBattleManager.Phase.VICTORY, "승리로 끝난다 (phase=%d)" % battle.phase)
	for ally in battle.allies():
		_expect(ally.alive, "%s 가 살아 있다(패배 불가)" % ally.unit_id)
	_expect(TutorialSystem.is_turn_completed(STAGE_ID), "완료로 저장된다")
	_expect(not TutorialSystem.is_turn_active(), "끝나면 안내가 꺼진다")


func _test_not_shown_again() -> void:
	# 위 테스트에서 완료했다. 1-1 을 다시 열어도 안내가 켜지지 않는다.
	EventBus.turn_stage_started.emit(String(STAGE_ID))
	_expect(not TutorialSystem.is_turn_active(), "완료 후 1-1 재진입에 안내가 다시 뜨지 않는다")
	# 저장 왕복.
	var saved := TutorialSystem.to_save_dict()
	_set_tutorial_fresh()
	TutorialSystem.from_save_dict(saved)
	_expect(TutorialSystem.is_turn_completed(STAGE_ID), "완료 기록이 저장 왕복을 견딘다")


func _test_prologue_needed() -> void:
	var stage_saved := StageProgress.to_save_dict()
	StageProgress.from_save_dict({})
	_set_tutorial_fresh()
	_expect(PrologueFlow.is_needed(), "새 세이브는 프롤로그가 필요하다")
	TutorialSystem.mark_turn_completed(STAGE_ID)
	_expect(not PrologueFlow.is_needed(), "프롤로그를 끝낸 세이브는 필요 없다")

	# 프롤로그 이전 세이브(이미 1-1 을 깼다)는 옮겨 온다.
	_set_tutorial_fresh()
	StageProgress.from_save_dict(stage_saved)
	if StageProgress.is_cleared(STAGE_ID):
		_expect(not PrologueFlow.is_needed(), "1-1 을 이미 깬 세이브는 프롤로그를 건너뛴다")
		_expect(TutorialSystem.is_turn_completed(STAGE_ID), "그 세이브는 안내를 본 것으로 기록된다")


func _test_story_player_flow() -> void:
	ScreenManager.close_all()
	await get_tree().process_frame
	var screen := ScreenManager.push(load("res://screens/story/StoryPlayerScreen.tscn"))
	_expect(screen != null, "스토리 화면을 연다")
	if screen == null:
		return
	var reached: Array = []
	screen.battle_reached.connect(func(stage_id, resume): reached.append([stage_id, resume]))
	screen.configure_flow(true, true)
	screen.open_chapter(CHAPTER_ID)
	screen._skip()
	var chapter := StoryDatabase.get_chapter(CHAPTER_ID)
	var battle_index := -1
	for i in range(chapter.lines.size()):
		if chapter.lines[i].kind == StoryLineData.Kind.BATTLE:
			battle_index = i
	_expect(reached.size() == 1, "건너뛰기는 전투 줄에서 멈추고 전투로 넘긴다")
	if reached.size() == 1:
		_expect(reached[0][0] == STAGE_ID and int(reached[0][1]) == battle_index + 1,
			"이어 볼 줄은 전투 줄 다음이다: %s" % [reached[0]])
	await get_tree().create_timer(0.6).timeout
	_expect(not ScreenManager.has_screen(), "전투로 넘기면 스토리 화면이 닫힌다")

	# 마무리: 이어 보기로 열면 끝에서 끝 카드 없이 닫힌다.
	var ending := ScreenManager.push(load("res://screens/story/StoryPlayerScreen.tscn"))
	ending.configure_flow(false, true)
	ending.open_chapter(CHAPTER_ID, battle_index + 1)
	ending._skip()
	await get_tree().create_timer(0.6).timeout
	_expect(not ScreenManager.has_screen(), "마무리 스토리는 끝나면 바로 닫힌다")


# ===== 보조 =====

func _party() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for id in [&"harang", &"taehee", &"gangji", &"arin"]:
		out.append(CharacterDatabase.get_character(id))
	return out


func _new_battle(seed_value: int, hp_floor: int = 0) -> TurnBattleManager:
	var stage := StageDatabase.get_stage(STAGE_ID)
	var waves := []
	for e in TurnStageEncounter.waves_for(stage):
		waves.append(e["enemies"])
	var b := TurnBattleManager.new()
	b.step_by_turn = true
	b.ally_hp_floor = hp_floor
	b.enemy_level_bonus = stage.turn_level_bonus
	b.pending_waves = waves.slice(1)
	b.start(_party(), waves[0], 0, seed_value)
	b.use_prep("energy")
	return b


# TurnBattle._start_battle 의 배선을 그대로 따른다: 신호 -> 저작된 판 -> start -> 자물쇠 -> 개시.
func _new_battle_for_tutorial() -> TurnBattleManager:
	var stage := StageDatabase.get_stage(STAGE_ID)
	var waves := []
	for e in TurnStageEncounter.waves_for(stage):
		waves.append(e["enemies"])
	var b := TurnBattleManager.new()
	var relay := func(actor_id: StringName): b.timeline.forced_next_id = actor_id
	TutorialSystem.turn_actor_requested.connect(relay)
	EventBus.turn_stage_started.emit(String(STAGE_ID))
	var seq := TutorialSystem.get_active_turn_sequence()
	b.step_by_turn = true
	b.enemy_level_bonus = stage.turn_level_bonus
	b.pending_waves = waves.slice(1)
	if seq != null:
		b.ally_hp_floor = seq.ally_hp_floor
	b.start(_party(), waves[0], 0, seq.battle_seed if seq != null else 1)
	if seq != null:
		seq.apply_scripted_locks(b)
	b.use_prep("energy")
	b.begin_battle()
	return b


func _skill_of(unit: TurnUnit, skill_id: StringName) -> SkillData:
	for s in unit.character.turn_skills:
		if s != null and s.skill_id == skill_id:
			return s
	return unit.character.get_turn_basic()

extends Node

# 근접 타격 연출 검증 (#531).
#
# ## 왜 필요한가
#
# 공격자가 제자리에서 26px 나갔다 돌아오기만 해서 **"상대를 때린다"는 느낌이 없었다.**
# 이제 공격자는 대상 앞까지 달려가 선 채로 피격 연출을 받고, 행동이 끝나면 돌아온다.
# 이 검사는 세 가지를 본다.
#
# 1. 상대를 치는 스킬 — 공격자가 대상 바로 앞까지 간다.
# 2. 복귀 — 제 랭크 자리로 돌아온다. 안 돌아오면 다음 행동에서 두 명이 겹친다.
# 3. 적 턴 — `SKILL_CAST` 가 쌓인다. 예전에는 적이 시전 이벤트를 아예 쌓지 않았다.
#
# 실행:
#   godot --headless --path . res://tests/combat/VerifyMeleeApproach.tscn

const TIMEOUT_SECONDS: float = 30.0
const SAMPLE_SECONDS: float = 0.05

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await _run()

	if _failures.is_empty():
		print("PASS: 근접 타격 연출 검증 %d개 통과" % _checks)
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: 근접 타격 연출 %d/%d 실패" % [_failures.size(), _checks])
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("실패: " + message)


func _run() -> void:
	var tuning := TurnCombatConfig.tuning
	var was_enabled: bool = tuning.presentation_enabled
	var was_speed: float = tuning.presentation_speed
	tuning.presentation_enabled = true
	tuning.presentation_speed = 3.0

	var node := (load("res://stage/turn/TurnBattle.tscn") as PackedScene).instantiate()
	node.set("use_stage", false)
	node.set("battle_seed", 20260926)
	node.set("party_ids", Array([&"harang", &"gangji", &"mina", &"arin"], TYPE_STRING_NAME, "", null))
	node.set("enemy_ids", Array([&"velociraptor_beastfolk", &"seoa"], TYPE_STRING_NAME, "", null))
	add_child(node)
	await get_tree().process_frame

	var battle = node.get("battle")
	_expect(battle != null, "전투가 만들어져야 한다")
	if battle == null:
		_restore(tuning, was_enabled, was_speed)
		node.queue_free()
		return

	# 첫 입력 대기까지 연출을 흘려보낸다.
	var elapsed := 0.0
	while elapsed < TIMEOUT_SECONDS:
		if battle.phase == TurnBattleManager.Phase.AWAITING_INPUT and not bool(node.get("_playing")):
			break
		await get_tree().create_timer(SAMPLE_SECONDS, true, false, true).timeout
		elapsed += SAMPLE_SECONDS

	var hud: TurnBattleHUD = node.get("hud")
	var shapes: Dictionary = node.get("_shapes")
	var ally: TurnUnit = null
	var enemy: TurnUnit = null
	for unit in battle.units:
		if unit.alive and unit.is_ally() and ally == null:
			ally = unit
		if unit.alive and unit.is_enemy() and enemy == null:
			enemy = unit
	_expect(ally != null and enemy != null, "아군과 적이 하나씩은 있어야 한다")
	if ally == null or enemy == null:
		_restore(tuning, was_enabled, was_speed)
		node.queue_free()
		return

	var shape: Node2D = shapes[ally.unit_id]
	var home := hud.unit_position(ally)
	var gap: float = node.get("STRIKE_GAP")

	# 1. 상대를 치는 스킬 — 대상 앞까지 간다.
	var attack := _find_skill(ally, false)
	_expect(attack != null, "%s 에게 상대를 치는 스킬이 있어야 한다" % ally.display_name)
	await node.call("_play_cast", {"unit": ally, "skill": attack, "target": enemy})
	var spot := hud.unit_position(enemy)
	_expect(absf(shape.position.x - (spot.x - gap)) < 2.0,
		"공격자는 대상 앞 %.0fpx 에 서야 한다 (x=%.1f, 기대 %.1f)" % [gap, shape.position.x, spot.x - gap])
	_expect(shape.position.distance_to(home) > gap,
		"공격자가 제자리에서 충분히 떠나야 한다 (%.1fpx)" % shape.position.distance_to(home))
	_expect(shape.z_index > 10, "대상 앞에 선 동안 공격자를 앞에 그려야 한다")

	# 피격 연출이 공격자가 붙어 선 채로 재생되는 동안 위치를 유지하는가.
	_expect(node.get("_striker") == ally, "피격 연출 전까지 공격자가 나가 있는 상태여야 한다")

	# 2. 복귀.
	await node.call("_return_striker")
	_expect(shape.position.distance_to(home) < 1.0,
		"공격자는 제 랭크 자리로 돌아와야 한다 (%.1fpx 어긋남)" % shape.position.distance_to(home))
	_expect(shape.z_index == 10, "돌아오면 그리기 순서도 되돌려야 한다")
	_expect(node.get("_striker") == null, "돌아오면 나가 있는 공격자가 없어야 한다")

	# 상대를 치지 않는 스킬은 달려가지 않는다.
	var support := _find_skill(ally, true)
	if support == null:
		for unit in battle.units:
			if unit.is_ally() and _find_skill(unit, true) != null:
				ally = unit
				support = _find_skill(unit, true)
				break
	if support != null:
		shape = shapes[ally.unit_id]
		home = hud.unit_position(ally)
		await node.call("_play_cast", {"unit": ally, "skill": support, "target": ally})
		_expect(shape.position.distance_to(home) < 1.0,
			"아군 대상 스킬은 제자리로 돌아와 있어야 한다 (%.1fpx)" % shape.position.distance_to(home))
		_expect(node.get("_striker") == null, "아군 대상 스킬은 공격자로 남지 않는다")

	# 3. 적 턴 — 시전 이벤트가 쌓인다.
	battle.auto_battle = true
	var enemy_casts := 0
	elapsed = 0.0
	while elapsed < TIMEOUT_SECONDS and enemy_casts == 0:
		if battle.phase == TurnBattleManager.Phase.AWAITING_INPUT:
			battle.advance()
			node.call("_play")
		for entry in battle.presentation.events:
			if entry["event"] != PresentationQueue.Event.SKILL_CAST:
				continue
			var caster: TurnUnit = entry["data"].get("unit")
			var target: TurnUnit = entry["data"].get("target")
			if caster != null and caster.is_enemy():
				enemy_casts += 1
				_expect(target != null and target.is_ally(),
					"적 시전 이벤트의 대상은 아군이어야 한다")
		if battle.is_over():
			break
		await get_tree().create_timer(SAMPLE_SECONDS, true, false, true).timeout
		elapsed += SAMPLE_SECONDS
	_expect(enemy_casts > 0, "적이 공격하면 SKILL_CAST 가 쌓여야 한다 (관측 %d회)" % enemy_casts)

	_restore(tuning, was_enabled, was_speed)
	node.queue_free()
	await get_tree().process_frame


# 상대를 치는 스킬(allies=false) 또는 아군 대상 스킬(allies=true).
func _find_skill(unit: TurnUnit, allies: bool) -> SkillData:
	if unit.character == null:
		return null
	for skill in unit.character.turn_skills:
		if skill != null and skill.targets_allies() == allies:
			return skill
	return null


func _restore(tuning, enabled: bool, speed: float) -> void:
	tuning.presentation_enabled = enabled
	tuning.presentation_speed = speed
	Engine.time_scale = 1.0

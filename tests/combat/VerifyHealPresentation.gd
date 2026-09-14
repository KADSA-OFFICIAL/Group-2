extends Node

# 회복 연출 경로 검증 (#525).
#
# ## 왜 필요한가
#
# `fx_heal` 시트와 `heal.ogg` 가 먼저 들어오고 **재생 코드만 비어 있었다.**
# `PresentationQueue.Event.HEAL` 은 enum 에 있었지만 **쌓는 곳이 없었고**,
# `NUMBER_STYLE["heal"]` 도 정의만 되고 호출되지 않았다. 회복이 일어나도
# 숫자·이펙트·소리가 전부 나오지 않았다.
#
# 이런 종류는 **"에셋이 있다"는 검사로는 절대 안 잡힌다** — 파일은 멀쩡히 있었다.
# 회복을 실제로 일으켜 이벤트가 쌓이는지 봐야 한다.
#
# ## 함정 — 파티에 회복 담당이 있어야 한다
#
# 회복 효과(`TurnSkillEffect.Kind.HEAL`)를 가진 것은 **강지와 하랑**뿐이다.
# 기본 스테이지 파티(미나·태희·설아·아린)로 돌리면 회복이 한 번도 안 일어나
# **아무것도 검증하지 못한 채 통과한다.** 그래서 파티를 명시한다.
#
# 실행:
#   godot --headless --path . res://tests/combat/VerifyHealPresentation.tscn

## 회복 담당이 든 파티. 이 둘이 아니면 회복이 일어나지 않는다.
const PARTY: Array[StringName] = [&"gangji", &"harang", &"mina", &"arin"]

## 회복이 일어나게 미리 깎아 둘 HP 비율. 만피면 회복량이 0 이라 이벤트가 안 난다.
const START_HP_RATIO: float = 0.3

const TIMEOUT_SECONDS: float = 30.0
const SAMPLE_SECONDS: float = 0.05

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await _run()

	if _failures.is_empty():
		print("PASS: 회복 연출 검증 %d개 통과" % _checks)
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: 회복 연출 %d/%d 실패" % [_failures.size(), _checks])
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("실패: " + message)


func _run() -> void:
	# 회복 스킬을 가진 캐릭터가 실제로 있어야 한다. 없으면 아래 검증이 무의미하다.
	var healers: Array[String] = []
	for id in [&"gangji", &"harang", &"mina", &"seola", &"arin", &"taehee"]:
		var data: CharacterData = CharacterDatabase.get_character(id)
		if data == null:
			continue
		for skill in data.turn_skills:
			if skill == null:
				continue
			for effect in skill.turn_effects:
				if effect != null and effect.kind == TurnSkillEffect.Kind.HEAL:
					if not healers.has(String(id)):
						healers.append(String(id))
	_expect(not healers.is_empty(),
		"회복 효과를 가진 캐릭터가 있어야 한다 — 없으면 회복 연출을 쓸 일이 없다")

	var tuning := TurnCombatConfig.tuning
	var was_enabled: bool = tuning.presentation_enabled
	var was_speed: float = tuning.presentation_speed
	tuning.presentation_enabled = true
	tuning.presentation_speed = 3.0

	var node := (load("res://stage/turn/TurnBattle.tscn") as PackedScene).instantiate()
	node.set("use_stage", false)
	node.set("battle_seed", 20260915)
	node.set("party_ids", PARTY.duplicate())
	node.set("enemy_ids", Array([&"velociraptor_beastfolk"], TYPE_STRING_NAME, "", null))
	add_child(node)

	var battle = node.get("battle")
	if battle != null:
		battle.auto_battle = true
	await get_tree().process_frame
	battle = node.get("battle")

	_expect(battle != null, "전투가 만들어져야 한다")
	if battle == null:
		_restore(tuning, was_enabled, was_speed)
		node.queue_free()
		return

	battle.auto_battle = true

	# 회복이 일어나게 깎아 둔다.
	for unit in battle.units:
		if unit.is_ally():
			unit.current_hp = maxi(int(float(unit.get_max_hp()) * START_HP_RATIO), 1)

	var seen := 0
	var amounts_positive := true
	var units_valid := true
	var elapsed := 0.0

	while elapsed < TIMEOUT_SECONDS:
		if battle.phase == TurnBattleManager.Phase.AWAITING_INPUT and battle.auto_battle:
			battle.advance()
			node.call("_play")

		# 큐가 비워지기 전에 가로챈다. 연출이 소비하면 사라진다.
		for entry in battle.presentation.events:
			if entry["event"] != PresentationQueue.Event.HEAL:
				continue
			seen += 1
			var data: Dictionary = entry["data"]
			if int(data.get("amount", 0)) <= 0:
				amounts_positive = false
			if data.get("unit") == null:
				units_valid = false

		if battle.is_over():
			break
		await get_tree().create_timer(SAMPLE_SECONDS, true, false, true).timeout
		elapsed += SAMPLE_SECONDS

	_expect(seen > 0,
		"회복이 일어나면 HEAL 이벤트가 쌓여야 한다 (관측 %d회) — 0 이면 연출이 끊긴 것이다" % seen)
	_expect(amounts_positive, "HEAL 이벤트의 회복량은 0보다 커야 한다")
	_expect(units_valid, "HEAL 이벤트에 대상 유닛이 있어야 한다")

	# 화면이 이 이벤트를 받을 준비가 되어 있는가.
	_expect(node.has_method("_play_heal"),
		"전투 화면에 _play_heal 처리가 있어야 한다 — 없으면 이벤트가 버려진다")

	# 에셋도 함께 본다. 없으면 폴백으로 떨어지지만 의도한 상태는 아니다.
	_expect(ResourceLoader.exists("res://assets/sprites/effects/battle/fx_heal.png"),
		"fx_heal 시트가 있어야 한다")
	_expect(ResourceLoader.exists("res://assets/audio/se/heal.ogg"),
		"heal.ogg 가 있어야 한다")

	_restore(tuning, was_enabled, was_speed)
	node.queue_free()
	await get_tree().process_frame


func _restore(tuning, enabled: bool, speed: float) -> void:
	tuning.presentation_enabled = enabled
	tuning.presentation_speed = speed
	Engine.time_scale = 1.0

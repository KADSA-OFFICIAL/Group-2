extends RefCounted
class_name TurnBattleManager

# 턴제 전투의 **전체 흐름 상태 기계** (#450).
#
# 전투 1회의 생애주기:
# ```
# [준비 페이즈] 준비 포인트 사용 → 선공/피습 결정
#        ↓
# [전투 개시] 초기 AV 산정 → 타임라인 생성 → 적 예고 생성
#        ↓
# ┌───── 턴 루프 ────────────────────────────────┐
# │ 1. 타임라인 최전방 유닛 결정                   │
# │ 2. 턴 시작 트리거 (DoT · 지속시간 감소 · 격파)  │
# │ 3. 행동 선택 (일반공격 / 전투 스킬)             │
# │    ※ 오의는 이 루프와 무관하게 아무 때나        │
# │ 4. 데미지·효과 처리 → 자물쇠·격파 판정          │
# │ 5. 턴 종료 트리거                             │
# │ 6. AV 재산정, 타임라인 갱신                    │
# └──────────────────────────────────────────────┘
#        ↓
# [전투 종료] 보상 / 소모 자원 정산
# ```
#
# **입력 제한시간이 없다.** 아군 차례가 오면 `AWAITING_INPUT` 상태로 멈추고, 화면이
# `act()`를 불러 줄 때까지 기다린다. 그래서 이 클래스는 노드가 아니어도 되고,
# 헤드리스에서 정책 함수로 자동 진행시켜 테스트할 수 있다.
#
# 참고: docs/turn-combat-design.md §전투 흐름

# ===== 상태 (Phase) =====
enum Phase {
	IDLE,            # 전투 전
	PREP,            # 준비 페이즈 (준비 포인트 사용)
	TURN_START,      # 턴 시작 트리거 처리 중
	AWAITING_INPUT,  # 아군 차례 — 입력 대기 (제한시간 없음)
	RESOLVING,       # 행동 처리 중
	TURN_END,
	VICTORY,
	DEFEAT,
}

var phase: Phase = Phase.IDLE

# ===== 시스템 (Systems) =====
var rng := RandomNumberGenerator.new()
var timeline := TimelineSystem.new()
var ranks := RankSystem.new()
var resources := TurnResourceSystem.new()
var pipeline: DamagePipeline = null
var statuses: TurnStatusSystem = null
var toughness: ToughnessSystem = null
var resolver := SkillResolver.new()
var ai := TurnEnemyAI.new()
var presentation: PresentationQueue = null

# ===== 유닛 (Units) =====
var units: Array[TurnUnit] = []

## 지금 행동 중인 유닛. `AWAITING_INPUT`에서 이 유닛의 스킬을 고른다.
var active_unit: TurnUnit = null
## 지금 턴이 추가 턴인가. 타임라인 리필 여부를 정한다.
var active_is_extra: bool = false

# ===== 기록 (Records) =====

## 전투 로그. 각 줄은 `DamageContext.summary()`나 시스템 메시지다.
var battle_log: Array[String] = []

## 전투 통계. 결과 화면(캐릭터별 딜 · 격파 횟수 · 사이클 수)이 읽는다.
var stats: Dictionary = {}

## 준비 포인트. 전투 진입 전에 쓴다.
var prep_points: int = 3

## 자동 전투인가.
var auto_battle: bool = false

## 사이클 제한. 이 사이클을 넘기면 패배한다. 0이면 제한 없음.
##
## 왜 필요한가 (실제로 겪은 문제): 파티에 힐러가 있고 적이 보스 한 마리면 **양쪽이 서로를
## 죽이지 못하는 교착**이 생긴다. 자동 전투로 돌려 보니 수천 턴이 지나도 끝나지 않았다.
## 제한이 없으면 그것은 버그가 아니라 "아주 긴 전투"로 보여서 눈에 띄지 않는다.
##
## 설계서 §12 의 엔드게임은 어차피 "사이클 제한 내 클리어"로 채점하므로, 제한은
## 이 시스템에 원래 있어야 하는 축이다. 스테이지가 값을 정한다.
var cycle_limit: int = 0

## 유닛별 누적 턴 수. `unit_id` -> 턴 수. 특성 주기 판정이 읽는다.
var _turn_counts: Dictionary = {}

# ===== 웨이브 (Waves) =====
#
# 전투는 "적 여러 무리"일 수 있다. 한 무리를 전멸시키면 다음 무리가 등장하고,
# **아군의 HP·오의 게이지·상태이상은 그대로 이어진다** — 웨이브 구조의 의미가 그것이다
# (무리마다 회복시켜 주면 웨이브가 그냥 별개 전투 여러 개가 된다).
#
# 웨이브를 전투가 소유하는 이유: `_check_end()` 가 "적이 없으면 승리"를 판정하는데,
# 그 판단에 "남은 웨이브가 있는가"가 함께 들어가야 한다. 밖에서 콜백으로 끼워 넣으면
# 승리 신호가 웨이브마다 한 번씩 나가 결과 화면이 여러 번 뜬다.
#
# `Array[Array[EnemyData]]` 로 두고 싶지만 GDScript 는 중첩 타입 배열을 지원하지 않는다.
var pending_waves: Array = []

## 지금 몇 번째 웨이브인가 (0부터).
var wave_index: int = 0
## 이 전투의 전체 웨이브 수.
var wave_total: int = 1

## 웨이브가 놓였을 때. `func(index: int, total: int) -> void`.
##
## 전투는 스테이지를 모른다 — `StageWave` 리소스를 아는 것은 화면 쪽이므로,
## 여기서는 번호만 알리고 `EventBus.stage_wave_started` 는 화면이 쏜다.
var on_wave_started: Callable = Callable()


func _tuning() -> TurnCombatTuning:
	return PlayerStats.get_tuning_turn()


# EventBus. 이 클래스는 RefCounted 라 씬 트리 밖에서도 살아 있을 수 있으므로
# (에디터 툴 · 밸런스 시뮬레이터) 없을 때를 견뎌야 한다. 없으면 신호를 그냥 보내지 않는다.
func _bus() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null


func _signal(signal_name: StringName, args: Array = []) -> void:
	var bus := _bus()
	if bus == null:
		return
	bus.callv("emit_signal", [signal_name] + args)


# ===== 개시 (Start) =====

# 전투를 시작한다.
#
# `ambush`: 1 = 선공(아군 이득), -1 = 피습(적 이득), 0 = 일반 조우.
#           전투 밖 행동이 전투 안 유불리로 연결되는 접합부다.
# `seed_value`: 결정론적 RNG 시드. 같은 시드는 같은 전투를 재현한다 — 리플레이와
#               버그 재현에 필수이고, 헤드리스 테스트가 이것에 의존한다.
# `party_level`: 0이면 **조우의 레벨에 맞춘다**(가장 높은 적의 레벨).
#
# 왜 0을 기본으로 두는가 (실제로 겪은 문제): 파티 레벨은 방어계수의 분모
# (`150 + 8 x 공격자레벼`)에 들어간다. 처음에 `PlayerProfile.deltoid_level`(1부터
# 시작하는 삼각근 Lv.)을 넣어 봤더니 분모가 158이 되어 방어력 620인 보스에게 피해가
# 20%만 들어갔다 — 파티가 보스를 785번 때려야 했다.
#
# 삼각근 Lv.은 **성장 채널**(기초 스텟 배수)이고 전투 레벨이 아니다. 캐릭터 레벨
# 시스템은 아직 없으므로(Phase 2), 그때까지는 조우 레벨을 파티 레벨로 쓴다 —
# "레벨이 맞는 상대와 싸운다"가 기본 가정이어야 방어계수가 의미를 갖는다.
func start(party: Array[CharacterData], enemies: Array[EnemyData],
		ambush: int = 0, seed_value: int = 0, party_level: int = 0) -> void:
	rng.seed = seed_value

	var level := party_level
	if level <= 0:
		level = 1
		for enemy in enemies:
			if enemy != null:
				level = maxi(level, enemy.turn_level)

	var t := _tuning()
	presentation = PresentationQueue.new(t.presentation_enabled, t.presentation_speed)
	pipeline = DamagePipeline.new(rng, resources)
	statuses = TurnStatusSystem.new(rng, pipeline)
	toughness = ToughnessSystem.new(rng, pipeline, statuses)

	units.clear()
	battle_log.clear()
	_turn_counts.clear()
	wave_index = 0
	wave_total = 1 + pending_waves.size()
	stats = {
		"cycles": 1, "turns": 0, "breaks": 0, "locks_cleared": 0,
		"nullified": 0, "damage_by_unit": {}, "kills": 0,
	}

	# --- 유닛 생성 ---
	var rank := 1
	for character in party:
		if character == null:
			continue
		if rank > TurnCombat.ALLY_RANK_COUNT:
			break
		# 선호 랭크가 있으면 그것을 시도한다. 겹치면 `RankSystem.place()`가 정리한다.
		var wanted := rank
		if not character.preferred_ranks.is_empty():
			wanted = int(character.preferred_ranks[0])
		var unit := TurnUnit.from_character(character, wanted, "", level)
		units.append(unit)
		rank += 1

	var enemy_index := 1
	for enemy in enemies:
		if enemy == null:
			continue
		if enemy_index > TurnCombat.ENEMY_RANK_COUNT:
			break
		var unit := TurnUnit.from_enemy(enemy, enemy_index, "#%d" % enemy_index)
		units.append(unit)
		enemy_index += 1

	# --- 시스템 배선 ---
	ranks = RankSystem.new()
	ranks.place(units)

	# 특성으로 확장되는 공명 상한을 모은다.
	var extra_rp := 0
	for unit in units:
		if unit.character == null:
			continue
		for trait_skill in unit.character.get_turn_skills(TurnCombat.ActionKind.TRAIT):
			for effect in trait_skill.turn_effects:
				if effect != null and effect.kind == TurnSkillEffect.Kind.RESONANCE \
						and effect.duration < 0:
					extra_rp += effect.amount
	resources.reset(extra_rp)

	resolver.rng = rng
	resolver.ranks = ranks
	resolver.timeline = timeline
	resolver.resources = resources
	resolver.statuses = statuses
	resolver.toughness = toughness
	resolver.pipeline = pipeline
	resolver.units = units

	ai.rng = rng
	ai.ranks = ranks
	ai.resolver = resolver
	ai.toughness = toughness

	statuses.on_damage = _on_status_damage
	toughness.on_break = _on_break
	toughness.on_lock_cleared = _on_lock_cleared
	toughness.on_nullified = _on_nullified

	for unit in units:
		statuses.reset(unit)

	# --- 초기 AV ---
	# 선공은 적 전체를 지연시키고, 피습은 아군을 지연시킨다.
	var ally_offset := 0.0
	var enemy_offset := 0.0
	if ambush > 0:
		enemy_offset = 0.25
	elif ambush < 0:
		ally_offset = 0.25
	timeline.reset(units, ally_offset, enemy_offset)

	# --- 적 예고 ---
	for unit in units:
		if unit.is_enemy():
			unit.intent = ai.build_intent(unit, units)

	resources.roll_recommendation(rng)

	_note("전투 개시 — 아군 %d명 vs 적 %d명%s"
		% [ranks.living(TurnCombat.Side.ALLY).size(),
			ranks.living(TurnCombat.Side.ENEMY).size(),
			("  (선공)" if ambush > 0 else ("  (피습)" if ambush < 0 else ""))])
	if not resources.recommendation_label().is_empty():
		_note("권장 행동: " + resources.recommendation_label())

	presentation.push(PresentationQueue.Event.CYCLE_START, {"cycle": 1})
	if on_wave_started.is_valid():
		on_wave_started.call(wave_index, wave_total)
	_signal(&"turn_battle_started", [seed_value])
	_signal(&"turn_cycle_started", [1])
	_signal(&"turn_resonance_changed", [resources.resonance, resources.resonance_max])
	phase = Phase.PREP


# ===== 준비 페이즈 (Prep) =====

# 준비 포인트를 소모해 전투 시작 전 이득을 얻는다 (HSR 비술 대응).
#
# `kind`: "energy"(오의 게이지 50%) / "toughness"(적 1체 인성치 -50%) /
#         "shield"(아군 전체 보호막) / "advance"(아군 전체 선제)
func use_prep(kind: String, target_index: int = 0) -> bool:
	if phase != Phase.PREP or prep_points <= 0:
		return false

	var allies := ranks.living(TurnCombat.Side.ALLY)
	var enemies := ranks.living(TurnCombat.Side.ENEMY)

	match kind:
		"energy":
			for unit in allies:
				resources.gain_energy(unit, int(round(float(unit.get_energy_max()) * 0.5)))
			_note("준비: 아군 전체 오의 게이지 50%")

		"toughness":
			if enemies.is_empty():
				return false
			var target: TurnUnit = enemies[clampi(target_index, 0, enemies.size() - 1)]
			target.toughness = maxi(target.toughness - target.max_toughness / 2, 0)
			_note("준비: %s 인성치 -50%%" % target.display_name)

		"shield":
			for unit in allies:
				var shield := TurnStatus.new(&"prep_shield", TurnStatus.Kind.SHIELD, 2)
				shield.display_name = "준비 보호막"
				shield.shield_amount = int(round(float(unit.get_max_hp()) * 0.12))
				statuses.apply(null, unit, shield)
			_note("준비: 아군 전체 보호막")

		"advance":
			for unit in allies:
				timeline.advance_action(unit, 0.3)
				unit.advance_streak = 0  # 준비 단계의 앞당김은 연속 카운터를 소모하지 않는다.
			_note("준비: 아군 전체 행동 앞당김 30%")

		_:
			return false

	prep_points -= 1
	return true


# 준비 페이즈를 끝내고 턴 루프를 시작한다.
func begin_battle() -> void:
	if phase != Phase.PREP:
		return
	phase = Phase.TURN_START
	advance()


# ===== 턴 루프 (Turn loop) =====

## 한 번의 `advance()` 가 처리할 턴 수 상한. 넘으면 경고하고 멈춘다.
##
## 무한 루프 방지용 안전장치다. 정상 전투는 수십 턴이고, 교착은 `cycle_limit` 이 잡는다.
const ADVANCE_GUARD := 4000

# 아군 입력이 필요한 지점까지, 또는 전투가 끝날 때까지 진행한다.
#
# **루프이고 재귀가 아니다.** 처음에는 `_end_turn()` 이 다시 `advance()` 를 부르는 재귀였는데,
# 자동 전투에서 턴마다 스택이 3프레임씩 쌓여 긴 전투가 GDScript 호출 깊이 상한(1024)에
# 부딪혔다. 게다가 `begin_battle()` 한 번에 전투 전체가 동기적으로 끝나 버려서,
# 화면이 연출을 재생할 틈이 없었다.
func advance() -> void:
	var guard := 0
	while guard < ADVANCE_GUARD:
		guard += 1
		if not _step():
			return
	push_warning("TurnBattleManager: 한 번의 advance() 가 %d턴을 넘겼습니다(중단)."
		% ADVANCE_GUARD)


# 한 턴을 진행한다.
#
# 반환: 계속 진행해야 하면 true. 아군 입력 대기나 전투 종료면 false.
func _step() -> bool:
	if _check_end():
		return false

	var previous_cycle := timeline.current_cycle()

	active_unit = timeline.advance_to_next()
	if active_unit == null:
		_note("행동할 수 있는 유닛이 없습니다.")
		phase = Phase.DEFEAT
		return false

	# `is_pending_extra()` 로 물어보면 안 된다 — `advance_to_next()` 가 대기열에서
	# 방금 꺼낸 뒤라 항상 false 다. 그래서 추가 턴마다 AV 가 리필되어 추가 턴이
	# 정상 턴을 먹고 있었다 (#495).
	active_is_extra = timeline.current_is_extra

	var cycle := timeline.current_cycle()
	if cycle != previous_cycle:
		stats["cycles"] = cycle
		resources.roll_recommendation(rng)
		presentation.push(PresentationQueue.Event.CYCLE_START, {"cycle": cycle})
		_signal(&"turn_cycle_started", [cycle])
		_note("─── %d 사이클 ───" % cycle)
		if not resources.recommendation_label().is_empty():
			_note("권장 행동: " + resources.recommendation_label())

	phase = Phase.TURN_START
	_turn_start(active_unit)

	if _check_end():
		return false

	# 턴 시작 트리거로 죽거나 행동 불가가 되었으면 턴을 넘긴다.
	if not active_unit.alive or not active_unit.can_act():
		if active_unit.alive:
			_note("%s 는 행동할 수 없다 (%s)"
				% [active_unit.display_name, active_unit.blocked_reason()])
		_end_turn()
		return true

	stats["turns"] = int(stats["turns"]) + 1
	resources.on_turn_start(active_unit)
	resolver.reset_trait_fires()
	presentation.push(PresentationQueue.Event.TURN_START, {"unit": active_unit})
	_signal(&"turn_started", [active_unit])

	# 이 유닛이 지금까지 행동한 턴 수. 특성 주기 판정에 쓴다
	# (「연산 보조」처럼 "2턴마다 1회"인 특성이 있다).
	var turn_index := int(_turn_counts.get(active_unit.unit_id, 0)) + 1
	_turn_counts[active_unit.unit_id] = turn_index

	_absorb_all(resolver.fire_traits(active_unit,
		SkillData.TraitTrigger.TURN_START, null, turn_index))
	if _check_end():
		return false

	if active_unit.is_enemy():
		_enemy_turn()
		return true

	if auto_battle:
		_auto_ally_turn()
		return true

	# **아군 차례 — 입력 대기.** 여기서 멈춘다. 입력 제한시간은 없다.
	phase = Phase.AWAITING_INPUT
	return false


# 턴 시작 트리거: 지속 피해 → 지속시간 감소 → 격파 기절/회복.
func _turn_start(unit: TurnUnit) -> void:
	var dots := statuses.tick_turn_start(unit, units)
	for ctx in dots:
		_record_damage(ctx)
		presentation.push_hit(ctx, "basic")
		_note(ctx.summary())
		if ctx.killed:
			_on_death(ctx.target)

	if not unit.alive:
		return

	var break_tick := toughness.tick_turn_start(unit)
	if bool(break_tick["recovered"]):
		_note("%s 의 격파가 풀렸다 (인성치 %d 회복)"
			% [unit.display_name, unit.max_toughness])
		_signal(&"turn_break_recovered", [unit])
		# 격파가 풀리면 예고와 자물쇠를 새로 만든다.
		if unit.is_enemy():
			unit.intent = ai.build_intent(unit, units)


# ===== 아군 행동 (Ally action) =====

# 아군이 행동한다. 화면이 부른다.
#
# 반환: `SkillResolver.execute()`의 결과.
func act(skill: SkillData, target: TurnUnit = null) -> Dictionary:
	if phase != Phase.AWAITING_INPUT or active_unit == null:
		return {"ok": false, "reason": "지금은 행동할 수 없습니다"}

	phase = Phase.RESOLVING
	var result := _run(active_unit, skill, target)

	if not bool(result["ok"]):
		phase = Phase.AWAITING_INPUT
		return result

	if bool(result["consumed_turn"]):
		_end_turn()
		# 다음 아군 입력 지점(또는 전투 종료)까지 진행한다. 화면은 이 사이에 쌓인
		# 연출 큐를 재생한다.
		advance()
	else:
		# 턴을 소모하지 않는 행동(오의)이면 같은 유닛의 입력 대기로 돌아온다.
		phase = Phase.AWAITING_INPUT

	return result


# **오의를 발동한다. 턴 순서와 무관하게 언제든 부를 수 있다.**
#
# 이 하나로 턴제 게임이 "순서 기다리기"에서 "타이밍 게임"으로 승격된다.
# 적 큰 공격 직전에 보호막을 깔거나, 아군 턴 중간에 버프를 넣어 그 공격에 태우거나,
# 격파 직전에 넣어 타이밍을 조율할 수 있다. 설계서가 "절대 버리면 안 되는 1순위 요소"로
# 꼽은 것이고, `phase` 검사를 느슨하게 두는 이유도 그것이다.
func use_ultimate(unit: TurnUnit) -> Dictionary:
	if phase == Phase.VICTORY or phase == Phase.DEFEAT or phase == Phase.IDLE:
		return {"ok": false, "reason": "전투가 진행 중이 아닙니다"}
	if unit == null or unit.character == null:
		return {"ok": false, "reason": "오의를 쓸 수 없는 유닛입니다"}

	var ultimate := unit.character.get_turn_ultimate()
	if ultimate == null:
		return {"ok": false, "reason": "오의가 없습니다"}
	if not resources.can_use_ultimate(unit, ultimate):
		return {"ok": false, "reason": resources.ultimate_blocked_reason(unit, ultimate)}

	presentation.push(PresentationQueue.Event.ULTIMATE_CUTIN, {
		"unit": unit,
		"skill": ultimate,
		"steps": PresentationQueue.ultimate_cutin_steps(unit, ultimate),
	})

	# 대상은 자동으로 고른다 — 오의는 턴 밖 발동이라 조준 UI를 띄우면 시간이 멈춘 것처럼
	# 보이고, 대부분의 오의가 전체/아군전체다. 단일 오의는 어그로 규칙으로 고른다.
	var target: TurnUnit = null
	if ultimate.needs_target_pick():
		var candidates := ranks.valid_targets(unit, ultimate)
		if not candidates.is_empty():
			target = candidates[0]

	var previous := phase
	phase = Phase.RESOLVING
	var result := _run(unit, ultimate, target)
	if previous == Phase.AWAITING_INPUT:
		phase = Phase.AWAITING_INPUT
	else:
		phase = previous

	_check_end()
	return result


# ===== 적 행동 (Enemy turn) =====

func _enemy_turn() -> void:
	phase = Phase.RESOLVING
	var result := ai.act(active_unit, units)
	_absorb(result)
	_end_turn()


func _auto_ally_turn() -> void:
	phase = Phase.RESOLVING

	# 자동 전투도 오의를 먼저 판단한다 — 게이지가 넘쳐 낭비되지 않게.
	if ai.should_use_ultimate(active_unit):
		var ultimate := active_unit.character.get_turn_ultimate()
		_run(active_unit, ultimate, null)

	var choice := ai.choose_ally_action(active_unit, units)
	var skill: SkillData = choice["skill"]
	if skill == null:
		_note("%s 는 할 수 있는 행동이 없다" % active_unit.display_name)
		_end_turn()
		return

	_run(active_unit, skill, choice["target"])
	_end_turn()


# ===== 공통 실행 (Run) =====

func _run(unit: TurnUnit, skill: SkillData, target: TurnUnit) -> Dictionary:
	presentation.push(PresentationQueue.Event.SKILL_CAST, {
		"unit": unit, "skill": skill, "target": target,
		"camera": PresentationQueue.camera_for(
			"ultimate" if skill != null and skill.is_turn_ultimate() else "ally_skill"),
	})

	var result := resolver.execute(unit, skill, target)
	_absorb(result)
	return result


# 여러 실행 결과를 한꺼번에 반영한다 (특성이 여러 개 터질 수 있다).
func _absorb_all(results: Array[Dictionary]) -> void:
	for result in results:
		_absorb(result)


# 실행 결과를 로그·통계·연출 큐에 반영한다.
func _absorb(result: Dictionary) -> void:
	if not result.has("logs"):
		return

	for line in result["logs"]:
		_note(String(line))

	var feedback_key := "skill"
	for ctx in result.get("damage", []):
		_record_damage(ctx)
		if ctx.is_break_damage or ctx.is_overbreak:
			feedback_key = "break"
		elif ctx.skill != null:
			feedback_key = PresentationQueue.feedback_key_for_action(ctx.skill.turn_action)
		presentation.push_hit(ctx, feedback_key)

	for unit in result.get("kills", []):
		_on_death(unit)

	stats["nullified"] = int(stats["nullified"]) + result.get("nullified", []).size()

	if not bool(result.get("ok", true)):
		_note("실패: " + String(result.get("reason", "")))


# ===== 턴 종료 (Turn end) =====

# 턴을 마무리한다. **다음 턴으로 넘어가지 않는다** — 진행은 `advance()` 의 루프가 한다.
func _end_turn() -> void:
	if active_unit == null:
		phase = Phase.TURN_END
		return

	presentation.push(PresentationQueue.Event.TURN_END, {"unit": active_unit})
	_signal(&"turn_ended", [active_unit])
	resources.decay_heat()
	_signal(&"turn_heat_changed", [resources.heat, resources.heat_zone()])
	timeline.on_turn_finished(active_unit, active_is_extra)
	active_unit = null
	active_is_extra = false

	phase = Phase.TURN_END


# ===== 웨이브 (Waves) =====

# 다음 웨이브를 투입한다. 아군은 그대로 두고 적만 새로 놓는다.
func _advance_wave() -> void:
	var wave: Array = pending_waves.pop_front()
	wave_index += 1

	# 지난 웨이브의 적을 **배열에서도** 치운다.
	#
	# 예전에는 `timeline.remove_unit()` 의 부작용(같은 배열을 erase 했다)에 기대고
	# 있었다. 그 부작용을 없앴으므로(#497) 배열을 소유한 이쪽이 직접 치운다.
	# 안 치우면 쓰러진 지난 웨이브 적이 `ranks.place()` 에서 다시 자리를 차지해
	# 새 웨이브 적이 앉을 칸이 모자란다.
	for unit in units.duplicate():
		if unit.is_enemy():
			ranks.remove(unit)
			timeline.remove_unit(unit)
			units.erase(unit)

	var index := 1
	for data in wave:
		if data == null:
			continue
		if index > TurnCombat.ENEMY_RANK_COUNT:
			break
		# `unit_id` 에 웨이브 번호를 넣는다 — 같은 적이 웨이브마다 나오면 id 가 겹치고,
		# 타임라인의 AV 딕셔너리가 앞 웨이브의 값을 그대로 쓴다.
		var unit := TurnUnit.from_enemy(data, index, "#w%d_%d" % [wave_index, index])
		units.append(unit)
		statuses.reset(unit)
		index += 1

	ranks.place(units)

	for unit in units:
		if not unit.is_enemy():
			continue
		# 초기 AV 를 최대치의 60% 로 둔다. 0이면 등장 즉시 행동해 억울하고,
		# 최대치면 한 사이클을 통째로 낭비한다.
		timeline.add_unit(unit, 0.6)
		unit.intent = ai.build_intent(unit, units)

	_note("─── %d/%d 웨이브 ───" % [wave_index + 1, wave_total])
	presentation.push(PresentationQueue.Event.CYCLE_START,
		{"cycle": timeline.current_cycle(), "wave": wave_index + 1})
	if on_wave_started.is_valid():
		on_wave_started.call(wave_index, wave_total)

	phase = Phase.TURN_END


# ===== 종료 판정 (End check) =====

func _check_end() -> bool:
	if phase == Phase.VICTORY or phase == Phase.DEFEAT:
		return true

	var allies := ranks.living(TurnCombat.Side.ALLY)
	var enemies := ranks.living(TurnCombat.Side.ENEMY)

	if enemies.is_empty() and not pending_waves.is_empty():
		_advance_wave()
		return false

	if enemies.is_empty():
		phase = Phase.VICTORY
		_note("승리 — %d 사이클, %d턴, 격파 %d회"
			% [timeline.current_cycle(), int(stats["turns"]), int(stats["breaks"])])
		presentation.push(PresentationQueue.Event.BATTLE_END, {"victory": true})
		_signal(&"turn_battle_ended", [true, result_summary()])
		return true

	if allies.is_empty():
		phase = Phase.DEFEAT
		_note("패배 — 파티 전멸")
		presentation.push(PresentationQueue.Event.BATTLE_END, {"victory": false})
		_signal(&"turn_battle_ended", [false, result_summary()])
		return true

	if cycle_limit > 0 and timeline.current_cycle() > cycle_limit:
		phase = Phase.DEFEAT
		_note("패배 — 사이클 제한 %d 초과" % cycle_limit)
		presentation.push(PresentationQueue.Event.BATTLE_END,
			{"victory": false, "reason": "cycle_limit"})
		_signal(&"turn_battle_ended", [false, result_summary()])
		return true

	return false


func is_over() -> bool:
	return phase == Phase.VICTORY or phase == Phase.DEFEAT


# ===== 콜백 (Callbacks) =====

func _on_break(unit: TurnUnit, element: int, ctx: DamageContext) -> void:
	stats["breaks"] = int(stats["breaks"]) + 1
	presentation.push_break(unit, element, ctx)
	_signal(&"turn_weakness_broken", [unit, element])


func _on_lock_cleared(unit: TurnUnit, lock: TurnLock, index: int, total: int) -> void:
	stats["locks_cleared"] = int(stats["locks_cleared"]) + 1
	presentation.push_lock_cleared(unit, lock, index, total)
	_signal(&"turn_lock_cleared", [unit, lock, index, total])


func _on_nullified(unit: TurnUnit) -> void:
	presentation.push(PresentationQueue.Event.NULLIFIED, {"unit": unit})
	_signal(&"turn_action_nullified", [unit])


func _on_status_damage(ctx: DamageContext) -> void:
	# `tick_turn_start`가 반환한 것을 `_turn_start`에서 이미 처리하므로 여기서는
	# 스킬 실행 중 발생한 지속 피해(폭발 등)만 기록한다. 중복 기록을 피하려고
	# 로그에는 남기지 않는다 — `SkillResolver`가 자기 로그에 이미 넣었다.
	pass


func _on_death(unit: TurnUnit) -> void:
	stats["kills"] = int(stats["kills"]) + 1
	presentation.push(PresentationQueue.Event.DEATH, {"unit": unit})
	_signal(&"turn_death", [unit])
	ranks.remove(unit)
	timeline.remove_unit(unit)


func _record_damage(ctx: DamageContext) -> void:
	if ctx.source == null:
		return
	var by_unit: Dictionary = stats["damage_by_unit"]
	var id := ctx.source.unit_id
	by_unit[id] = int(by_unit.get(id, 0)) + ctx.final_damage()
	_signal(&"turn_damage_dealt", [ctx])


func _note(line: String) -> void:
	battle_log.append(line)
	presentation.push_log(line)


# ===== 조회 (Queries for UI) =====

func allies() -> Array[TurnUnit]:
	return ranks.living(TurnCombat.Side.ALLY)


func enemies() -> Array[TurnUnit]:
	return ranks.living(TurnCombat.Side.ENEMY)


func find_unit(id: StringName) -> TurnUnit:
	for unit in units:
		if unit.unit_id == id:
			return unit
	return null


# 지금 행동자가 쓸 수 있는 행동 목록. 액션 바가 그대로 그린다.
#
# 반환: `[{"skill": SkillData, "ok": bool, "reason": String, "locks": int}, ...]`
# `locks`는 이 스킬로 열 수 있는 자물쇠 개수다 — 매 턴의 미니 퍼즐을 위해 버튼에 띄운다.
func available_actions(unit: TurnUnit = null) -> Array[Dictionary]:
	var actor := unit if unit != null else active_unit
	var out: Array[Dictionary] = []
	if actor == null or actor.character == null:
		return out

	var candidates: Array[SkillData] = []
	var basic := actor.character.get_turn_basic()
	if basic != null:
		candidates.append(basic)
	candidates.append_array(actor.character.get_turn_skills(TurnCombat.ActionKind.SKILL))
	var ultimate := actor.character.get_turn_ultimate()
	if ultimate != null:
		candidates.append(ultimate)

	for skill in candidates:
		var entry := {"skill": skill, "ok": true, "reason": "", "locks": 0}

		if skill.is_turn_ultimate():
			entry["ok"] = resources.can_use_ultimate(actor, skill)
			entry["reason"] = resources.ultimate_blocked_reason(actor, skill)
		else:
			var usable := ranks.check_usable(actor, skill)
			entry["ok"] = bool(usable["ok"])
			entry["reason"] = String(usable["reason"])
			if bool(entry["ok"]) and skill.rp_cost > resources.resonance:
				entry["ok"] = false
				entry["reason"] = "공명 포인트 %d/%d" % [resources.resonance, skill.rp_cost]

		# 자물쇠를 가장 많이 여는 대상 기준으로 표시한다.
		var best := 0
		for target in ranks.valid_targets(actor, skill):
			if target.is_ally():
				continue
			best = maxi(best, toughness.count_openable_locks(actor, skill, target))
		entry["locks"] = best

		out.append(entry)

	return out


# **스킬 호버 프리뷰** — 이 스킬을 쓰면 순서가 어떻게 바뀌는가 (설계서 §4.2.5).
#
# 반환: `{"order": Array[TurnUnit], "expected": Dictionary, "locks": int}`
func preview_action(skill: SkillData, target: TurnUnit = null,
		unit: TurnUnit = null) -> Dictionary:
	var actor := unit if unit != null else active_unit
	if actor == null or skill == null:
		return {"order": [] as Array[TurnUnit], "expected": {}, "locks": 0}

	var effects := resolver.timeline_effects(actor, skill, target)
	var order := timeline.preview_if_acted(actor, effects["av_changes"],
		bool(effects["grants_extra"]), skill.consumes_turn())

	var locks := 0
	if target != null:
		locks = toughness.count_openable_locks(actor, skill, target)

	return {
		"order": order,
		"expected": resolver.expected_damage(actor, skill, target),
		"locks": locks,
	}


# 전투 결과 요약. 결과 화면이 읽는다 (설계서 §11.4).
func result_summary() -> Dictionary:
	var by_name: Dictionary = {}
	var by_unit: Dictionary = stats["damage_by_unit"]
	for id in by_unit:
		var unit := find_unit(id)
		var label := String(id) if unit == null else unit.display_name
		by_name[label] = by_unit[id]

	return {
		"victory": phase == Phase.VICTORY,
		"waves": wave_index + 1,
		"wave_total": wave_total,
		"cycles": timeline.current_cycle(),
		"turns": stats["turns"],
		"breaks": stats["breaks"],
		"locks_cleared": stats["locks_cleared"],
		"nullified": stats["nullified"],
		"damage": by_name,
		"resonance_spent": resources.stats_resonance_spent,
		"resonance_bankrupt_turns": resources.stats_bankrupt_turns,
	}


func describe() -> String:
	var lines: Array[String] = []
	lines.append("[%s] %s" % [Phase.keys()[phase], resources.describe()])
	lines.append(ranks.describe())
	for unit in units:
		if unit.alive:
			lines.append("  " + unit.describe())
	lines.append(timeline.describe())
	return "\n".join(lines)

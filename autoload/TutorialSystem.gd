extends Node

# 튜토리얼 진행의 단일 출처 (autoload).
#
# 책임 셋:
#   1. data/tutorial 의 시퀀스(.tres)를 로드해 stage_id 로 조회한다.
#   2. 지금 몇 번째 단계인지, 그 단계의 조건이 채워졌는지 판정한다.
#   3. 단계가 떠 있는 동안 전투를 멈춘다.
#
# 하지 않는 것:
#   - **그리지 않는다.** 화면은 HUD 가 step_changed / finished 신호를 받아 그린다.
#     (여기서 Control 을 만들면 전투 화면 밖에서도 튜토리얼이 UI 를 들고 다니게 된다.)
#   - **안내 문구를 만들지 않는다.** 문구는 TutorialStepData 저작본이 출처다.
#   - **조건을 새로 판정하지 않는다.** 표식·기절·처형·대시가 일어났다는 사실은 이미
#     EventBus 신호로 흐르고 있고, 여기서는 그것을 세기만 한다.
#
# 왜 GuideSystem 과 따로인가: GuideSystem 은 **전투 밖에서 "다음에 할 일"** 을 판정한다
# (편성·제조·장비). 이쪽은 전투 안에서 순서가 있는 단계를 진행한다 — 진행 인덱스를
# 상태로 들고 있고 전투를 멈춘다. 한 파일에 두면 "지금 뭘 해야 하나"와 "튜토리얼 몇
# 번째인가"가 한 판정에 섞인다.
#
# 참고: entities/tutorial/TutorialSequenceData.gd, ui/HUD.gd, docs/combat-screen-design.md §8

const TUTORIALS_DIR := "res://data/tutorial"

# 저장 키. 완료한 시퀀스를 기록해 두 번 띄우지 않는다.
const SAVE_KEY := "tutorial"

# 확인 키로 넘기는 단계에서 받는 입력.
const CONFIRM_ACTION := "ui_accept"

# 지금 보여 줄 단계나 그 단계의 상태가 바뀌었다(시작 포함). 화면은 이 신호로만 갱신한다.
#
# reading=true 면 **읽는 중**이다 — 전투가 멈춰 있고 확인 키를 기다린다.
# reading=false 면 **하는 중**이다 — 전투가 흐르고, 저작된 조건이 달성되기를 기다린다.
signal step_changed(step: TutorialStepData, index: int, total: int, reading: bool)

# 시퀀스가 끝났다(또는 중단됐다). 화면은 패널을 숨긴다.
signal finished(stage_id: StringName)

# (턴제) 이 아군의 차례를 당겨 달라. 전투 화면이 타임라인에 전한다(#594).
# 튜토리얼은 전투를 모른다 — 누가 행동해야 하는지만 말한다.
signal turn_actor_requested(actor_id: StringName)

# stage_id(StringName) -> TutorialSequenceData  (실시간)
var _sequences: Dictionary = {}

# stage_id(StringName) -> TutorialSequenceData  (턴제, #594)
#
# 같은 스테이지에 두 전투의 안내가 나란히 있다. 한 사전에 넣으면 stage_id 가 겹쳐
# 둘 중 하나가 "중복"으로 버려진다.
var _turn_sequences: Dictionary = {}

# 완료한 stage_id 집합. Dictionary 를 집합처럼 쓴다(GDScript 에 Set 이 없다).
var _completed: Dictionary = {}

# ----- 진행 상태 (Runtime) -----
var _active: TutorialSequenceData = null
var _index: int = 0
# 지금 단계의 조건이 몇 번 성립했는지. required_count 에 닿으면 넘어간다.
var _progress: int = 0

# 단계가 두 국면을 갖는 이유 (읽는 중 -> 하는 중):
#
# 단계마다 전투를 멈춰야 글을 읽을 수 있는데, **멈춘 채로는 대시도 평타도 할 수 없다.**
# 정지 하나로 끝내면 "대시해 보자"는 단계에서 게임이 영영 멈춰 있게 된다.
# 그래서 먼저 멈춰서 읽히고(확인 키), 확인하면 전투를 다시 흘려 조건을 기다린다.
# 그동안 패널은 목표를 계속 띄워 둔다.
var _reading: bool = false

# ----- 턴제 진행 상태 (#594) -----
#
# 턴제는 트리를 멈추지 않는다. 전투 화면이 **스스로 기다리는** 구조라(입력 대기에 제한시간이
# 없다) 멈출 필요가 없고, 트리를 멈추면 하이라이트·대사 패널의 연출까지 얼어 버린다.
# 대신 전투 화면이 `is_holding_turn_battle()` 을 보고 진행 루프를 세운다.
var _turn_mode: bool = false

# 단계가 바뀌었지만 아직 띄우지 않았다. 띄우는 시점은 전투 화면이 정한다 — 연출이 다 끝나고
# 아군이 입력을 기다리는 순간(`turn_ready_point`)이다. 타격 연출 도중에 패널이 튀어나오면
# 무엇이 일어났는지를 놓친다.
var _pending_show: bool = false


func _ready() -> void:
	name = "TutorialSystem"

	# 단계가 떠 있는 동안 전투가 멈추므로 이 노드는 멈춘 상태에서도 돌아야 한다.
	# (멈춘 채로 입력을 못 받으면 확인 키를 눌러도 넘어가지 않는다.)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_load_all()
	SaveSystem.register_provider(SAVE_KEY, self)

	EventBus.stage_started.connect(_on_stage_started)
	# 판이 끝나면(승리·패배) 남은 단계를 붙들고 있지 않는다.
	EventBus.stage_completed.connect(_on_stage_finished)
	EventBus.stage_failed.connect(_on_stage_finished)

	# 진행 조건으로 쓰는 신호들.
	EventBus.player_dashed.connect(_on_player_dashed)
	EventBus.status_effect_applied.connect(_on_status_effect_applied)
	EventBus.status_effect_burst.connect(_on_status_effect_burst)
	EventBus.enemy_executed.connect(_on_enemy_executed)

	# 턴제 진행 조건 (#594).
	EventBus.turn_stage_started.connect(_on_turn_stage_started)
	EventBus.turn_action_used.connect(_on_turn_action_used)
	EventBus.turn_lock_cleared.connect(_on_turn_lock_cleared)
	EventBus.turn_weakness_broken.connect(_on_turn_weakness_broken)
	EventBus.turn_battle_ended.connect(_on_turn_battle_ended)
	EventBus.turn_ended.connect(_on_turn_ended)

	# 메타 화면이 닫히면 ScreenManager 가 정지를 푼다(자기가 걸었던 정지라고 보고).
	# 튜토리얼이 아직 대기 중이면 그 순간 전투가 다시 흐르므로 다시 걸어 준다.
	ScreenManager.screen_visibility_changed.connect(_on_screen_visibility_changed)


# ===== 로드 (Load) =====

func _load_all() -> void:
	_sequences.clear()
	_turn_sequences.clear()

	var dir := DirAccess.open(TUTORIALS_DIR)
	if dir == null:
		# 저작된 튜토리얼이 없어도 정상이다.
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_resource_file(file_name):
			_load_one(TUTORIALS_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


# 내보내기 시 .tres 가 .remap 이 될 수 있어 두 확장자를 허용한다.
func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")


func _load_one(path: String) -> void:
	var load_path := path.trim_suffix(".remap")
	var res := load(load_path)
	if not (res is TutorialSequenceData):
		push_warning("TutorialSystem: TutorialSequenceData가 아닙니다(건너뜀): " + load_path)
		return

	var seq: TutorialSequenceData = res
	var problems := seq.validate()
	if not problems.is_empty():
		push_warning("TutorialSystem: 유효하지 않은 시퀀스(" + load_path + "): " + ", ".join(problems))
		return

	var table := _turn_sequences if seq.combat == TutorialSequenceData.Combat.TURN else _sequences
	if table.has(seq.stage_id):
		push_warning("TutorialSystem: 중복 stage_id(건너뜀): " + String(seq.stage_id))
		return

	table[seq.stage_id] = seq


# ===== 조회 (Query) =====

func has_sequence(stage_id: StringName) -> bool:
	return _sequences.has(stage_id)


func get_sequence(stage_id: StringName) -> TutorialSequenceData:
	return _sequences.get(stage_id, null)


func is_completed(stage_id: StringName) -> bool:
	return _completed.has(stage_id)


func is_active() -> bool:
	return _active != null


# ----- 턴제 조회 (#594) -----

func has_turn_sequence(stage_id: StringName) -> bool:
	return _turn_sequences.has(stage_id)


func get_turn_sequence(stage_id: StringName) -> TutorialSequenceData:
	return _turn_sequences.get(stage_id, null)


func is_turn_completed(stage_id: StringName) -> bool:
	var seq := get_turn_sequence(stage_id)
	return seq != null and _completed.has(seq.sequence_key())


## 턴제 시퀀스를 본 것으로 기록한다. 안내 없이 이미 그 스테이지를 깬 세이브(프롤로그 이전에
## 시작한 플레이어)를 옮겨 올 때 쓴다. 진행 중이던 그 시퀀스는 접는다(완료 경로가 아니다).
func mark_turn_completed(stage_id: StringName) -> void:
	var seq := get_turn_sequence(stage_id)
	if seq == null:
		return
	if _active == seq:
		_stop(false)
	_completed[seq.sequence_key()] = true
	SaveSystem.request_save()


# 지금 턴제 안내가 진행 중인가.
func is_turn_active() -> bool:
	return _active != null and _turn_mode


# 지금 진행 중인 턴제 시퀀스. 전투 화면이 저작된 판(시드·HP 하한·자물쇠)을 읽는다.
func get_active_turn_sequence() -> TutorialSequenceData:
	return _active if is_turn_active() else null


# 전투 진행 루프를 세워야 하는가 — 대사 패널을 읽는 중이다.
func is_holding_turn_battle() -> bool:
	return is_turn_active() and _reading


# 단계가 바뀌었는데 아직 띄우지 않았다(전투 화면이 입력 대기에 들어오면 뜬다).
func is_turn_step_pending() -> bool:
	return is_turn_active() and _pending_show


# 화면이 강조할 곳(`TutorialStepData.highlight`). 단계가 떠 있지 않으면 빈 값이다.
func current_highlight() -> StringName:
	if not is_turn_active() or _pending_show:
		return &""
	var step := get_current_step()
	return step.highlight if step != null else &""


# 이 단계가 노리라고 한 적. 화면은 이 적을 미리 조준해 둔다.
func required_target_id() -> StringName:
	if not is_turn_active():
		return &""
	var step := get_current_step()
	return step.target_id if step != null else &""


# 첫 궁극기처럼 크게 보여 줄 행동인가. 전투 화면이 컷인 연출을 키운다.
func is_showcase_action(unit_id: StringName, skill: SkillData) -> bool:
	if not is_turn_active() or _reading or skill == null:
		return false
	var step := get_current_step()
	if step == null or not step.showcase:
		return false
	if not String(step.actor_id).is_empty() and step.actor_id != unit_id:
		return false
	return String(step.skill_id).is_empty() or step.skill_id == skill.skill_id


func get_current_step() -> TutorialStepData:
	if _active == null:
		return null
	return _active.get_step(_index)


func get_step_index() -> int:
	return _index


func get_step_count() -> int:
	return _active.get_count() if _active != null else 0


# 지금 읽는 중인가(전투가 멈춰 있고 확인 키를 기다린다).
func is_reading() -> bool:
	return _reading


# ===== 진행 (Flow) =====

# 스테이지가 시작되면 그 스테이지의 시퀀스를 켠다.
# 이미 완료했거나 저작된 시퀀스가 없으면 아무 일도 하지 않는다.
func _on_stage_started(stage_name: String) -> void:
	if _active != null:
		# 같은 전장을 다시 로드했다. 진행 중이던 시퀀스를 접고 새로 판단한다.
		_stop(false)

	var stage_id := StringName(stage_name)
	if is_completed(stage_id):
		return

	var seq: TutorialSequenceData = get_sequence(stage_id)
	if seq == null:
		return

	_active = seq
	_index = 0
	_show_current()


func _on_stage_finished(_stage_name: String) -> void:
	if _active == null:
		return
	# 판이 끝났으면 남은 단계는 접는다. 완료로는 기록하지 않는다 —
	# 끝까지 보지 못한 튜토리얼을 봤다고 저장하면 다시 볼 방법이 없다.
	_stop(false)


# 지금 단계를 화면에 올리고 전투를 멈춘다(읽는 국면).
func _show_current() -> void:
	var step := get_current_step()
	if step == null:
		# 마지막 단계를 넘겼다. 여기가 유일한 "완료" 경로다.
		_stop(true)
		return

	if _turn_mode:
		# 턴제: 바로 띄우지 않는다. 행동할 아군의 차례를 당겨 두고, 전투 화면이 입력 대기에
		# 들어오면(`turn_ready_point`) 그때 띄운다.
		_progress = 0
		_reading = false
		_pending_show = true
		_request_next_actor()
		return

	_progress = 0
	_reading = true
	_set_paused(true)
	step_changed.emit(step, _index, get_step_count(), true)


# 읽기가 끝났다(확인 키). 확인만으로 넘어가는 단계면 다음 단계로,
# 행동이 필요한 단계면 전투를 다시 흘려 조건을 기다린다.
func _confirm() -> void:
	var step := get_current_step()
	if step == null:
		return

	if step.advance == TutorialStepData.Advance.CONFIRM:
		_advance_step()
		return

	_reading = false
	if not _turn_mode:
		_set_paused(false)
	step_changed.emit(step, _index, get_step_count(), false)


## 읽는 중인 단계를 확인한다. 화면(대사 패널 클릭)이 부른다. 확인 키도 같은 길을 쓴다.
func confirm() -> void:
	if _active == null or not _reading:
		return
	_confirm()


# 지금 단계의 조건이 한 번 성립했다.
func _register_progress() -> void:
	var step := get_current_step()
	if step == null:
		return
	_progress += 1
	if _progress < step.required_count:
		return
	_advance_step()


func _advance_step() -> void:
	_index += 1
	_show_current()


# 시퀀스를 끝낸다. completed 면 완료로 기록해 다시 뜨지 않게 한다.
func _stop(completed: bool) -> void:
	var stage_id: StringName = _active.stage_id if _active != null else StringName()
	var key: StringName = _active.sequence_key() if _active != null else StringName()
	var was_turn := _turn_mode
	_active = null
	_index = 0
	_progress = 0
	_reading = false
	_turn_mode = false
	_pending_show = false
	# 턴제는 트리를 멈춘 적이 없다. 풀면 메타 화면이 건 정지를 건드린다.
	if not was_turn:
		_set_paused(false)

	if completed and not String(key).is_empty():
		_completed[key] = true
		SaveSystem.request_save()

	finished.emit(stage_id)


# 전투 정지를 걸거나 푼다.
#
# 푸는 쪽에 조건이 붙는 이유: 메타 화면이 떠 있는 동안에도 튜토리얼이 끝날 수 있고
# (예: 결과 화면), 그때 정지를 풀어 버리면 화면 뒤에서 전투가 다시 흐른다.
# 정지의 다른 소유자는 ScreenManager 다.
func _set_paused(paused: bool) -> void:
	if paused:
		get_tree().paused = true
		return
	if ScreenManager.has_screen():
		return
	get_tree().paused = false


func _on_screen_visibility_changed(has_screen: bool) -> void:
	if has_screen or _active == null or _turn_mode:
		return
	# 화면이 닫혔는데 읽는 국면이 아직 끝나지 않았다. 정지를 다시 건다.
	# (하는 국면이면 전투가 흘러야 하므로 건드리지 않는다.)
	if _reading:
		get_tree().paused = true


# ===== 입력 (Confirm) =====

# 읽는 국면에서만 입력을 먹는다. 하는 국면에서는 확인 키가 전투 조작을 가로채지 않는다.
# _unhandled_input 을 쓰는 이유: UI 버튼·메타 화면이 먼저 입력을 가져갈 수 있어야 한다.
func _unhandled_input(event: InputEvent) -> void:
	if _active == null or not _reading:
		return
	# 턴제 안내는 트리를 멈추지 않으므로 메타 화면이 떠 있어도 여기까지 온다. 그 화면의 입력이다.
	if _turn_mode and ScreenManager.has_screen():
		return
	if event.is_action_pressed(CONFIRM_ACTION):
		get_viewport().set_input_as_handled()
		_confirm()


# ===== 조건 신호 (Advance conditions) =====

func _on_player_dashed(_who) -> void:
	_advance_if_waiting(TutorialStepData.Advance.DASH, &"")


func _on_status_effect_applied(_target, effect_id: StringName) -> void:
	_advance_if_waiting(TutorialStepData.Advance.EFFECT_APPLIED, effect_id)


func _on_status_effect_burst(_target, effect_id: StringName) -> void:
	_advance_if_waiting(TutorialStepData.Advance.EFFECT_BURST, effect_id)


func _on_enemy_executed(_enemy, _by) -> void:
	_advance_if_waiting(TutorialStepData.Advance.EXECUTE, &"")


# 지금 단계가 그 조건을 기다리고 있으면 한 번 진행한다.
# effect_id 를 받는 조건이면 저작된 id 와 같아야 한다(다른 효과로 넘어가지 않게).
func _advance_if_waiting(advance: TutorialStepData.Advance, effect_id: StringName) -> void:
	if _active == null or _reading or _pending_show:
		# 읽는 중에 일어난 일로는 넘어가지 않는다 — 아직 무엇을 하라고 말하지도 않았다.
		return
	var step := get_current_step()
	if step == null or step.advance != advance:
		return
	if not String(step.effect_id).is_empty() and step.effect_id != effect_id:
		return
	_register_progress()


# ===== 턴제 (#594) =====

# 턴제 전투가 스테이지로 시작됐다. 그 스테이지의 턴제 시퀀스를 켠다.
#
# 이 신호는 전투가 **첫 턴을 굴리기 전에** 와야 한다 — 그래야 첫 행동자를 당길 수 있다.
# 전투 화면(`TurnBattle._start_battle`)이 그 순서를 지킨다.
func _on_turn_stage_started(stage_name) -> void:
	if _active != null:
		_stop(false)

	var stage_id := StringName(String(stage_name))
	var seq := get_turn_sequence(stage_id)
	if seq == null or is_turn_completed(stage_id):
		return

	_active = seq
	_turn_mode = true
	_index = 0
	_show_current()


# 전투 화면이 부른다: 연출이 다 끝났고 `active_id` 아군이 입력을 기다린다.
#
# 반환: 이 아군이 **안내가 기다리는 아군이 아니어서** 자동으로 넘겨야 하면 true.
# (행동자 당기기는 다음 턴부터 먹는다. 첫 턴이 다른 아군에게 갔을 때의 안전장치다 —
# 입력을 막아 둔 채 그 아군을 세워 두면 전투가 영영 멈춘다.)
func turn_ready_point(active_id: StringName) -> bool:
	if not is_turn_active():
		return false
	var step := get_current_step()
	if step == null:
		return false

	var wanted := _next_actor_id()
	if _pending_show and not String(wanted).is_empty() and wanted != active_id:
		_request_next_actor()
		return true

	if not _pending_show:
		# 이미 떠 있는 단계다. 행동해야 할 아군이 아닌 아군이 서 있으면 넘긴다.
		if not _reading and _step_gates_input(step) and not String(step.actor_id).is_empty() \
				and step.actor_id != active_id:
			_request_next_actor()
			return true
		return false

	_pending_show = false
	_reading = true
	step_changed.emit(step, _index, get_step_count(), true)
	return false


## 화면이 그 입력을 받아도 되는가 — **강제 진행**의 관문이다.
##
## kind: "action"(평타·스킬) · "ultimate" · "target" · "control"(배속·자동·일시정지)
## 안내가 없으면 전부 허용한다.
func allows_turn_input(kind: String, unit_id: StringName = &"",
		skill: SkillData = null) -> bool:
	if not is_turn_active():
		return true
	var step := get_current_step()
	if step == null:
		return true
	if _reading or _pending_show:
		return false

	if kind == "control":
		return step.unlock_controls

	if not _step_gates_input(step):
		return true

	match kind:
		"target":
			return String(step.target_id).is_empty() or step.target_id == unit_id
		"ultimate":
			return step.advance == TutorialStepData.Advance.TURN_ULTIMATE \
				and (String(step.actor_id).is_empty() or step.actor_id == unit_id)
		"action":
			if step.advance == TutorialStepData.Advance.TURN_ULTIMATE:
				# 스킬 목록의 궁극기 항목도 같은 궁극기다. 초상 배지만 받으면 목록을 누른 사람이 막힌다.
				return skill != null and skill.is_turn_ultimate() 					and (String(step.actor_id).is_empty() or step.actor_id == unit_id)
			if not String(step.actor_id).is_empty() and step.actor_id != unit_id:
				return false
			if skill == null:
				return false
			if not String(step.skill_id).is_empty():
				return step.skill_id == skill.skill_id
			match step.advance:
				TutorialStepData.Advance.TURN_BASIC:
					return skill.turn_action == TurnCombat.ActionKind.BASIC
				TutorialStepData.Advance.TURN_SKILL:
					return skill.turn_action == TurnCombat.ActionKind.SKILL
			return not skill.is_turn_ultimate()
	return true


# 이 단계가 입력을 하나로 좁히는가. 확인·승리 단계는 자유롭다.
func _step_gates_input(step: TutorialStepData) -> bool:
	return step.advance in [
		TutorialStepData.Advance.TURN_BASIC, TutorialStepData.Advance.TURN_SKILL,
		TutorialStepData.Advance.TURN_ULTIMATE, TutorialStepData.Advance.TURN_LOCK_CLEARED,
		TutorialStepData.Advance.TURN_BREAK,
	]


# 지금부터 처음으로 행동이 필요한 아군. 확인 단계는 다음 행동 단계의 아군을 미리 부른다 —
# "타임라인을 봐라" 같은 단계가 떠 있는 동안 엉뚱한 아군이 차례를 받지 않게 한다.
func _next_actor_id() -> StringName:
	if _active == null:
		return &""
	for i in range(_index, _active.get_count()):
		var step := _active.get_step(i)
		if step == null:
			continue
		if not String(step.actor_id).is_empty():
			return step.actor_id
		if _step_gates_input(step) or step.advance == TutorialStepData.Advance.TURN_VICTORY:
			return &""
	return &""


func _request_next_actor() -> void:
	var id := _next_actor_id()
	if not String(id).is_empty():
		turn_actor_requested.emit(id)


func _on_turn_action_used(unit, skill) -> void:
	if not is_turn_active() or unit == null or skill == null:
		return
	var step := get_current_step()
	if step == null or String(step.actor_id) != String(unit.unit_id):
		return
	if not String(step.skill_id).is_empty() and step.skill_id != skill.skill_id:
		return
	var kind := TutorialStepData.Advance.TURN_SKILL
	if skill.is_turn_ultimate():
		kind = TutorialStepData.Advance.TURN_ULTIMATE
	elif skill.turn_action == TurnCombat.ActionKind.BASIC:
		kind = TutorialStepData.Advance.TURN_BASIC
	_advance_if_waiting(kind, &"")


func _on_turn_lock_cleared(unit, _lock, _index_value: int, _total: int) -> void:
	if _matches_target(unit):
		_advance_if_waiting(TutorialStepData.Advance.TURN_LOCK_CLEARED, &"")


func _on_turn_weakness_broken(unit, _element: int) -> void:
	if _matches_target(unit):
		_advance_if_waiting(TutorialStepData.Advance.TURN_BREAK, &"")


func _matches_target(unit) -> bool:
	if not is_turn_active() or unit == null:
		return false
	var step := get_current_step()
	return step != null and String(step.target_id) == String(unit.unit_id)


func _on_turn_battle_ended(victory: bool, _summary: Dictionary) -> void:
	if not is_turn_active():
		return
	if victory:
		_advance_if_waiting(TutorialStepData.Advance.TURN_VICTORY, &"")
		# 마지막 단계에 닿기 전에 이겼어도(궁극기가 판을 끝냈다) 끝까지 싸운 것이다 — 완료다.
		if is_turn_active():
			_stop(true)
	else:
		_stop(false)


# 행동해야 할 아군이 행동했는데 단계가 넘어가지 않았다(예: 자물쇠를 못 열었다).
# 그 아군의 차례를 다시 당겨 한 번 더 하게 한다 — 엉뚱한 아군이 끼어들지 않는다.
func _on_turn_ended(_unit) -> void:
	if not is_turn_active() or _reading or _pending_show:
		return
	var step := get_current_step()
	if step != null and _step_gates_input(step):
		_request_next_actor()


# ===== 저장 (SaveSystem provider) =====

func to_save_dict() -> Dictionary:
	var ids: Array[String] = []
	for id in _completed:
		ids.append(String(id))
	return {"completed": ids}


func from_save_dict(data: Dictionary) -> void:
	_completed.clear()
	for raw in data.get("completed", []):
		_completed[StringName(raw)] = true

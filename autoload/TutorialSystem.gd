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

# stage_id(StringName) -> TutorialSequenceData
var _sequences: Dictionary = {}

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

	# 메타 화면이 닫히면 ScreenManager 가 정지를 푼다(자기가 걸었던 정지라고 보고).
	# 튜토리얼이 아직 대기 중이면 그 순간 전투가 다시 흐르므로 다시 걸어 준다.
	ScreenManager.screen_visibility_changed.connect(_on_screen_visibility_changed)


# ===== 로드 (Load) =====

func _load_all() -> void:
	_sequences.clear()

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

	if _sequences.has(seq.stage_id):
		push_warning("TutorialSystem: 중복 stage_id(건너뜀): " + String(seq.stage_id))
		return

	_sequences[seq.stage_id] = seq


# ===== 조회 (Query) =====

func has_sequence(stage_id: StringName) -> bool:
	return _sequences.has(stage_id)


func get_sequence(stage_id: StringName) -> TutorialSequenceData:
	return _sequences.get(stage_id, null)


func is_completed(stage_id: StringName) -> bool:
	return _completed.has(stage_id)


func is_active() -> bool:
	return _active != null


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
	_set_paused(false)
	step_changed.emit(step, _index, get_step_count(), false)


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
	_active = null
	_index = 0
	_progress = 0
	_reading = false
	_set_paused(false)

	if completed and not String(stage_id).is_empty():
		_completed[stage_id] = true
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
	if has_screen or _active == null:
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
	if _active == null or _reading:
		# 읽는 중에 일어난 일로는 넘어가지 않는다 — 아직 무엇을 하라고 말하지도 않았다.
		return
	var step := get_current_step()
	if step == null or step.advance != advance:
		return
	if not String(step.effect_id).is_empty() and step.effect_id != effect_id:
		return
	_register_progress()


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

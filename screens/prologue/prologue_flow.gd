extends Node
class_name PrologueFlow

# 첫 플레이 프롤로그의 흐름 (#594).
#
#   오프닝 스토리 ──(전투 줄)──▶ 1-1 턴제 전투 + 단계별 안내 ──(승리)──▶ 마무리 스토리 ──▶ 메인 화면
#
# 이 노드는 **순서만** 쥔다. 각 구간은 기존 시스템이 그대로 한다:
#   스토리      -> StoryPlayerScreen (흐름 모드: 전투 줄에서 넘겨주고, 끝나면 닫는다)
#   전투        -> TurnBattle (StageSystem.request_stage 로 1-1 을 연다)
#   안내·완료 저장 -> TutorialSystem (턴제 시퀀스 data/tutorial/prologue_turn_1_1.tres, SaveSystem "tutorial")
#   보상        -> StageProgress (stage_completed 로 평소처럼 지급)
#
# "프롤로그를 끝냈다"의 출처는 TutorialSystem 의 완료 기록 하나다. 따로 플래그를 두지 않는다 —
# 1-1 안내를 끝냈으면 프롤로그를 끝낸 것이고, 둘을 따로 저장하면 어긋날 수 있다.
#
# 메인 화면을 여는 쪽(MainScreenLauncher)이 첫 실행에 이 노드를 만든다.

signal done

const CHAPTER_ID := &"prologue"
const STAGE_ID := &"stage_1_1"
const STORY_PLAYER := preload("res://screens/story/StoryPlayerScreen.tscn")
const RESULT_SCREEN_PATH := "res://screens/result/ResultScreen.tscn"
const MAIN_SCREEN_PATH := "res://screens/main/MainScreen.tscn"

# 마무리 스토리를 이어 볼 줄(오프닝의 전투 줄 다음). 전투 줄을 넘길 때 정해진다.
var _resume_index: int = -1
var _awaiting_result: bool = false
var _ending_open: bool = false
var _running: bool = false


## 이 세이브에 프롤로그가 필요한가.
##
## 프롤로그가 생기기 전에 시작한 세이브(이미 1-1 을 깼다)는 안내를 본 것으로 옮겨 온다 —
## 이미 싸울 줄 아는 사람에게 처음부터 다시 가르치지 않는다.
static func is_needed() -> bool:
	if not StoryDatabase.has_chapter(CHAPTER_ID) or not TutorialSystem.has_turn_sequence(STAGE_ID):
		return false
	if TutorialSystem.is_turn_completed(STAGE_ID):
		return false
	if StageProgress.is_cleared(STAGE_ID):
		var was_running := TutorialSystem.is_turn_active()
		TutorialSystem.mark_turn_completed(STAGE_ID)
		# 뒤에서 돌던 전투가 안내 판(고정 시드·자물쇠)으로 열려 있었다면 평소 판으로 다시 연다.
		if was_running:
			StageSystem.request_stage(StageSystem.get_current_id())
		return false
	return true


func is_running() -> bool:
	return _running


func start() -> void:
	_running = true
	TutorialSystem.finished.connect(_on_tutorial_finished)
	ScreenManager.screen_pushed.connect(_on_screen_pushed)

	# 1-1 을 연다. 이미 1-1 이어도 다시 연다 — 안내가 첫 턴 전에 켜져야 하고, 처음부터 깨끗한 판이어야 한다.
	StageSystem.request_stage(STAGE_ID)

	var screen := ScreenManager.push(STORY_PLAYER)
	if screen == null:
		# 스토리를 띄울 수 없으면 전투 안내만이라도 진행한다.
		return
	screen.call("configure_flow", true, true)
	screen.connect("battle_reached", _on_battle_reached)
	screen.call("open_chapter", CHAPTER_ID)


func _on_battle_reached(_stage_id: StringName, resume_index: int) -> void:
	# 스토리 화면이 닫히면 화면 스택이 비고 전투가 다시 흐른다. 안내는 이미 켜져 있다.
	_resume_index = resume_index


func _on_tutorial_finished(stage_id: StringName) -> void:
	if stage_id != STAGE_ID or not TutorialSystem.is_turn_completed(STAGE_ID):
		return
	# 이겼다. 곧 결과 화면이 뜬다(stage_result_launcher). 그 위에 마무리 스토리를 얹는다.
	_awaiting_result = true


func _on_screen_pushed(screen: Control) -> void:
	if not _awaiting_result or screen == null or screen.scene_file_path != RESULT_SCREEN_PATH:
		return
	_awaiting_result = false
	# 결과 화면이 막 들어온 프레임이다. 한 프레임 뒤에 얹어야 스택 순서가 꼬이지 않는다.
	_open_ending.call_deferred()


func _open_ending() -> void:
	var start_index := _resume_index
	if start_index < 0:
		start_index = _find_resume_index()
	var chapter := StoryDatabase.get_chapter(CHAPTER_ID)
	if chapter == null or start_index < 0 or start_index >= chapter.lines.size():
		_finish()
		return

	var screen := ScreenManager.push(STORY_PLAYER)
	if screen == null:
		_finish()
		return
	_ending_open = true
	screen.call("configure_flow", false, true)
	ScreenManager.screen_popped.connect(_on_ending_popped)
	screen.call("open_chapter", CHAPTER_ID, start_index)


# 전투 줄을 넘기지 않고 전투가 끝난 경우(예: 스토리를 띄우지 못했다) 대본에서 직접 찾는다.
func _find_resume_index() -> int:
	var chapter := StoryDatabase.get_chapter(CHAPTER_ID)
	if chapter == null:
		return -1
	for i in range(chapter.lines.size()):
		var line := chapter.lines[i]
		if line != null and line.kind == StoryLineData.Kind.BATTLE:
			return i + 1
	return -1


func _on_ending_popped(_depth: int) -> void:
	if not _ending_open:
		return
	_ending_open = false
	ScreenManager.screen_popped.disconnect(_on_ending_popped)
	_finish()


# 메인 화면으로. 결과 화면이 남아 있으면 그것을 메인 화면으로 바꾼다(보상은 이미 지급됐다).
func _finish() -> void:
	_running = false
	if TutorialSystem.finished.is_connected(_on_tutorial_finished):
		TutorialSystem.finished.disconnect(_on_tutorial_finished)
	if ScreenManager.screen_pushed.is_connected(_on_screen_pushed):
		ScreenManager.screen_pushed.disconnect(_on_screen_pushed)
	var main_screen := load(MAIN_SCREEN_PATH) as PackedScene
	if ScreenManager.has_screen():
		ScreenManager.replace(main_screen)
	else:
		ScreenManager.push(main_screen)
	done.emit()
	queue_free()

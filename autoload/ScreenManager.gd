extends Node

# 메타 화면(메인화면/편성/장비 등) 스택의 단일 출처 (autoload).
#
# 책임: 게임플레이 위에 얹히는 UI 화면을 쌓고(push) 되돌린다(pop).
#
# 진입점을 대체하지 않는다 (중요):
#   프로젝트의 main_scene은 계속 main.tscn(실제 게임플레이)이다.
#   메타 화면은 이 시스템이 만든 CanvasLayer 위에 "얹혀서" 표시되며,
#   게임플레이 씬 트리를 교체하거나 project.godot의 run/main_scene을 바꾸지 않는다.
#   (팀 방향: 실제 게임플레이인 main.tscn을 기초로 삼는다.)
#
# 단일 출처 원칙:
#   - 이 시스템은 "지금 어떤 화면이 떠 있는가"만 안다.
#   - 화면이 보여주는 값(재화/파티/시너지 등)은 각 기초 시스템이 소유한다.
#     화면 스크립트가 그 시스템을 직접 읽고, 여기서 데이터를 중계하지 않는다.
#
# 참고: SYSTEM_CONVENTIONS.md, docs/combat-screen-design.md

# 메타 화면이 올라가는 CanvasLayer의 레이어 번호.
# main.tscn의 HUD(layer 1) / DebugOverlay(layer 2)보다 위에 와야 화면이 가려지지 않는다.
const SCREEN_LAYER: int = 10

# 화면 스택이 비었음을 뜻한다.
const EMPTY_DEPTH: int = 0

# 화면이 열렸을 때 (열린 화면 노드).
signal screen_pushed(screen: Control)

# 화면이 닫혔을 때 (남은 스택 깊이).
signal screen_popped(depth: int)

# 메타 화면이 하나라도 떠 있는지 바뀔 때 (true = 화면 있음).
signal screen_visibility_changed(has_screen: bool)

# 메타 화면이 떠 있는 동안 게임플레이를 멈출지.
# 정지 정책을 각 화면이 따로 구현하면 새 화면이 생길 때마다 빠뜨리기 쉬우므로
# 스택을 소유한 이 시스템이 한 곳에서 처리한다.
# (화면 노드는 자동으로 PROCESS_MODE_ALWAYS 가 되어 정지 중에도 동작한다.)
var pause_gameplay_while_open: bool = true

# 화면이 실제로 붙는 레이어. _ready()에서 만든다.
var _layer: CanvasLayer = null

# 화면 스택. 마지막 원소가 맨 위(현재 화면)다.
var _stack: Array[Control] = []


func _ready() -> void:
	name = "ScreenManager"
	_layer = CanvasLayer.new()
	_layer.name = "ScreenLayer"
	_layer.layer = SCREEN_LAYER
	add_child(_layer)


# ===== 스택 조작 (Stack) =====

# 새 화면을 위에 쌓는다. 이전 화면은 숨긴다(해제하지 않으므로 pop 시 상태가 남는다).
# 실패하면 null을 반환한다.
func push(scene: PackedScene) -> Control:
	if scene == null:
		push_warning("ScreenManager.push: scene이 null입니다.")
		return null

	var instance := scene.instantiate()
	# 씬이 깨져 있으면 instantiate() 가 null 을 돌려준다(순환 참조 등).
	# 이때 아래에서 instance.queue_free() 를 부르면 그 자체가 에러가 되어
	# 진짜 원인이 가려진다. 먼저 걸러 낸다.
	if instance == null:
		push_warning("ScreenManager.push: 씬을 만들 수 없습니다: " + scene.resource_path)
		return null

	var screen := instance as Control
	if screen == null:
		push_warning("ScreenManager.push: 루트가 Control이 아닙니다: " + scene.resource_path)
		instance.queue_free()
		return null

	var was_empty := _stack.is_empty()
	if not was_empty:
		_stack.back().visible = false

	_layer.add_child(screen)
	# 어떤 창 비율에서도 화면 전체를 덮게 한다.
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 게임플레이가 멈춰도 화면은 계속 동작해야 버튼을 누를 수 있다.
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_stack.append(screen)

	screen_pushed.emit(screen)
	if was_empty:
		_apply_pause(true)
		screen_visibility_changed.emit(true)
	return screen


# 맨 위 화면을 닫는다. 스택이 비어 있으면 아무 일도 하지 않는다.
# 닫은 뒤 스택이 비면 게임플레이가 그대로 드러난다.
func pop() -> void:
	if _stack.is_empty():
		return

	var top: Control = _stack.pop_back()
	top.queue_free()

	if not _stack.is_empty():
		_stack.back().visible = true

	screen_popped.emit(_stack.size())
	if _stack.is_empty():
		_apply_pause(false)
		screen_visibility_changed.emit(false)


# 스택을 모두 비우고 새 화면 하나만 남긴다.
func replace(scene: PackedScene) -> Control:
	close_all()
	return push(scene)


# 맨 위 화면을 다른 화면으로 **갈아 끼운다**. 스택 깊이가 늘지 않는다.
#
# 옆으로 이동할 때 쓴다(장비 <-> 제조처럼 서로를 오가는 화면).
# 그런 이동에 push 를 쓰면 오갈수록 스택이 깊어져서
# 뒤로가기를 여러 번 눌러야 원래 자리로 돌아온다.
#
# 파고드는 이동(편성 -> 인물 상세)은 돌아올 자리가 있어야 하므로 push 를 쓴다.
func swap(scene: PackedScene) -> Control:
	if _stack.is_empty():
		return push(scene)
	pop()
	return push(scene)


# 모든 메타 화면을 닫는다(게임플레이만 남긴다).
func close_all() -> void:
	if _stack.is_empty():
		return
	for screen in _stack:
		screen.queue_free()
	_stack.clear()
	_apply_pause(false)
	screen_popped.emit(EMPTY_DEPTH)
	screen_visibility_changed.emit(false)


# 게임플레이 정지 상태를 적용한다. 정책이 꺼져 있으면 아무것도 하지 않는다.
func _apply_pause(paused: bool) -> void:
	if not pause_gameplay_while_open:
		return
	get_tree().paused = paused


# ===== 조회 (Query) =====

# 맨 위 화면. 없으면 null.
func current() -> Control:
	return _stack.back() if not _stack.is_empty() else null


# 쌓여 있는 화면 수.
func get_depth() -> int:
	return _stack.size()


# 메타 화면이 하나라도 떠 있는가.
func has_screen() -> bool:
	return not _stack.is_empty()

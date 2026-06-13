## res://autoload/screen_manager.gd
## Autoload 이름: ScreenManager
## 화면(씬) 스택 관리. 메인 → 정복 → 편성 ... push/pop.

extends Node

var _layer: CanvasLayer
var _stack: Array[Control] = []

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "ScreenLayer"
	add_child(_layer)

## 새 화면을 위로 쌓는다 (이전 화면은 숨김)
func push(scene: PackedScene) -> void:
	if scene == null:
		push_warning("ScreenManager.push: scene is null")
		return
	if not _stack.is_empty():
		_stack.back().visible = false
	var inst := scene.instantiate() as Control
	_layer.add_child(inst)
	_stack.append(inst)

## 뒤로가기. 마지막 한 장은 남긴다.
func pop() -> void:
	if _stack.size() <= 1:
		return
	var top: Control = _stack.pop_back()
	top.queue_free()
	_stack.back().visible = true

## 스택을 비우고 교체 (예: 타이틀 → 메인)
func replace(scene: PackedScene) -> void:
	for s in _stack:
		s.queue_free()
	_stack.clear()
	push(scene)

func current() -> Control:
	return _stack.back() if not _stack.is_empty() else null

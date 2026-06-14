## res://Boot.gd  (Boot.tscn 의 루트에 붙임 — 프로젝트 Main Scene)
## 메인 화면을 ScreenManager 스택에 올린다.
## 이렇게 해야 정복(StageSelect)을 push 한 뒤 pop() 으로 메인에 정확히 돌아온다.

extends Node

func _ready() -> void:
	# project.godot 에디터 덮어쓰기 방지 — 코드로 직접 설정
	var w := get_window()
	w.content_scale_mode   = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	w.content_scale_size   = Vector2i(1280, 720)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	ScreenManager.push(preload("res://screens/main/MainScreen.tscn"))

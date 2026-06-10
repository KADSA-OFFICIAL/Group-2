## res://Boot.gd  (Boot.tscn 의 루트에 붙임 — 프로젝트 Main Scene)
## 메인 화면을 ScreenManager 스택에 올린다.
## 이렇게 해야 정복(StageSelect)을 push 한 뒤 pop() 으로 메인에 정확히 돌아온다.

extends Node

func _ready() -> void:
	ScreenManager.push(preload("res://screens/main/MainScreen.tscn"))

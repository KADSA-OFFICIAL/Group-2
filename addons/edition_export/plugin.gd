@tool
extends EditorPlugin

# 내보내기 플러그인을 등록만 한다. 규칙은 edition_export_plugin.gd, 경로 규칙은 GameEdition.

var _export_plugin: EditorExportPlugin = null


func _enter_tree() -> void:
	_export_plugin = preload("res://addons/edition_export/edition_export_plugin.gd").new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null

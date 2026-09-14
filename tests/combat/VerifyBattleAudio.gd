extends Node
var failed := false

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var field = load("res://stage/turn/TurnBattle.tscn").instantiate()
	field.use_stage = false
	add_child(field)
	var launcher := Node.new()
	launcher.set_script(load("res://screens/main/main_screen_launcher.gd"))
	add_child(launcher)
	await get_tree().process_frame
	await get_tree().process_frame
	check(MusicSystem.get_current_stream().resource_path.ends_with("lobby_theme.ogg"), "Lobby music must win over battle")
	ScreenManager.close_all()
	await get_tree().process_frame
	await get_tree().process_frame
	check(MusicSystem.get_current_stream() == field._battle_music, "Battle must resume after lobby closes")
	check(field._battle_music.loop, "Battle BGM must loop")
	check(field._play_se("missing_test_sound") == null, "Missing audio must not break battle")
	for i in range(12):
		var pitch := PresentationQueue.lock_pitch(i % 4, 4)
		var voice: AudioStreamPlayer = field._play_se("lock", pitch)
		check(voice != null and is_equal_approx(voice.pitch_scale, pitch), "Lock pitch must reach the audio player")
	check(field._se_voices.size() <= field.MAX_SE_VOICES, "SE voices must be bounded")
	for sound in ["hit", "break", "status", "death"]:
		check(field._play_se(sound) != null, "Playable effect: " + sound)
	launcher.open_menu()
	await get_tree().process_frame
	check(MusicSystem.get_current_stream().resource_path.ends_with("lobby_theme.ogg"), "Return to lobby must restore music")
	launcher.queue_free()
	ScreenManager.close_all()
	field.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	MusicSystem.stop()
	print("BATTLE_AUDIO ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)

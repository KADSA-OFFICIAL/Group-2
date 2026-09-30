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
	# #535: 챕터 컨셉마다 전투곡, 보스 웨이브는 보스곡, 결과는 한 번 재생하는 징글.
	check(field._stage_music.resource_path == field.BATTLE_BGM_PATH, "Stage-less battle uses the land track")
	for concept in field.CONCEPT_BGM:
		var track: AudioStream = field._load_loop(field.CONCEPT_BGM[concept])
		check(track != null and track.loop, "Concept track exists and loops: %s" % field.CONCEPT_BGM[concept])
	var sea := StageData.new()
	sea.chapter = 2
	field._stage = sea
	field._apply_backdrop()
	check(field._stage_music.resource_path.ends_with("battle_sea.ogg"), "Sea chapter picks the sea track")
	check(MusicSystem.get_current_stream() == field._stage_music, "Switching stage music plays it")
	var boss: AudioStream = field._load_loop(field.BOSS_BGM_PATH)
	check(boss != null and boss.loop, "Boss track exists and loops")
	field._switch_battle_music(boss)
	check(MusicSystem.get_current_stream() == boss, "Boss wave switches to the boss track")
	field._switch_battle_music(field._stage_music)
	check(MusicSystem.get_current_stream() == field._stage_music, "After the boss the stage track returns")
	for path in [field.VICTORY_JINGLE_PATH, field.DEFEAT_JINGLE_PATH]:
		var jingle := load(path) as AudioStreamOggVorbis
		check(jingle != null and not jingle.loop, "Jingle plays once: " + path)
	# 실제 스테이지 흐름: 승패를 알리면 결과 화면이 열린다. 그래도 징글이 나와야 한다.
	var results := Node.new()
	results.set_script(load("res://screens/result/stage_result_launcher.gd"))
	add_child(results)
	await get_tree().process_frame
	var stage := StageData.new()
	stage.stage_id = &"stage_test"
	field._stage = stage
	field._outcome_reported = false
	field._show_result()
	await get_tree().process_frame
	await get_tree().process_frame
	check(ScreenManager.has_screen(), "Result screen opens after the outcome is reported")
	var playing := MusicSystem.get_current_stream()
	check(playing != null and playing.resource_path.ends_with("jingle_defeat.ogg") or playing != null and playing.resource_path.ends_with("jingle_victory.ogg"),
		"Result jingle keeps playing under the result screen (got %s)" % (playing.resource_path if playing else "none"))
	ScreenManager.close_all()
	await get_tree().process_frame
	results.queue_free()
	field._stage = null
	field._apply_backdrop()
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

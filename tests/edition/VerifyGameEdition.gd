extends Node

# 일반판 / 검열판 그림 교체 검증 (#586).
#
#   1) 경로 규칙: assets/ 의 짝은 assets_censored/ 같은 경로. assets/ 밖은 짝이 없다.
#   2) 일반판: 초상·오의 경로가 지금과 똑같다(검열판 그림이 있어도 쓰지 않는다).
#   3) 검열판: 짝이 있는 것만 검열판 그림, 없으면 원본. 초상 얼굴 자르기가 그대로 동작한다.
#      임시 SpriteFrames 를 assets_censored/ 에 써서 오의 경로가 실제로 바뀌는지 본다(끝나면 지운다).
#   4) 들어와 있는 검열판 오의 애니메이션은 24장이고 모두 assets_censored/ 의 그림을 가리킨다.
#   5) 검열판 그림이 아직 없는 목록을 출력한다(실패 아님 — 릴리스 전 확인용).
#   6) 내보낸 검열판 빌드에서 돌리면: 원본 경로를 직접 읽어도 검열판 그림이 나온다
#      (addons/edition_export 가 바꿔 넣었다).
#
# `-- --censored` 로 돌리면 실행 인수 판정도 본다.

const FIXTURE_ID := &"mina"

var failed := false


func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)


func _ready() -> void:
	var from_cmdline := GameEdition.CMDLINE_FLAG in OS.get_cmdline_user_args()
	GameEdition.force_censored(null)
	check(GameEdition.is_censored() == (from_cmdline or OS.has_feature(GameEdition.FEATURE)),
		"실행 인수 --censored · 내보내기 태그 판정이 맞아야 한다")

	_check_path_rule()
	_check_general()
	_check_censored()
	_check_fixture()
	_report_missing()
	if OS.has_feature(GameEdition.FEATURE) and not OS.has_feature("editor"):
		_check_exported()

	GameEdition.force_censored(null)
	print("GAME_EDITION ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)


func _check_path_rule() -> void:
	check(GameEdition.censored_path("res://assets/sprites/characters/portraits/mina.png")
		== "res://assets_censored/sprites/characters/portraits/mina.png", "assets/ 의 짝은 같은 상대 경로")
	check(GameEdition.censored_path("res://data/characters/mina.tres").is_empty(), "assets/ 밖은 짝이 없다")
	check(GameEdition.censored_path("").is_empty(), "빈 경로는 짝이 없다")


func _check_general() -> void:
	GameEdition.force_censored(false)
	for id in CharacterDatabase.get_playable_ids():
		var character: CharacterData = CharacterDatabase.get_character(id)
		if character == null or character.portrait == null:
			continue
		check(PortraitSystem.get_portrait(character) == character.portrait or
			not String(PortraitSystem.get_selected_id(id)).is_empty(), String(id) + ": 일반판 초상은 원본")
		var frames := UITheme.ultimate_frames_path(id)
		check(frames.is_empty() or frames.begins_with(GameEdition.ART_ROOT), String(id) + ": 일반판 오의는 원본")


func _check_censored() -> void:
	GameEdition.force_censored(true)
	for id in CharacterDatabase.get_playable_ids():
		var character: CharacterData = CharacterDatabase.get_character(id)
		if character == null or character.portrait == null:
			continue
		if not String(PortraitSystem.get_selected_id(id)).is_empty():
			continue
		var original := character.portrait.resource_path
		var expected := GameEdition.censored_path(original) if GameEdition.has_censored(original) else original
		var shown := PortraitSystem.get_portrait(character)
		check(shown != null and shown.resource_path == expected, String(id) + ": 검열판 초상은 " + expected)
		if shown != null:
			check(PortraitSystem.get_head_rect(shown) == PortraitSystem.get_head_rect(character.portrait),
				String(id) + ": 검열판 초상도 같은 얼굴 위치를 쓴다")

		var frames := UITheme.ultimate_frames_path(id)
		if frames.begins_with(GameEdition.CENSORED_ROOT):
			_check_censored_frames(id, load(frames) as SpriteFrames)


func _check_censored_frames(id: StringName, frames: SpriteFrames) -> void:
	check(frames != null and frames.has_animation(&"ult"), String(id) + ": 검열판 오의 애니메이션이 있다")
	if frames == null or not frames.has_animation(&"ult"):
		return
	check(frames.get_frame_count(&"ult") == 24, String(id) + ": 검열판 오의는 24장")
	for i in frames.get_frame_count(&"ult"):
		var tex := frames.get_frame_texture(&"ult", i)
		check(tex != null and tex.resource_path.begins_with(GameEdition.CENSORED_ROOT),
			"%s: 검열판 오의 %d장은 assets_censored/ 그림" % [id, i])


# 실제 검열판 파일 없이도 교체 경로를 확인한다. 이미 들어와 있으면 건드리지 않는다.
func _check_fixture() -> void:
	var original := UITheme.ULTIMATE_CUTIN_DIR + "/%s/%s_ult.tres" % [FIXTURE_ID, FIXTURE_ID]
	var fixture := GameEdition.censored_path(original)
	if ResourceLoader.exists(fixture):
		return
	# 이 테스트가 새로 만든 폴더만 지우도록, 원래 있던 가장 깊은 폴더를 기억한다.
	var kept := fixture.get_base_dir()
	while not DirAccess.dir_exists_absolute(kept):
		kept = kept.get_base_dir()
	DirAccess.make_dir_recursive_absolute(fixture.get_base_dir())
	check(ResourceSaver.save(SpriteFrames.new(), fixture) == OK, "임시 검열판 SpriteFrames 저장")

	GameEdition.force_censored(false)
	check(UITheme.ultimate_frames_path(FIXTURE_ID) == original, "일반판은 검열판 그림이 있어도 원본")
	GameEdition.force_censored(true)
	check(UITheme.ultimate_frames_path(FIXTURE_ID) == fixture, "검열판은 짝이 있으면 그 경로")

	DirAccess.remove_absolute(fixture)
	var dir := fixture.get_base_dir()
	while dir != kept:
		DirAccess.remove_absolute(dir)
		dir = dir.get_base_dir()
	check(not FileAccess.file_exists(fixture) and (fixture.get_base_dir() == kept
		or not DirAccess.dir_exists_absolute(fixture.get_base_dir())), "임시 파일·폴더를 지운다")


func _check_exported() -> void:
	var swapped := 0
	for portrait_id in PortraitSystem.get_all_ids():
		var path := PortraitSystem.PORTRAIT_DIR.path_join(String(portrait_id) + ".png")
		if not GameEdition.has_censored(path):
			continue
		var original := (load(path) as Texture2D).get_image()
		var censored := (load(GameEdition.censored_path(path)) as Texture2D).get_image()
		check(original.get_data() == censored.get_data(), String(portrait_id) + ": 내보낸 검열판은 원본 경로도 검열판 그림")
		swapped += 1
	for id in CharacterDatabase.get_playable_ids():
		var path := UITheme.ULTIMATE_CUTIN_DIR + "/%s/%s_ult.tres" % [id, id]
		if not GameEdition.has_censored(path):
			continue
		var frames := load(path) as SpriteFrames
		check(frames != null and frames.get_frame_texture(&"ult", 0).resource_path.begins_with(GameEdition.CENSORED_ROOT),
			String(id) + ": 내보낸 검열판은 원본 오의 경로도 검열판 애니메이션")
		swapped += 1
	print("GAME_EDITION 내보낸 검열판 교체 확인: %d개" % swapped)


func _report_missing() -> void:
	var missing: PackedStringArray = []
	for portrait_id in PortraitSystem.get_all_ids():
		var path := PortraitSystem.PORTRAIT_DIR.path_join(String(portrait_id) + ".png")
		if not GameEdition.has_censored(path):
			missing.append("초상 " + String(portrait_id))
	for id in CharacterDatabase.get_playable_ids():
		var path := UITheme.ULTIMATE_CUTIN_DIR + "/%s/%s_ult.tres" % [id, id]
		if ResourceLoader.exists(path) and not GameEdition.has_censored(path):
			missing.append("오의 " + String(id))
	print("GAME_EDITION 검열판 그림 없음(원본 사용): ", ", ".join(missing) if not missing.is_empty() else "없음")

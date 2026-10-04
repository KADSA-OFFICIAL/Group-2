extends Node

# 오의 연출 검증 (#544).
#
#   1) 6명 모두 컷인이 준비된다. 그림은 게임 그림체(전투 스프라이트 공격 프레임)이거나
#      오의 전용 일러스트(`UITheme.ultimate_cutin_path()`)뿐이다 — 예전 2400×1350 컷인과
#      편성 초상은 쓰지 않는다. 하드코딩된 id 목록이 없다.
#   2) 풀 / 짧게 연출이 정해진 길이 안에서 끝나고, 끝나면 판이 사라진다.
#      6명 모두 LD 공격 애니메이션(#549, 독립 원화 24장 SpriteFrames)이 있고 컷인 판에 실린다.
#      장마다 길이가 있고, 공격 정점 장이 범위 안이며, 정점 장에서 기술명이 박힌다.
#   3) 설정 "오의 연출"이 저장·복원되고, 잘못된 값은 풀로 돌아간다.
#   4) 끄기 모드에서는 컷인 판이 뜨지 않는다.
#
# 창 모드로 돌리면 각 캐릭터의 풀 연출 한 장면을 docs/art-review/missing-art/ 에 남긴다.

var failed := false


func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)


func _ready() -> void:
	var saved_mode := SettingsSystem.ultimate_cutin_mode
	var field = load("res://stage/turn/TurnBattle.tscn").instantiate()
	field.use_stage = false
	add_child(field)
	await get_tree().process_frame

	var legacy_dir := "res://assets/sprites/characters/cutins/char_"
	for id in CharacterDatabase.get_playable_ids():
		var character: CharacterData = CharacterDatabase.get_character(id)
		if character == null or character.get_turn_ultimate() == null:
			continue
		var unit := TurnUnit.new()
		unit.character = character
		unit.display_name = character.display_name
		var skill := character.get_turn_ultimate()
		check(field._setup_cutin(unit, skill, Color(0.6, 0.8, 1.0)), "컷인 준비: " + String(id))

		var picked: Dictionary = field._cutin_art_for(unit)
		var texture: Texture2D = picked["texture"]
		check(texture != null, "컷인 그림이 있어야 한다: " + String(id))
		var path := texture.resource_path if texture != null else ""
		check(not path.begins_with(legacy_dir), "그림체가 다른 예전 컷인을 쓰면 안 된다: " + path)
		check(texture != PortraitSystem.get_portrait(character), "그림체가 다른 편성 초상을 쓰면 안 된다: " + String(id))
		# LD 공격 애니메이션 (#549): 원화 24장이 컷인 판에 실린다.
		var frames_path := UITheme.ultimate_frames_path(id)
		check(not frames_path.is_empty(), "LD 공격 애니메이션이 있어야 한다: " + String(id))
		var frames: SpriteFrames = picked.get("frames")
		check(frames != null, "컷인 그림 고르기가 애니메이션을 넘겨야 한다: " + String(id))
		check(field._cutin._anim == frames, "컷인 판에 애니메이션이 실려야 한다: " + String(id))
		if frames != null:
			var count := frames.get_frame_count(UltimateCutin.ANIM_NAME)
			check(count == 24, "오의 원화는 24장이어야 한다: %s %d" % [id, count])
			var strike := int(frames.get_meta(&"strike_frame", -1))
			check(strike > 0 and strike < count - 1, "공격 정점 장이 범위 밖이다: %s %d" % [id, strike])
			var size0 := frames.get_frame_texture(UltimateCutin.ANIM_NAME, 0).get_size()
			for i in count:
				var tex := frames.get_frame_texture(UltimateCutin.ANIM_NAME, i)
				check(tex != null and tex.get_size() == size0, "장마다 같은 크기로 잘려야 한다: %s %d" % [id, i])
			check(absf(field._cutin._anim_length - 3.0) < 0.6, "원화 길이가 1배속 약 3초여야 한다: %s %.2f" % [id, field._cutin._anim_length])
			check(bool(picked["dedicated"]) and picked["texture"] is AtlasTexture,
				"짧게 모드는 마지막 장(결정 포즈)을 잘라 써야 한다: " + String(id))

		if DisplayServer.get_name() != "headless":
			field._fade_hud(0.0, 0.01)
			field._cutin.play_full()
			await get_tree().create_timer(1.3).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				"res://docs/art-review/missing-art/%s-ult-cutin.png" % id)
			await get_tree().create_timer(1.8).timeout
			field._cutin.reset()

	# 2) 길이: 1배속 기준 풀 ≈ 2초대, 짧게 ≈ 1초 안팎 (presentation_speed 0.7 반영).
	var unit2 := TurnUnit.new()
	unit2.character = CharacterDatabase.get_character(&"seola")
	unit2.display_name = unit2.character.display_name
	field._setup_cutin(unit2, unit2.character.get_turn_ultimate(), Color(0.6, 0.8, 1.0))
	var t0 := Time.get_ticks_msec()
	await field._cutin.play_full()
	var full_s := (Time.get_ticks_msec() - t0) / 1000.0
	# 애니메이션판: 등장(약 0.36초) + 원화 3초(배속 1) + 퇴장. 정지판은 2~3초.
	check(full_s > 2.8 and full_s < 4.6, "풀 연출(애니메이션) 길이가 맞지 않다: %.2fs" % full_s)
	check(field._cutin._anim_struck, "공격 정점 장에서 기술명이 박혀야 한다")
	check(field._cutin._anim_frame == field._cutin._anim.get_frame_count(UltimateCutin.ANIM_NAME) - 1,
		"마지막 장(결정 포즈)까지 재생해야 한다: %d" % field._cutin._anim_frame)
	check(not field._cutin._slash.visible and not field._cutin._art_root.visible, "풀 연출이 끝나면 판이 사라져야 한다")
	t0 = Time.get_ticks_msec()
	await field._cutin.play_short()
	var short_s := (Time.get_ticks_msec() - t0) / 1000.0
	check(short_s > 0.4 and short_s < 1.6, "짧은 연출 길이가 맞지 않다: %.2fs" % short_s)
	check(not field._cutin._strip.visible, "짧은 연출이 끝나면 띠가 사라져야 한다")
	check(short_s < full_s, "짧게가 풀보다 짧아야 한다")

	# reset() 은 재생 중인 연출을 끊는다.
	field._cutin.play_full()
	await get_tree().create_timer(0.3).timeout
	field._cutin.reset()
	check(not field._cutin.visible, "reset() 하면 컷인이 사라져야 한다")
	var frame_at_reset: int = field._cutin._anim_frame
	await get_tree().create_timer(0.3).timeout
	check(field._cutin._anim_frame == frame_at_reset, "reset() 하면 원화 넘김도 멈춰야 한다")

	# 3) 설정 저장·복원
	SettingsSystem.set_ultimate_cutin_mode(SettingsSystem.CutinMode.SHORT)
	var dict := SettingsSystem.to_save_dict()
	check(int(dict.get("ultimate_cutin_mode", -1)) == SettingsSystem.CutinMode.SHORT, "오의 연출 설정이 저장돼야 한다")
	SettingsSystem.from_save_dict({"ultimate_cutin_mode": SettingsSystem.CutinMode.OFF})
	check(SettingsSystem.ultimate_cutin_mode == SettingsSystem.CutinMode.OFF, "오의 연출 설정이 복원돼야 한다")
	SettingsSystem.from_save_dict({"ultimate_cutin_mode": 99})
	check(SettingsSystem.ultimate_cutin_mode == SettingsSystem.CutinMode.FULL, "잘못된 값은 풀로 돌아가야 한다")

	# 4) 끄기: 판이 뜨지 않는다.
	SettingsSystem.set_ultimate_cutin_mode(SettingsSystem.CutinMode.OFF)
	field.battle = TurnBattleManager.new()
	var unit3 := TurnUnit.new()
	unit3.character = unit2.character
	unit3.display_name = unit2.display_name
	var watched := [false]
	var watcher := func():
		if field._cutin.visible:
			watched[0] = true
	get_tree().process_frame.connect(watcher)
	await field._play_cutin({"unit": unit3, "skill": unit3.character.get_turn_ultimate()})
	get_tree().process_frame.disconnect(watcher)
	check(not watched[0], "끄기 모드에서는 컷인 판이 뜨면 안 된다")

	SettingsSystem.set_ultimate_cutin_mode(saved_mode)
	field.queue_free()
	await get_tree().process_frame
	MusicSystem.stop()
	print("DEDICATED_CUTINS ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)

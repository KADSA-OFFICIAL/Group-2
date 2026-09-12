extends Node

# 전투 프레임 시트 검증 (#487).
#
#   godot --headless --path . res://tests/combat/VerifyBattleFrames.tscn
#
# 두 가지를 본다.
#
# 1. **규약 자체** — `BattleAnimation` 의 상수·헬퍼가 일관적인가. 시트가 한 장도 없어도
#    돌아간다. 애니메이션 이름을 늘리거나 프레임 수를 바꿀 때 여기서 먼저 걸린다.
# 2. **저작된 시트** — `.tres` 에 연결된 시트가 규격을 지키는가. 아직 아무도 시트를
#    저작하지 않았으면 이 절은 건너뛴다(빈 슬롯은 정상 상태다 — 화면이 정지
#    스프라이트로 떨어진다).
#
# 왜 "시트가 없으면 실패"로 만들지 않는가: `battle_frames` 는 **선택 슬롯**이다.
# 없으면 `battle_sprite`, 그것도 없으면 네모로 떨어지는 것이 설계다. 없다고 빨간불이
# 켜지면 아트가 들어오기 전까지 이 검증을 아무도 안 보게 된다.

var failures: Array[String] = []
var checks := 0
var sheets_found := 0


func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _ready() -> void:
	await get_tree().process_frame

	_verify_contract()
	_verify_authored()

	for failure in failures:
		push_error(failure)
	print("%s: battle frames verification %d checks, %d authored sheets, %d failures" %
		["PASS" if failures.is_empty() else "FAIL", checks, sheets_found, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


# ===== 1. 규약 =====

func _verify_contract() -> void:
	expect(BattleAnimation.ALL.size() == 4, "애니메이션은 4종이어야 한다")
	expect(BattleAnimation.ALL.has(BattleAnimation.IDLE), "idle 이 있어야 한다")

	for name in BattleAnimation.ALL:
		expect(BattleAnimation.FRAME_COUNT.has(name),
			"%s 의 프레임 수가 정의되지 않았다" % name)
		expect(BattleAnimation.FPS.has(name), "%s 의 fps 가 정의되지 않았다" % name)
		expect(int(BattleAnimation.FRAME_COUNT.get(name, 0)) > 0,
			"%s 의 프레임 수는 1 이상이어야 한다" % name)
		expect(float(BattleAnimation.FPS.get(name, 0.0)) > 0.0,
			"%s 의 fps 는 0보다 커야 한다" % name)

	# 루프하는 것은 idle 하나뿐이다. death 가 루프하면 시체가 계속 쓰러진다.
	# (`as Array[StringName]` 을 비교식 안에 쓰면 캐스트가 비교 전체에 걸려 파스 에러가 난다.)
	expect(BattleAnimation.LOOPING.size() == 1, "루프 애니메이션은 하나여야 한다")
	expect(BattleAnimation.LOOPING.has(BattleAnimation.IDLE),
		"루프하는 것은 idle 이어야 한다")

	# 빈 시트 처리
	expect(not BattleAnimation.is_usable(null), "null 시트는 쓸 수 없어야 한다")
	expect(BattleAnimation.missing_animations(null).size() == 4,
		"null 시트는 4종 전부 누락으로 보고해야 한다")
	expect(BattleAnimation.cell_size(null) == Vector2.ZERO,
		"null 시트의 셀 크기는 0이어야 한다")

	# idle 만 있는 시트는 쓸 수 있어야 한다 (나머지는 트윈으로 떨어진다)
	var partial := SpriteFrames.new()
	partial.remove_animation(&"default")
	partial.add_animation(BattleAnimation.IDLE)
	partial.add_frame(BattleAnimation.IDLE, PlaceholderTexture2D.new())
	expect(BattleAnimation.is_usable(partial), "idle 만 있어도 쓸 수 있어야 한다")
	expect(BattleAnimation.missing_animations(partial).size() == 3,
		"idle 만 있는 시트는 3종 누락으로 보고해야 한다")

	# 프레임이 0개인 애니메이션은 "있다"로 세면 안 된다 — 재생하면 빈 화면이 된다.
	var empty := SpriteFrames.new()
	empty.remove_animation(&"default")
	empty.add_animation(BattleAnimation.IDLE)
	expect(not BattleAnimation.is_usable(empty),
		"프레임이 0개인 idle 은 쓸 수 없어야 한다")


# ===== 2. 저작된 시트 =====

func _verify_authored() -> void:
	for id in CharacterDatabase.get_all_ids():
		var data: CharacterData = CharacterDatabase.get_character(id)
		if data != null:
			_verify_sheet(String(id), data.battle_frames, Vector2(56, 84))

	for id in EnemyDatabase.get_all_ids():
		var data: EnemyData = EnemyDatabase.get_enemy(id)
		if data != null:
			_verify_sheet(String(id), data.battle_frames, Vector2(62, 78))


func _verify_sheet(unit_id: String, frames: SpriteFrames, box: Vector2) -> void:
	if frames == null:
		return  # 빈 슬롯은 정상이다 — 정지 스프라이트로 떨어진다.
	sheets_found += 1

	expect(BattleAnimation.is_usable(frames), "%s: idle 이 없는 시트다" % unit_id)

	var cell := BattleAnimation.cell_size(frames)
	expect(cell.x > 0.0 and cell.y > 0.0, "%s: 셀 크기를 읽을 수 없다" % unit_id)
	# 칸보다 작으면 확대되어 뭉갠다. 칸 비율과 크게 어긋나면 여백이 남는다.
	expect(cell.x >= box.x and cell.y >= box.y,
		"%s: 셀 %s 이 표시 칸 %s 보다 작다 — 확대되어 뭉갠다" % [unit_id, cell, box])

	for name in frames.get_animation_names():
		var anim := StringName(name)
		expect(BattleAnimation.ALL.has(anim),
			"%s: 규약에 없는 애니메이션 '%s'" % [unit_id, name])
		expect(frames.get_frame_count(anim) > 0,
			"%s: '%s' 에 프레임이 없다" % [unit_id, name])
		expect(frames.get_animation_loop(anim) == BattleAnimation.LOOPING.has(anim),
			"%s: '%s' 의 루프 설정이 규약과 다르다" % [unit_id, name])

		# 프레임마다 셀 크기가 다르면 인물이 프레임 사이에서 튄다.
		for i in frames.get_frame_count(anim):
			var texture := frames.get_frame_texture(anim, i)
			expect(texture != null, "%s: '%s' %d번 프레임이 비었다" % [unit_id, name, i])
			if texture != null:
				expect(texture.get_size().is_equal_approx(cell),
					"%s: '%s' %d번 프레임의 셀 크기가 다르다 %s != %s"
						% [unit_id, name, i, texture.get_size(), cell])

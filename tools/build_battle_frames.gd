@tool
extends SceneTree

# 낱장 프레임 PNG 를 `SpriteFrames` `.tres` 로 조립한다 (#487).
#
# 생성 도구는 스프라이트 시트의 격자를 정확히 못 맞춘다 — 이 프로젝트에서 이미 겪었다
# (`tools/normalize_walk_sheet.gd` 머리말: *"셀 폭이 정수로 나뉘지 않는다",
# "프레임마다 캐릭터가 셀 안에서 한쪽으로 흘러간다"*). 그래서 **한 장짜리 시트를 받지
# 않고 낱장 프레임을 받는다.** 낱장은 격자 문제가 없고, 한 컷이 마음에 안 들면 그것만
# 다시 뽑으면 된다.
#
# ## 입력 규약
#
#   assets/sprites/characters/battle/frames/<id>/<anim>_<n>.png     아군
#   assets/sprites/enemies/battle/frames/<id>/<anim>_<n>.png        적
#
# `<anim>` 은 idle / attack / hit / death, `<n>` 은 0 부터. 예: `harang/attack_0.png`.
#
# ## 출력
#
#   assets/sprites/characters/battle/frames/<id>.tres  (SpriteFrames)
#
# 그 `.tres` 를 `CharacterData.battle_frames` / `EnemyData.battle_frames` 에 지정한다.
#
# ## 실행
#
#   godot --headless --path . --script tools/build_battle_frames.gd
#
# 낱장이 하나도 없는 유닛은 건너뛴다. 있는 동작만 넣으므로 `idle` 만 그려도 동작한다.

const ALLY_DIR := "res://assets/sprites/characters/battle/frames"
const ENEMY_DIR := "res://assets/sprites/enemies/battle/frames"


func _init() -> void:
	var built := 0
	for root in [ALLY_DIR, ENEMY_DIR]:
		for unit_id in _sub_dirs(root):
			if _build_one(root, unit_id):
				built += 1
	print("[build_battle_frames] %d개 시트를 만들었다." % built)
	quit()


func _sub_dirs(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			out.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _build_one(root: String, unit_id: String) -> bool:
	var folder := root.path_join(unit_id)
	var frames := SpriteFrames.new()
	# 새 `SpriteFrames` 는 빈 `default` 를 갖고 태어난다. 남겨 두면 그 이름이
	# 애니메이션 목록에 섞여 검증이 헷갈린다.
	frames.remove_animation(&"default")

	var total := 0
	var cell := Vector2.ZERO
	for anim in BattleAnimation.ALL:
		var textures := _load_frames(folder, String(anim))
		if textures.is_empty():
			continue

		frames.add_animation(anim)
		frames.set_animation_loop(anim, BattleAnimation.LOOPING.has(anim))
		frames.set_animation_speed(anim, float(BattleAnimation.FPS[anim]))
		for texture in textures:
			frames.add_frame(anim, texture)
			# 셀 크기가 프레임마다 다르면 인물이 프레임 사이에서 튄다.
			var size := texture.get_size()
			if cell == Vector2.ZERO:
				cell = size
			elif not size.is_equal_approx(cell):
				push_warning("[build_battle_frames] %s/%s: 셀 크기가 다르다 %s != %s"
					% [unit_id, anim, size, cell])
		total += textures.size()

	if total == 0:
		return false

	var out_path := root.path_join(unit_id + ".tres")
	var error := ResourceSaver.save(frames, out_path)
	if error != OK:
		push_error("[build_battle_frames] 저장 실패 %s (%d)" % [out_path, error])
		return false

	print("  %s: %d프레임 / 셀 %s / 동작 %s"
		% [unit_id, total, cell, frames.get_animation_names()])
	return true


# `<anim>_0.png` 부터 번호가 끊길 때까지 읽는다.
#
# 번호가 중간에 비면 거기서 멈춘다 — 빠진 컷을 조용히 건너뛰고 이어 붙이면 동작이
# 어긋난 채로 재생되고, 그걸 화면에서 알아채기 어렵다.
func _load_frames(folder: String, anim: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var index := 0
	while true:
		var path := folder.path_join("%s_%d.png" % [anim, index])
		if not ResourceLoader.exists(path):
			break
		var texture: Texture2D = load(path)
		if texture == null:
			push_error("[build_battle_frames] 읽을 수 없다: %s" % path)
			break
		out.append(texture)
		index += 1
	return out

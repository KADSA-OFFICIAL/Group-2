extends Node

# 플레이어에게 보이는 글에 개발 노트가 섞이지 않았는지 검사한다 (#360).
#
# `description` 은 **개발자용**이라 이슈 번호·`[임시값]`·필드명이 들어 있다.
# 화면이 그것을 그대로 그리는 곳이 있었다 — 플레이어가 "제작 비용은 [임시값]이며
# 밸런싱 대상이다", "튜토리얼 스테이지(#345) … #208 로 탐지 범위가 600 이 되어" 를
# 읽었다. `summary` 를 따로 두어 갈랐고(#353 이 스킬에서 먼저 했다), 이 검사가
# **다시 새는 것을 막는다.**
#
# 검사는 둘이다.
#   1. 저작된 `summary` 에 개발 노트 표시가 없는가.
#   2. 화면 코드가 `description` 이 아니라 `summary` 를 읽는가 —
#      필드만 만들고 화면을 안 고치면 아무것도 달라지지 않는다.
#
# **`description` 은 검사하지 않는다.** 거기에 이슈 번호가 있는 것이 정상이다.

# 플레이어용 글에 있으면 안 되는 것들.
const FORBIDDEN := [
	"[임시값]",   # 밸런싱 표시
	"**",          # 마크다운
	"`",           # 코드 표기
	"TODO",
	"[미정]",
]

# 필드명이 글에 그대로 나오면 개발 노트다.
const FIELD_WORDS := [
	"base_power", "cooldown", "description", "summary", "tier",
	"physical_attack_bonus", "stage_id", "equipment_id",
]

# `summary` 를 읽어야 하는 화면과, 거기서 그리는 데이터.
const SCREEN_READS := {
	"res://screens/equipment/equipment_screen.gd": "item.summary",
	"res://screens/stage/stage_select_screen.gd": "stage.summary",
	"res://screens/characters/characters_screen.gd": "skill.summary",
}

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame

	for id in EquipmentDatabase.get_all_ids():
		var item: EquipmentData = EquipmentDatabase.get_equipment(id)
		if item != null:
			_check("장비 %s" % String(id), item.summary)

	for id in StageDatabase.get_all_ids():
		var stage: StageData = StageDatabase.get_stage(id)
		if stage != null:
			_check("스테이지 %s" % String(id), stage.summary)

	# 스킬은 #353 이 먼저 했다. 같은 규약이므로 함께 지킨다.
	for path in _files_in("res://data/skills"):
		var skill: SkillData = load(path)
		if skill != null:
			_check("스킬 %s" % path.get_file(), skill.summary)

	_check_screens()

	if _failures.is_empty():
		print("PASS: player-facing text carries no developer notes")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


# 한 편의 플레이어용 글을 본다.
func _check(label: String, text: String) -> void:
	if text.strip_edges().is_empty():
		_failures.append("%s: summary 가 비어 있다 — 화면에 아무것도 안 나온다" % label)
		return

	for marker in FORBIDDEN:
		if text.contains(marker):
			_failures.append("%s: 플레이어용 글에 '%s' 가 있다" % [label, marker])

	for word in FIELD_WORDS:
		if text.contains(word):
			_failures.append("%s: 플레이어용 글에 필드명 '%s' 가 있다" % [label, word])

	# 이슈 번호. `#345` 처럼 우물정 뒤에 숫자가 오는 것만 잡는다 —
	# 색상 표기(`#D9B26A`)나 문장 부호로 쓰인 우물정은 여기 대상이 아니다.
	for i in text.length() - 1:
		if text[i] == "#" and text[i + 1].is_valid_int():
			_failures.append("%s: 플레이어용 글에 이슈 번호가 있다" % label)
			break


# 화면이 실제로 summary 를 읽는지 본다.
#
# 필드를 만들고 저작까지 해도 화면이 여전히 description 을 그리면 아무것도
# 달라지지 않는다 — 데이터 검사만으로는 그 상태가 통과한다.
func _check_screens() -> void:
	for path in SCREEN_READS:
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			_failures.append("%s: 읽을 수 없다" % path)
			continue
		var needle: String = SCREEN_READS[path]
		if not text.contains(needle):
			_failures.append("%s: '%s' 를 읽지 않는다" % [path, needle])
		# description 을 그리는 자리가 남아 있으면 안 된다.
		var leaked: String = needle.replace(".summary", ".description")
		if text.contains(leaked):
			_failures.append("%s: 아직 '%s' 를 그린다" % [path, leaked])


func _files_in(folder: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			out.append(folder.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
	return out

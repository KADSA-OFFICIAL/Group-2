extends Node

# 챕터 해금 규칙 검증 (#434).
#
# 확인하는 것: 앞 챕터를 전부 클리어할 때까지 다음 챕터가 열리지 않는다.
#
# 클리어 기록은 StageProgress.from_save_dict() 로 넣는다 — 판을 실제로 이기지 않고
# "이만큼 깬 세이브"를 만드는 공개 경로가 그것뿐이고, 저장 스키마를 그대로 쓰기 때문에
# 세이브 왕복에서도 같은 판정이 나오는지 함께 확인된다.
#
# 실제 저작 데이터(data/stages)를 쓴다. 챕터 2·3 이 아직 저작되지 않아도 판정은
# 챕터 1 의 클리어 여부만 보므로(미저작 챕터는 장벽이 아니다) 그대로 검사할 수 있다.

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame

	var chapters := StageDatabase.get_authored_chapters()
	_expect(chapters.has(1), "1챕터가 저작되어 있어야 한다(검사의 전제)")
	var chapter_1_ids := StageDatabase.get_ids_by_chapter(1)
	_expect(not chapter_1_ids.is_empty(), "1챕터에 스테이지가 있어야 한다(검사의 전제)")

	# ----- 클리어 기록이 없는 새 세이브 -----
	_set_clears([])
	_expect(not StageProgress.is_chapter_cleared(1), "안 깬 1챕터는 클리어됨이 아니다")
	_expect(StageProgress.is_chapter_unlocked(1), "첫 저작 챕터는 기록 없이도 열려 있다")
	_expect(not StageProgress.is_chapter_unlocked(2), "1챕터를 깨기 전에는 2챕터가 잠겨 있다")
	_expect(not StageProgress.is_chapter_unlocked(3), "앞 챕터가 미저작이면 그보다 앞의 저작 챕터를 본다")
	_expect(StageProgress.get_unlocked_chapters() == [1], "새 세이브에서 열린 챕터는 1챕터뿐이다")

	# ----- 1챕터를 일부만 클리어 -----
	if chapter_1_ids.size() >= 2:
		_set_clears([chapter_1_ids[0]])
		_expect(not StageProgress.is_chapter_cleared(1), "일부만 깬 챕터는 클리어됨이 아니다")
		_expect(not StageProgress.is_chapter_unlocked(2), "1챕터를 일부만 깨면 2챕터는 아직 잠겨 있다")
		_expect(StageProgress.get_unlocked_chapters() == [1], "일부 클리어로 챕터가 늘지 않는다")

	# ----- 1챕터를 전부 클리어 -----
	_set_clears(chapter_1_ids)
	_expect(StageProgress.is_chapter_cleared(1), "1챕터를 전부 깨면 클리어됨이다")
	_expect(StageProgress.is_chapter_unlocked(2), "1챕터를 전부 깨면 2챕터가 열린다")
	for id in chapter_1_ids:
		_expect(StageProgress.is_unlocked(id), "열린 챕터의 스테이지는 열려 있다: " + String(id))

	# 열린 챕터 목록에 미저작 챕터가 섞이지 않는다 — 목록 화면이 빈 머리를 띄우면 안 된다.
	for chapter in StageProgress.get_unlocked_chapters():
		_expect(chapters.has(chapter), "열린 챕터 목록에 미저작 챕터가 있다: %d" % chapter)

	# 스테이지가 없는 챕터는 "깰 것이 없었을 뿐"이라 클리어됨이 아니다.
	for chapter in [1, 2, 3]:
		if StageDatabase.get_ids_by_chapter(chapter).is_empty():
			_expect(not StageProgress.is_chapter_cleared(chapter),
				"미저작 챕터는 클리어됨이 아니다: %d" % chapter)

	# ----- 챕터 밖 스테이지와 알 수 없는 id -----
	_set_clears([])
	for id in StageDatabase.get_chapterless_ids():
		_expect(StageProgress.is_unlocked(id), "챕터 밖 스테이지는 항상 열려 있다: " + String(id))
	_expect(not StageProgress.is_unlocked(&"stage_does_not_exist"), "알 수 없는 id 는 열려 있다고 하지 않는다")

	# ----- 저장 스키마가 늘지 않았다 -----
	# 해금은 클리어 기록에서 도출된다. 별도 저장 필드가 생기면 두 값이 어긋날 수 있다.
	_expect(StageProgress.to_save_dict().keys() == ["clears"],
		"해금 때문에 저장 스키마가 늘어나면 안 된다: " + str(StageProgress.to_save_dict().keys()))

	if _failures.is_empty():
		print("PASS: 챕터 해금 — 앞 챕터를 전부 깨야 다음 챕터가 열린다")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


# 주어진 스테이지만 1회 클리어한 세이브 상태를 만든다.
func _set_clears(ids: Array) -> void:
	var clears := {}
	for id in ids:
		clears[String(id)] = 1
	StageProgress.from_save_dict({"clears": clears})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

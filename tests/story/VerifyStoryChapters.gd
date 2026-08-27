extends Node

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	var expected_ids := [
		&"chapter_1", &"chapter_2", &"chapter_3", &"chapter_4",
		&"chapter_5", &"chapter_6", &"chapter_7",
	]
	_expect(StoryDatabase.get_all_ids() == expected_ids, "story catalog must contain Chapters 1-7 in order")

	var expected_line_counts := {
		&"chapter_5": 42,
		&"chapter_6": 72,
		&"chapter_7": 26,
	}
	for chapter_id in expected_line_counts:
		var chapter := StoryDatabase.get_chapter(chapter_id)
		_expect(chapter != null, "%s must load" % chapter_id)
		if chapter == null:
			continue
		_expect(chapter.validate().is_empty(), "%s must validate" % chapter_id)
		_expect(chapter.lines.size() == expected_line_counts[chapter_id], "%s line count changed" % chapter_id)
		_verify_speakers(chapter)

	var chapter_5 := StoryDatabase.get_chapter(&"chapter_5")
	var chapter_6 := StoryDatabase.get_chapter(&"chapter_6")
	var chapter_7 := StoryDatabase.get_chapter(&"chapter_7")
	if chapter_5:
		_expect(chapter_5.get_battle_count() == 3, "Chapter 5 must mark travel, follow-up, and boss battles")
	if chapter_6:
		_expect(chapter_6.get_battle_count() == 1, "Chapter 6 must mark the final boss battle")
	if chapter_7:
		_expect(chapter_7.lines[-1].text == "-The end-", "Chapter 7 must retain the ending card")

	if _failures.is_empty():
		print("PASS: Chapters 5-7 load, validate, and preserve story beats")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _verify_speakers(chapter: StoryChapterData) -> void:
	for line in chapter.lines:
		if line.kind != StoryLineData.Kind.DIALOGUE:
			continue
		if line.speaker == "???":
			_expect(String(line.character_id).is_empty(), "anonymous speakers must remain unresolved")
		elif not String(line.character_id).is_empty():
			_expect(line.get_character() != null, "%s has an unresolved character id" % line.speaker)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

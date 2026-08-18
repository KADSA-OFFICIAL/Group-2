extends Resource
class_name StoryChapterData

# 스토리 챕터의 단일 정의 출처 (data definition).
# StageData / ShopEntryData 와 같은 규약을 따른다.

# ===== 식별 (Identity) =====
@export var chapter_id: StringName = &""   # 고유 식별자 (예: &"chapter_1")

# 표시 순서. 목록을 이 값으로 정렬한다(디렉터리 순회 순서에 기대지 않는다).
@export var number: int = 1

@export var title: String = ""
@export_multiline var summary: String = ""

# ===== 대본 =====
@export var lines: Array[StoryLineData] = []


# 이 챕터에 전투가 몇 번 끼는가. 목록에서 미리 보여준다.
func get_battle_count() -> int:
	var n := 0
	for line in lines:
		if line != null and line.kind == StoryLineData.Kind.BATTLE:
			n += 1
	return n


# 등장 화자 목록(중복 없이, 나온 순서대로).
func get_speakers() -> Array[String]:
	var out: Array[String] = []
	for line in lines:
		if line == null or line.kind != StoryLineData.Kind.DIALOGUE:
			continue
		if not out.has(line.speaker):
			out.append(line.speaker)
	return out


func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(chapter_id).is_empty():
		problems.append("chapter_id가 비어 있습니다.")
	if title.is_empty():
		problems.append("title이 비어 있습니다.")
	if lines.is_empty():
		problems.append("대본(lines)이 비어 있습니다.")
	for i in range(lines.size()):
		var line := lines[i]
		if line == null:
			problems.append("%d번째 줄이 비어 있습니다." % (i + 1))
			continue
		for p in line.validate():
			problems.append("%d번째 줄: %s" % [i + 1, p])
	return problems

## res://data/chapter_db.gd
## 더미 챕터/스테이지 공급기. HTML 프로토타입과 같은 값.
## 2차에서 .tres / CSV / JSON 테이블 로더로 교체할 자리.

class_name ChapterDB
extends RefCounted

const STAGE_NAMES := [
	"관문", "폐허 입구", "무너진 다리", "성벽", "안마당",
	"회랑", "제단", "봉인의 방", "무너진 성소", "새벽의 군주",
]
# 스테이지 1~8 의 클리어 별 개수 (더미)
const CLEARED_STARS := [3, 3, 2, 3, 3, 2, 3, 3]

const CHAPTER_DEFS := [
	{"num": "31장", "name": "잿빛 평원"},
	{"num": "32장", "name": "속삭이는 숲"},
	{"num": "33장", "name": "균열의 새벽"},
	{"num": "34장", "name": "심연의 문 (잠김)"},
]

static func all_chapters(hard: bool) -> Array[ChapterData]:
	var out: Array[ChapterData] = []
	for d in CHAPTER_DEFS:
		out.append(make_chapter(d["num"], d["name"], hard))
	return out

static func make_chapter(number_label: String, name: String, hard: bool) -> ChapterData:
	var ch := ChapterData.new()
	ch.number_label = number_label
	ch.name = name
	var base: float = 1.6 if hard else 1.0
	var chap_num := number_label.trim_suffix("장")
	for i in STAGE_NAMES.size():
		var n := i + 1
		var s := StageData.new()
		s.index = n
		s.code = "%s-%d" % [chap_num, n]
		s.name = STAGE_NAMES[i]
		s.is_boss = (n == 10)
		# 더미 진행도: 1~8 클리어, 9 현재, 10 잠김
		if n <= 8:
			s.stars = CLEARED_STARS[i]
		elif n == 9:
			s.stars = 0
		else:
			s.stars = -1
		s.recommended_power = int(round((38000 + n * 1600) * base))
		s.stamina_cost = int(round((10 + n / 3) * base))
		s.sweep_ticket_cost = s.stamina_cost
		ch.stages.append(s)
	return ch

extends Node

# 스테이지 진행도의 단일 출처 (autoload).
#
# 책임 둘:
#   1. 어느 스테이지를 몇 번 깼는지 기억한다(저장 대상).
#   2. 승리했을 때 클리어 보상을 지급하도록 CurrencySystem 에 요청한다.
#      프로틴도 재화이므로 같은 경로로 나간다(#204) — 여기서 잔액을 직접 만지지 않는다.
#
# 왜 StageDatabase / StageSystem 과 나누는가:
#   StageDatabase 는 **저작 데이터**(스테이지 정의)를 소유한다. 플레이어마다 달라지지 않는다.
#   StageSystem 은 **지금 어느 스테이지인가**만 안다. 저장 대상이 아니다.
#   클리어 기록은 **플레이어 상태**다. 저장되고 플레이어마다 다르다.
#   (StoryDatabase 와 StoryProgress 를 나눈 것과 같은 이유다.)
#
# 단일 출처 원칙:
#   보상 정의   -> StageData.clear_rewards (프로틴 포함)
#   재화 잔액   -> CurrencySystem (여기서 잔액을 직접 만지지 않는다)
#   삼각근 Lv.  -> PlayerProfile (프로틴 지급을 재화 신호로 듣고 스스로 정산한다)
#   클리어 기록 -> 여기
#
# 참고: autoload/StoryProgress.gd, entities/stage/StageData.gd

# 저장 스키마에서 스테이지 진행도가 들어가는 키.
const SAVE_KEY := "stage_progress"

# 진행도가 바뀔 때. 화면은 이 신호로만 갱신한다.
signal progress_changed()

# stage_id(String) -> 클리어 횟수(int).
# 키를 String 으로 두는 이유: 저장 스키마(JSON)의 키가 문자열이라 왕복에서 형이 바뀐다.
var _clears: Dictionary = {}

# 방금 끝난 판의 결과. 결과 화면이 읽는다.
# { "stage_id": StringName, "victory": bool, "rewards": Dictionary, "first_clear": bool }
var _last_result: Dictionary = {}


func _ready() -> void:
	name = "StageProgress"
	SaveSystem.register_provider(SAVE_KEY, self)

	# 판이 끝나는 것은 게임 규칙이다. 화면이 떠 있든 아니든 정산된다.
	EventBus.stage_completed.connect(_on_stage_completed)
	EventBus.stage_failed.connect(_on_stage_failed)


# ===== 조회 (Query) =====

func get_clear_count(stage_id: StringName) -> int:
	return int(_clears.get(String(stage_id), 0))


func is_cleared(stage_id: StringName) -> bool:
	return get_clear_count(stage_id) > 0


func get_cleared_count() -> int:
	return _clears.size()


# 방금 끝난 판의 결과. 아직 판이 끝난 적 없으면 빈 Dictionary.
# 결과 화면은 자기가 받은 stage_id 와 대조한 뒤 쓴다(다른 판의 결과를 보여주지 않도록).
func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


# ===== 해금 (Unlock) — #434 =====
#
# 앞 챕터를 전부 클리어할 때까지 다음 챕터는 출격 목록에 뜨지 않는다.
#
# 왜 저장 필드를 새로 만들지 않는가: 해금은 **클리어 기록에서 도출된다.** "2챕터 열림"을
# 따로 저장하면 클리어 기록과 어긋난 세이브(스테이지는 안 깼는데 챕터는 열린)가 만들어질 수 있다.
# StageData 가 승리 조건을 type 에서, 컨셉을 chapter 에서 도출한 것과 같은 규약이다.
#
# 왜 화면이 아니라 여기인가: 해금은 **플레이어 상태에 대한 판정**이다. 규칙이 화면에 있으면
# 목록 화면과 (나중에 생길) 출격 차단·다음 스테이지 추천이 각자 규칙을 갖는다.
# 챕터 구성과 정렬은 그대로 StageDatabase 가 소유하고, 여기는 그것에 클리어 기록을 겹친다.

# 챕터의 저작된 스테이지를 전부 클리어했는가.
# 스테이지가 하나도 저작되지 않은 챕터는 "클리어됨"이 아니다(깰 것이 없었을 뿐이다).
func is_chapter_cleared(chapter: int) -> bool:
	var ids := StageDatabase.get_ids_by_chapter(chapter)
	if ids.is_empty():
		return false
	for id in ids:
		if not is_cleared(id):
			return false
	return true


# 이 챕터가 열려 있는가.
#
# 기준은 **바로 앞의 저작된 챕터**다. 챕터 번호에서 1을 빼지 않는 이유: 앞 챕터가 아직
# 저작되지 않았으면(스테이지 0개) 클리어가 불가능하고, 그것을 장벽으로 세면 뒷 챕터가
# 영구히 잠긴다. 저작 중인 지금은 2챕터가 비어 있어도 3챕터를 열어 볼 수 있어야 한다.
#
# 첫 번째로 저작된 챕터는 클리어 기록이 없어도 열려 있다(새 세이브에서 1챕터).
# 챕터 밖(NO_CHAPTER)은 챕터가 아니므로 항상 열려 있다 — 테스트·연습 스테이지가 잠기지 않는다.
func is_chapter_unlocked(chapter: int) -> bool:
	if chapter == StageData.NO_CHAPTER:
		return true

	var previous := _previous_authored_chapter(chapter)
	if previous == StageData.NO_CHAPTER:
		return true
	return is_chapter_cleared(previous)


# 이 스테이지가 열려 있는가. 챕터 단위 해금이므로 같은 챕터의 세 스테이지는 함께 열린다.
# 알 수 없는 id 는 열려 있다고 하지 않는다 — 어느 챕터의 것인지 판정할 근거가 없다.
func is_unlocked(stage_id: StringName) -> bool:
	if not StageDatabase.has_stage(stage_id):
		return false
	return is_chapter_unlocked(StageDatabase.get_stage(stage_id).chapter)


# 열려 있는 챕터 번호 목록(오름차순). 저작된 챕터 중에서만 나온다.
# 목록 화면은 이쪽을 돌면 되고 챕터마다 판정을 다시 하지 않는다.
func get_unlocked_chapters() -> Array:
	var result: Array = []
	for chapter in StageDatabase.get_authored_chapters():
		if is_chapter_unlocked(chapter):
			result.append(chapter)
	return result


# chapter 보다 앞에 있는, 스테이지가 저작된 챕터 중 가장 큰 번호. 없으면 NO_CHAPTER.
func _previous_authored_chapter(chapter: int) -> int:
	var previous := StageData.NO_CHAPTER
	for authored in StageDatabase.get_authored_chapters():
		if authored < chapter:
			previous = authored
	return previous


# ===== 정산 (Settle) =====

func _on_stage_completed(stage_name) -> void:
	var stage_id := StringName(str(stage_name))
	var first_clear := not is_cleared(stage_id)

	_clears[String(stage_id)] = get_clear_count(stage_id) + 1

	# 보상에 프로틴이 있으면 지급 도중 삼각근 Lv.이 오른다(PlayerProfile 이 재화 신호로 정산).
	# 결과 화면이 "이번에 올랐다"를 보여줄 수 있게 지급 전후 Lv.을 함께 남긴다.
	var level_before := PlayerProfile.deltoid_level

	_last_result = {
		"stage_id": stage_id,
		"victory": true,
		"rewards": _grant_rewards(stage_id),
		"deltoid_level_before": level_before,
		"deltoid_level_after": PlayerProfile.deltoid_level,
		"first_clear": first_clear,
	}

	# 자동 저장 요청. 실제 파일 쓰기는 SaveSystem 이 한 프레임에 한 번으로 모은다.
	SaveSystem.request_save()
	progress_changed.emit()


func _on_stage_failed(stage_name) -> void:
	# 패배는 기록도 보상도 없다. 결과 화면이 무엇을 보여줄지 알 수 있게 결과만 남긴다.
	_last_result = {
		"stage_id": StringName(str(stage_name)),
		"victory": false,
		"rewards": {},
		"deltoid_level_before": PlayerProfile.deltoid_level,
		"deltoid_level_after": PlayerProfile.deltoid_level,
		"first_clear": false,
	}


# 저작된 보상을 지급하고, 실제로 지급된 것만 돌려준다.
# 지급 자체는 CurrencySystem 이 한다(잔액의 주인이 그쪽이다).
func _grant_rewards(stage_id: StringName) -> Dictionary:
	var stage := StageDatabase.get_stage(stage_id) if StageDatabase.has_stage(stage_id) else null
	if stage == null:
		return {}

	var granted: Dictionary = {}
	for currency_type in stage.clear_rewards:
		var amount := int(stage.clear_rewards[currency_type])
		if amount <= 0:
			continue
		if CurrencySystem.add_currency(str(currency_type), amount):
			granted[str(currency_type)] = amount
	return granted


# ===== 저장 (Save) =====
# SaveSystem 은 이 안을 모른다. 스키마의 이 부분은 여기가 소유한다.

func to_save_dict() -> Dictionary:
	return { "clears": _clears.duplicate() }


func from_save_dict(data: Dictionary) -> void:
	_clears.clear()
	var saved = data.get("clears", {})
	if typeof(saved) != TYPE_DICTIONARY:
		return

	for key in saved:
		# 저장 파일이 손상되었거나 손으로 고쳤을 수 있다. 정수만 받는다.
		var count := int(saved[key])
		if count > 0:
			_clears[str(key)] = count
	progress_changed.emit()

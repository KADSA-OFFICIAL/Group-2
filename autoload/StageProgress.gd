extends Node

# 스테이지 진행도의 단일 출처 (autoload).
#
# 책임 둘:
#   1. 어느 스테이지를 몇 번 깼는지 기억한다(저장 대상).
#   2. 승리했을 때 그 스테이지의 클리어 보상을 지급하도록 CurrencySystem 에 요청한다.
#
# 왜 StageDatabase / StageSystem 과 나누는가:
#   StageDatabase 는 **저작 데이터**(스테이지 정의)를 소유한다. 플레이어마다 달라지지 않는다.
#   StageSystem 은 **지금 어느 스테이지인가**만 안다. 저장 대상이 아니다.
#   클리어 기록은 **플레이어 상태**다. 저장되고 플레이어마다 다르다.
#   (StoryDatabase 와 StoryProgress 를 나눈 것과 같은 이유다.)
#
# 단일 출처 원칙:
#   보상 정의   -> StageData.clear_rewards
#   재화 잔액   -> CurrencySystem (여기서 잔액을 직접 만지지 않는다)
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


# ===== 정산 (Settle) =====

func _on_stage_completed(stage_name) -> void:
	var stage_id := StringName(str(stage_name))
	var first_clear := not is_cleared(stage_id)

	_clears[String(stage_id)] = get_clear_count(stage_id) + 1

	_last_result = {
		"stage_id": stage_id,
		"victory": true,
		"rewards": _grant_rewards(stage_id),
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

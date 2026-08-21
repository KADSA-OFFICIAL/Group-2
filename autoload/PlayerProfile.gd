extends Node

# 플레이어 프로필의 단일 출처 (autoload).
#
# 책임: 플레이어의 이름과 **삼각근 Lv.** 을 보유하고, 프로틴을 소모해 Lv.을 올린다.
#
# 단일 출처 원칙:
#   - 화면(메인화면 프로필 칩 등)은 이 시스템에서 읽기만 한다. 값을 따로 들지 않는다.
#   - **프로틴 잔액은 CurrencySystem 이 소유한다.** 여기서 잔액을 따로 들지 않는다.
#     성장의 재료는 재화이고, 재화의 주인은 그쪽이다(#204).
#   - 파티/장비는 각자의 시스템이 출처다. 여기서 다시 정의하지 않는다.
#
# 왜 "레벨"이 아니라 "삼각근"인가:
#   chapter_1 의 주인공 동기가 삼각근 성장이고, PlayerStats.strength 도 이미
#   "삼각근 강화로 상승"이라고 적혀 있다. 성장축의 이름이 곧 이 게임의 성장이다.

# 저장 스키마에서 프로필이 들어가는 키.
const SAVE_KEY := "profile"

# 성장 재료로 쓰는 재화 id. 정의 출처는 CurrencySystem.DEFAULT_CURRENCIES 다.
const PROTEIN := "protein"

# 삼각근 Lv.의 하한. 0이나 음수는 표시·계산 모두에서 의미가 없다.
const MIN_LEVEL: int = 1

# ===== 성장 곡선 (Growth curve) — #192 [확정] =====
#
# 다음 삼각근 Lv.까지 필요한 프로틴은 지수 곡선이다.
#   required_protein(n) = BASE_PROTEIN * PROTEIN_GROWTH^(n-1)     (Lv.n -> Lv.n+1)
#
# 값: 50, 75, 112, 168, 253 ...   누적: 50, 125, 237, 405, 658 ...
# 내림(int 절삭)을 쓴다 — 반올림이면 112.5 가 113이 되어 표에 적은 값과 어긋난다.
const BASE_PROTEIN: int = 50
const PROTEIN_GROWTH: float = 1.5

# 삼각근 Lv. 하나당 기초 스텟 상승폭(비율). Lv.1 은 보너스 없음(+0%).
const STAT_GAIN_PER_LEVEL: float = 0.05

# 프로필 값이 바뀔 때. 화면은 이 신호로만 갱신한다.
signal profile_changed()

# 삼각근 Lv.이 올랐을 때. (이전 Lv., 새 Lv.)
# 결과 화면처럼 "이번에 올랐다"는 사건 자체가 필요한 쪽이 쓴다.
signal deltoid_level_up(from_level: int, to_level: int)

# 플레이어가 정한 이름. 비어 있으면 화면이 대체 문구를 쓴다(여기서 기본 이름을 만들지 않는다).
var player_name: String = ""

# 현재 삼각근 Lv. **저장 대상**이다.
#
# 왜 파생이 아닌가(#192 에서 바뀐 점): 프로틴이 재화가 되면서 잔액은 소모로 줄어든다.
# 줄어드는 값에서 "지금까지 얼마나 성장했는가"를 되짚을 수 없으므로 Lv.을 직접 든다.
# 대신 누적 프로틴은 어디에도 두지 않는다 — 두 값이 어긋날 여지를 만들지 않는다.
var deltoid_level: int = MIN_LEVEL


func _ready() -> void:
	name = "PlayerProfile"

	# 프로틴이 **어느 경로로 들어오든**(스테이지 클리어·상점·우편) 같은 정산이 돌아야 한다.
	# 그래서 지급하는 쪽을 일일이 고치지 않고 재화 신호 하나를 듣는다.
	CurrencySystem.currency_added.connect(_on_currency_added)

	# 저장 스키마의 프로필 부분은 이 시스템이 소유한다(SaveSystem 은 내부를 모른다).
	# 복원은 이 호출 안에서 바로 일어난다.
	SaveSystem.register_provider(SAVE_KEY, self)

	# 저장된 잔액이 이미 기준을 넘었을 수 있다(곡선을 낮추는 밸런스 변경 등).
	_settle_level_ups()
	# 복원된 삼각근 Lv.을 로스터에 반영한다.
	# autoload 순서상 CharacterDatabase 는 이미 로드를 마친 뒤다(project.godot 참고).
	_apply_growth()


# ===== 조회 (Query) =====

# Lv.n -> Lv.n+1 에 필요한 프로틴. n < MIN_LEVEL 이면 0.
static func required_protein(level: int) -> int:
	if level < MIN_LEVEL:
		return 0
	return int(BASE_PROTEIN * pow(PROTEIN_GROWTH, level - MIN_LEVEL))


# Lv.n 에 도달하는 데 드는 **누적** 프로틴. Lv.1 은 0이다.
# 구 세이브 마이그레이션과 저작 참고용이다(런타임 계산에는 쓰지 않는다).
static func protein_for_level(level: int) -> int:
	var total := 0
	for n in range(MIN_LEVEL, level):
		total += required_protein(n)
	return total


# 누적 프로틴이 만드는 삼각근 Lv. (구 세이브 마이그레이션용)
static func level_for_protein(protein: int) -> int:
	var level := MIN_LEVEL
	var remaining := maxi(protein, 0)
	while remaining >= required_protein(level):
		remaining -= required_protein(level)
		level += 1
	return level


# 다음 Lv.까지의 진행도. (지금 가진 프로틴, 다음 Lv.에 필요한 프로틴)
# 잔액의 주인은 CurrencySystem 이므로 여기서 들지 않고 그때그때 읽는다.
func get_level_progress() -> Dictionary:
	return {
		"current": CurrencySystem.get_balance(PROTEIN),
		"required": required_protein(deltoid_level),
	}


# 삼각근 Lv.이 기초 스텟에 주는 배수. Lv.1 = 1.0, Lv.5 = 1.20.
func get_stat_multiplier() -> float:
	return 1.0 + STAT_GAIN_PER_LEVEL * float(deltoid_level - MIN_LEVEL)


# ===== 변경 (Mutation) =====

func set_player_name(value: String) -> void:
	if value == player_name:
		return
	player_name = value
	profile_changed.emit()


# ===== 성장 정산 (Level-up settlement) =====

func _on_currency_added(currency_type: String, _amount: int, _new_balance: int) -> void:
	if currency_type == PROTEIN:
		_settle_level_ups()


# 잔액이 기준을 넘는 동안 필요량만큼 **차감하며** Lv.을 올린다.
# 한 번에 여러 Lv.도 오른다. 남은 잔액은 다음 Lv.의 진행도로 남는다.
#
# subtract_currency 는 currency_subtracted 를 쏘므로 _on_currency_added 로 되돌아오지 않는다.
func _settle_level_ups() -> void:
	var before := deltoid_level
	while CurrencySystem.get_balance(PROTEIN) >= required_protein(deltoid_level):
		if not CurrencySystem.subtract_currency(PROTEIN, required_protein(deltoid_level)):
			break
		deltoid_level += 1

	if deltoid_level == before:
		return

	_apply_growth()
	SaveSystem.request_save()
	deltoid_level_up.emit(before, deltoid_level)
	profile_changed.emit()


# ===== 성장 반영 (Growth propagation) =====

# 삼각근 Lv.의 스텟 배수를 로스터 전원에게 밀어 넣는다.
#
# 왜 PlayerStats 가 스스로 PlayerProfile 을 읽지 않는가:
#   PlayerStats 는 적(EnemyData.stats)도 공유한다. 스텟 쪽에서 자동 조회하면
#   **적까지 같이 강해진다.** 장비(equip_*)·버프(buff_*) 와 같은 규약대로,
#   값을 밀어 넣는 쪽이 대상을 정한다. 대상은 로스터(CharacterDatabase)뿐이다.
func _apply_growth() -> void:
	var multiplier := get_stat_multiplier()
	for id in CharacterDatabase.get_all_ids():
		var character: CharacterData = CharacterDatabase.get_character(id)
		if character != null:
			character.get_stats().set_growth_multiplier(multiplier)


# ===== 저장/복원 (Save / Load) =====
# SaveSystem 은 이 두 함수만 호출한다.

func to_save_dict() -> Dictionary:
	# 프로틴 잔액은 CurrencySystem 이 자기 키("currencies")에 저장한다. 여기서 중복하지 않는다.
	return {
		"name": player_name,
		"deltoid_level": deltoid_level,
	}


func from_save_dict(data: Dictionary) -> void:
	# 없는 키는 현재 값을 유지한다(구 세이브 호환).
	player_name = String(data.get("name", player_name))

	if data.has("deltoid_level"):
		deltoid_level = maxi(int(data["deltoid_level"]), MIN_LEVEL)
		profile_changed.emit()
		return

	# ----- 구 스키마 마이그레이션 -----
	# #192 의 protein_total(누적) 과 그 이전의 level / exp_total 을 모두 받는다.
	# 있는 키만 후보로 넣는다 — 없는 키의 자리를 현재 값으로 메우면 이전 상태가
	# 섞여 들어와 세이브에 적힌 것보다 큰 값으로 복원될 수 있다.
	var candidates: Array[int] = []
	if data.has("protein_total"):
		candidates.append(int(data["protein_total"]))
	if data.has("exp_total"):
		candidates.append(int(data["exp_total"]))
	if data.has("level"):
		candidates.append(protein_for_level(maxi(int(data["level"]), MIN_LEVEL)))

	if candidates.is_empty():
		profile_changed.emit()
		return

	var cumulative := 0
	for candidate in candidates:
		cumulative = maxi(cumulative, candidate)

	# 누적값을 "도달한 Lv. + 남은 잔액"으로 나눈다. 어느 쪽도 잃지 않는다.
	deltoid_level = level_for_protein(cumulative)
	var leftover := cumulative - protein_for_level(deltoid_level)
	if leftover > 0:
		# leftover 는 항상 required_protein(deltoid_level) 미만이라 Lv.이 더 오르지 않는다.
		CurrencySystem.add_currency(PROTEIN, leftover)

	profile_changed.emit()

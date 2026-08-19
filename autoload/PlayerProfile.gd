extends Node

# 플레이어 프로필의 단일 출처 (autoload).
#
# 책임: 플레이어의 이름과 **삼각근 Lv./프로틴**을 보유한다.
#
# 단일 출처 원칙:
#   - 화면(메인화면 프로필 칩 등)은 이 시스템에서 읽기만 한다. 값을 따로 들지 않는다.
#   - 파티/재화/장비는 각자의 시스템이 출처다. 여기서 다시 정의하지 않는다.
#
# 왜 "레벨"이 아니라 "삼각근"인가:
#   chapter_1 의 주인공 동기가 삼각근 성장이고, PlayerStats.strength 도 이미
#   "삼각근 강화로 상승"이라고 적혀 있다. 성장축의 이름이 곧 이 게임의 성장이다.
#
# 왜 프로틴을 CurrencySystem 재화로 두지 않는가:
#   프로틴은 잔액이 아니라 **진행도**다. 소비처가 없고 레벨업으로 차감되지도 않는다.
#   재화로 만들면 창고·상점이 "쓸 수 없는 재화"를 하나 떠안게 된다.

# 저장 스키마에서 프로필이 들어가는 키.
const SAVE_KEY := "profile"

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

# 누적 프로틴. **성장의 단일 출처**다. 줄어들지 않는다.
#
# 삼각근 Lv.을 따로 저장하지 않는 이유: 둘 다 저장하면 서로 어긋난 세이브가
# 만들어질 수 있다(손으로 고친 파일, 구 버전 등). 레벨은 언제나 여기서 파생한다.
var protein_total: int = 0


func _ready() -> void:
	name = "PlayerProfile"
	# 저장 스키마의 프로필 부분은 이 시스템이 소유한다(SaveSystem 은 내부를 모른다).
	# 복원은 이 호출 안에서 바로 일어난다.
	SaveSystem.register_provider(SAVE_KEY, self)
	# 복원된 삼각근 Lv.을 로스터에 반영한다.
	# autoload 순서상 CharacterDatabase 는 이미 로드를 마친 뒤다(project.godot 참고).
	_apply_growth()


# ===== 조회 (Query) =====

# 현재 삼각근 Lv. 누적 프로틴에서 파생한다.
var deltoid_level: int:
	get:
		return level_for_protein(protein_total)


# Lv.n -> Lv.n+1 에 필요한 프로틴. n < MIN_LEVEL 이면 0.
static func required_protein(level: int) -> int:
	if level < MIN_LEVEL:
		return 0
	return int(BASE_PROTEIN * pow(PROTEIN_GROWTH, level - MIN_LEVEL))


# Lv.n 에 도달하는 데 필요한 **누적** 프로틴. Lv.1 은 0이다.
static func protein_for_level(level: int) -> int:
	var total := 0
	for n in range(MIN_LEVEL, level):
		total += required_protein(n)
	return total


# 누적 프로틴이 만드는 삼각근 Lv.
static func level_for_protein(protein: int) -> int:
	var level := MIN_LEVEL
	var remaining := maxi(protein, 0)
	while remaining >= required_protein(level):
		remaining -= required_protein(level)
		level += 1
	return level


# 다음 Lv.까지의 진행도. (현재 Lv. 안에서 모은 프로틴, 다음 Lv.에 필요한 프로틴)
func get_level_progress() -> Dictionary:
	var level := deltoid_level
	return {
		"current": protein_total - protein_for_level(level),
		"required": required_protein(level),
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


# 프로틴을 더한다. 음수는 무시한다.
# 기준을 넘으면 그 자리에서 삼각근 Lv.이 오른다(한 번에 여러 Lv.도 가능).
func add_protein(amount: int) -> void:
	if amount <= 0:
		return
	var before := deltoid_level
	protein_total += amount
	var after := deltoid_level

	if after != before:
		_apply_growth()
		deltoid_level_up.emit(before, after)
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
	# 삼각근 Lv.은 파생값이라 저장하지 않는다(누적 프로틴 하나가 출처다).
	return {
		"name": player_name,
		"protein_total": protein_total,
	}


func from_save_dict(data: Dictionary) -> void:
	# 없는 키는 현재 값을 유지한다(구 세이브 호환).
	player_name = String(data.get("name", player_name))

	# 구 스키마(level / exp_total) 마이그레이션.
	# 누적 경험치는 그대로 프로틴으로 잇고, 저장돼 있던 레벨은 "그 Lv.에 도달하는 데
	# 필요한 누적 프로틴"으로 환산해 가장 큰 쪽을 쓴다 — 어느 쪽도 값을 잃지 않는다.
	#
	# **있는 키만** 후보로 넣는다. 없는 키의 자리를 현재 값으로 메우면 이전 상태가
	# 섞여 들어와, 세이브에 적힌 것보다 큰 값으로 복원될 수 있다.
	var candidates: Array[int] = []
	if data.has("protein_total"):
		candidates.append(int(data["protein_total"]))
	if data.has("exp_total"):
		candidates.append(int(data["exp_total"]))
	if data.has("level"):
		candidates.append(protein_for_level(maxi(int(data["level"]), MIN_LEVEL)))

	# 프로필 키가 하나도 없는 세이브면 현재 값을 그대로 둔다.
	if not candidates.is_empty():
		var restored := 0
		for candidate in candidates:
			restored = maxi(restored, candidate)
		protein_total = restored

	_apply_growth()
	profile_changed.emit()

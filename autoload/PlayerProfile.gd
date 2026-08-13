extends Node

# 플레이어 프로필의 단일 출처 (autoload).
#
# 책임: 플레이어의 이름·레벨·누적 경험치를 보유한다. **뼈대만이다.**
#
# 단일 출처 원칙:
#   - 화면(메인화면 프로필 칩 등)은 이 시스템에서 읽기만 한다. 값을 따로 들지 않는다.
#   - 파티/재화/장비는 각자의 시스템이 출처다. 여기서 다시 정의하지 않는다.
#
# 밸런스는 팀의 몫이다 (CombatConfig 의 [확정]/[임시값] 표기 방식을 따른다):
#   [확정]  프로필이 이름·레벨·누적 경험치를 갖는다.
#   [미정]  레벨업에 필요한 경험치 곡선. 정해지지 않았으므로 **여기서 만들지 않는다.**
#           그래서 add_exp() 는 경험치를 누적할 뿐 레벨을 올리지 않는다.
#           곡선이 정해지면 required_exp(level) 를 두고 add_exp() 안에서 승급을 처리한다.
#   [미정]  시작 레벨·이름 규칙. 아래 기본값은 "비어 있음"에 가까운 값일 뿐 밸런스가 아니다.

# 저장 스키마에서 프로필이 들어가는 키.
const SAVE_KEY := "profile"

# 레벨의 하한. 0레벨이나 음수 레벨은 표시·계산 모두에서 의미가 없다.
const MIN_LEVEL: int = 1

# 프로필 값이 바뀔 때. 화면은 이 신호로만 갱신한다.
signal profile_changed()

# 플레이어가 정한 이름. 비어 있으면 화면이 대체 문구를 쓴다(여기서 기본 이름을 만들지 않는다).
var player_name: String = ""

# 현재 레벨.
var level: int = MIN_LEVEL

# 누적 경험치. 레벨업 곡선이 [미정] 이므로 지금은 누적만 한다.
var exp_total: int = 0


func _ready() -> void:
	name = "PlayerProfile"
	# 저장 스키마의 프로필 부분은 이 시스템이 소유한다(SaveSystem 은 내부를 모른다).
	SaveSystem.register_provider(SAVE_KEY, self)


# ===== 변경 (Mutation) =====

func set_player_name(value: String) -> void:
	if value == player_name:
		return
	player_name = value
	profile_changed.emit()


# 레벨을 직접 지정한다. MIN_LEVEL 아래로는 내려가지 않는다.
func set_level(value: int) -> void:
	var clamped := maxi(value, MIN_LEVEL)
	if clamped == level:
		return
	level = clamped
	profile_changed.emit()


# 경험치를 더한다. 음수는 무시한다.
#
# 레벨업을 하지 않는 이유: 필요 경험치 곡선이 [미정] 이다.
# 곡선 없이 임의의 수치를 넣으면 나중에 밸런스를 잡을 때 이 값이 근거처럼 남는다.
func add_exp(amount: int) -> void:
	if amount <= 0:
		return
	exp_total += amount
	profile_changed.emit()


# ===== 저장/복원 (Save / Load) =====
# SaveSystem 은 이 두 함수만 호출한다.

func to_save_dict() -> Dictionary:
	return {
		"name": player_name,
		"level": level,
		"exp_total": exp_total,
	}


func from_save_dict(data: Dictionary) -> void:
	# 없는 키는 현재 값을 유지한다(구 세이브 호환).
	player_name = String(data.get("name", player_name))
	level = maxi(int(data.get("level", level)), MIN_LEVEL)
	exp_total = maxi(int(data.get("exp_total", exp_total)), 0)
	profile_changed.emit()

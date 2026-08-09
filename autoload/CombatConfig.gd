extends Node

# 전투 튜닝 수치의 접근 지점 (autoload).
#
# 수치의 단일 출처는 data/combat/combat_tuning.tres (CombatTuning 리소스)다.
# 이 autoload는 그 리소스를 로드해 제공하기만 하며, 값을 여기에 다시 정의하지 않는다.
#
#   사용 예: CombatConfig.tuning.mark_threshold
#
# 밸런싱 방법: Godot 에디터에서 data/combat/combat_tuning.tres를 열고 인스펙터에서 숫자를 고친다.
#             코드를 편집할 필요가 없다. (이전에는 여기 const를 고쳐야 했다.)
#
# 주의(단일 출처): 캐릭터별 스텟(공격력/방어력/HP 등)은 PlayerStats가 소유한다.
#   여기에는 그 값을 복제하지 않고, "전투 메커니즘 공통 규칙" 수치만 둔다.
#
# [폐기] 브루저 · 패링(PARRY_*) 상수는 제거되었다.
#   역할이 브루저 -> 탱커로 바뀌며 패링 기본기 자체가 폐기되었고, 표식이 버퍼에서 탱커로 이동했다.
#   폐기된 메커니즘의 수치를 남겨두면 그것을 보고 구현할 위험이 있어 삭제한다.
#   (docs/combat-screen-design.md §2 참조)
#
# 참고: docs/combat-screen-design.md §8.1, SYSTEM_CONVENTIONS.md

const TUNING_PATH := "res://data/combat/combat_tuning.tres"

# 전투 튜닝 수치. _ready()에서 .tres를 로드해 채운다.
# .tres가 없거나 손상되어도 기본값으로 폴백하므로 null이 되지 않는다.
var tuning: CombatTuning = null


func _ready() -> void:
	name = "CombatConfig"
	_load_tuning()


# 튜닝 리소스를 로드한다. 실패하면 코드 기본값으로 폴백한다.
# 폴백이 있어야 .tres가 빠진 상태에서도 게임이 죽지 않는다.
func _load_tuning() -> void:
	if not ResourceLoader.exists(TUNING_PATH):
		push_warning("CombatConfig: 튜닝 리소스를 찾을 수 없어 기본값을 사용합니다: " + TUNING_PATH)
		tuning = CombatTuning.new()
		return

	var res := load(TUNING_PATH)
	if not (res is CombatTuning):
		push_warning("CombatConfig: CombatTuning이 아니어서 기본값을 사용합니다: " + TUNING_PATH)
		tuning = CombatTuning.new()
		return

	tuning = res

	var problems := tuning.validate()
	if not problems.is_empty():
		push_warning("CombatConfig: 튜닝 값에 문제가 있습니다: " + ", ".join(problems))


# 튜닝 리소스를 디스크에서 다시 읽는다.
# 밸런싱 중 .tres를 고친 뒤 재시작 없이 반영하고 싶을 때 쓴다.
func reload_tuning() -> void:
	if not ResourceLoader.exists(TUNING_PATH):
		_load_tuning()
		return

	# 캐시를 우회해 디스크 내용을 다시 읽는다.
	var fresh := ResourceLoader.load(TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if fresh is CombatTuning:
		tuning = fresh
	else:
		push_warning("CombatConfig: 재로드 실패, 기존 값을 유지합니다: " + TUNING_PATH)

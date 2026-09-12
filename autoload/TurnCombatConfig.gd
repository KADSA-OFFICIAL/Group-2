extends Node

# 턴제 전투 튜닝 수치의 접근 지점 (autoload, #450).
#
# 수치의 단일 출처는 `data/combat/turn_combat_tuning.tres` (`TurnCombatTuning` 리소스)다.
# 이 autoload는 그 리소스를 로드해 제공하기만 하며, 값을 여기에 다시 정의하지 않는다.
#
#   사용 예: TurnCombatConfig.tuning.resonance_max
#
# 기존 `CombatConfig`(실시간)와 **나란히 존재한다.** 하나로 합치지 않은 이유:
# 실시간 수치(대시 충전, 감지 범위, 초 단위 쿨다운)와 턴제 수치(AV, 인성치, 버킷)는
# 서로를 쓰지 않는 별개 축이고, 실시간 전투가 살아 있는 동안 한 리소스에 섞으면
# 한쪽 밸런싱이 다른 쪽 `.tres`를 계속 흔든다.
#
# 밸런싱 방법: Godot 에디터에서 `data/combat/turn_combat_tuning.tres`를 열고 인스펙터에서 고친다.
#
# 참고: docs/turn-combat-design.md, SYSTEM_CONVENTIONS.md §1

const TUNING_PATH := "res://data/combat/turn_combat_tuning.tres"

# 턴제 튜닝 수치. `.tres`가 없거나 손상되어도 코드 기본값으로 폴백하므로 null이 되지 않는다.
var tuning: TurnCombatTuning = null

# 적 정보를 얼마나 공개하는가 (설계서 §4.8.2). 기본은 상세 — 설계 3원칙의 첫 줄이
# "모든 정보를 공개한다"이므로, 정보를 숨기는 쪽이 옵트인이어야 한다.
var info_detail: int = TurnCombat.InfoDetail.VERBOSE


func _ready() -> void:
	name = "TurnCombatConfig"
	_load_tuning()


func _load_tuning() -> void:
	if not ResourceLoader.exists(TUNING_PATH):
		push_warning("TurnCombatConfig: 튜닝 리소스를 찾을 수 없어 기본값을 사용합니다: " + TUNING_PATH)
		tuning = TurnCombatTuning.new()
		return

	var res := load(TUNING_PATH)
	if not (res is TurnCombatTuning):
		push_warning("TurnCombatConfig: TurnCombatTuning이 아니어서 기본값을 사용합니다: " + TUNING_PATH)
		tuning = TurnCombatTuning.new()
		return

	tuning = res

	var problems := tuning.validate()
	if not problems.is_empty():
		push_warning("TurnCombatConfig: 튜닝 값에 문제가 있습니다: " + ", ".join(problems))


# 밸런싱 중 `.tres`를 고친 뒤 재시작 없이 반영한다.
func reload_tuning() -> void:
	if not ResourceLoader.exists(TUNING_PATH):
		_load_tuning()
		return

	var fresh := ResourceLoader.load(TUNING_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if fresh is TurnCombatTuning:
		tuning = fresh
	else:
		push_warning("TurnCombatConfig: 재로드 실패, 기존 값을 유지합니다: " + TUNING_PATH)

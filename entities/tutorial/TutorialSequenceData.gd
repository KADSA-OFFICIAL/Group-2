extends Resource
class_name TutorialSequenceData

# 스테이지 하나의 튜토리얼 단계 묶음 (data definition).
#
# 스테이지 id 로 찾을 수 있어야 하므로 시퀀스가 자기 stage_id 를 들고 있다.
# 스테이지 정의(StageData)에 단계를 넣지 않은 이유: 스테이지는 승리 조건·배치·보상의
# 출처이고, 튜토리얼은 그 위에 얹히는 안내다. 섞으면 튜토리얼이 없는 스테이지마다
# 빈 필드가 생기고, 안내를 고칠 때 스테이지 정의를 건드리게 된다.
#
# 참고: entities/tutorial/TutorialStepData.gd, autoload/TutorialSystem.gd

# 이 시퀀스가 걸리는 스테이지. StageData.stage_id 와 같은 값이다(출처는 StageData).
@export var stage_id: StringName = &""

# 순서가 곧 진행 순서다.
@export var steps: Array[TutorialStepData] = []

# ===== 어느 전투의 안내인가 (#594) =====
#
# 같은 스테이지(1-1)에 실시간 안내와 턴제 안내가 **나란히** 있다. 두 전투가 공존하므로
# (SYSTEM_CONVENTIONS §1) 어느 쪽에 걸리는지를 시퀀스가 밝힌다. 기본값이 실시간이라
# 기존 저작본은 그대로 읽힌다.
enum Combat { REALTIME, TURN }
@export var combat: Combat = Combat.REALTIME

# ===== 저작된 전투 (턴제 전용) =====
#
# 안내는 "하랑의 충격이 자물쇠를 연다"처럼 **결과를 약속하고** 가르친다. 시드나 적 정의가
# 바뀌어 자물쇠 조합이 달라지면 약속이 깨지고 단계가 멈추므로, 안내가 쓰는 판을 여기서 고정한다.

## 전투 시드. 0 이면 평소처럼 시간으로 정한다.
@export var battle_seed: int = 0

## 아군 HP 하한. 1 이면 이 전투에서 지지 않는다(피해 숫자는 그대로 나온다).
@export var ally_hp_floor: int = 0

## 적 `unit_id` -> 첫 예고의 자물쇠. 원소는 "e<Element>", 물리는 "p<PhysicalType>" (예: ["e0", "e2"]).
## 비우면 평소대로 약점에서 뽑는다. 약점이 아닌 타입은 넣지 않는다 — 열어도 인성치가 안 깎인다.
@export var scripted_locks: Dictionary = {}


## 완료 기록·조회에 쓰는 키. 실시간은 예전 그대로 stage_id 라 기존 세이브가 그대로 읽힌다.
func sequence_key() -> StringName:
	if combat == Combat.TURN:
		return StringName("turn/" + String(stage_id))
	return stage_id


func get_step(index: int) -> TutorialStepData:
	if index < 0 or index >= steps.size():
		return null
	return steps[index]


func get_count() -> int:
	return steps.size()


# ===== 무결성 점검 (Validation) =====
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(stage_id).is_empty():
		problems.append("stage_id가 비어 있습니다.")
	if steps.is_empty():
		problems.append("steps가 비어 있습니다: " + String(stage_id))

	var seen := {}
	for i in range(steps.size()):
		var step := steps[i]
		if step == null:
			problems.append("steps[%d]가 비어 있습니다." % i)
			continue
		for p in step.validate():
			problems.append("steps[%d]: %s" % [i, p])
		# 전투 종류와 진행 조건이 엇갈리면 그 단계는 영영 넘어가지 않는다.
		var turn_step := TutorialStepData.is_turn_advance(step.advance)
		if turn_step and combat != Combat.TURN:
			problems.append("steps[%d]: 턴제 진행 조건인데 실시간 시퀀스입니다." % i)
		if combat == Combat.TURN and not turn_step 				and step.advance != TutorialStepData.Advance.CONFIRM:
			problems.append("steps[%d]: 실시간 진행 조건인데 턴제 시퀀스입니다." % i)
		if seen.has(step.step_id):
			problems.append("step_id가 중복되었습니다: " + String(step.step_id))
		seen[step.step_id] = true

	for key in scripted_locks:
		var codes = scripted_locks[key]
		if not (codes is Array) or (codes as Array).is_empty():
			problems.append("scripted_locks[%s]가 비어 있습니다." % key)
			continue
		for code in codes:
			if parse_lock_code(String(code)) == null:
				problems.append("scripted_locks[%s]: 알 수 없는 코드 %s" % [key, code])

	return problems


## "e6" -> 광휘 원소 자물쇠, "p2" -> 강타 물리 자물쇠. 잘못된 코드면 null.
static func parse_lock_code(code: String) -> TurnLock:
	if code.length() < 2 or not code.substr(1).is_valid_int():
		return null
	var value := code.substr(1).to_int()
	match code[0]:
		"e":
			if value < 0 or value >= TurnCombat.Element.size():
				return null
			return TurnLock.new(true, value)
		"p":
			if value < 0 or value >= TurnCombat.PhysicalType.size():
				return null
			return TurnLock.new(false, value)
	return null


## 저작된 자물쇠를 전투에 건다. 전투 화면이 `start()` 직후(첫 턴 전)에 부른다.
## 찾지 못한 적은 경고만 하고 넘어간다 — 그 적은 평소대로 약점에서 뽑힌 자물쇠를 갖는다.
func apply_scripted_locks(battle: TurnBattleManager) -> void:
	if battle == null:
		return
	for key in scripted_locks:
		var unit := battle.find_unit(StringName(String(key)))
		if unit == null or unit.intent == null:
			push_warning("TutorialSequenceData: 자물쇠를 걸 적이 없습니다: " + String(key))
			continue
		var locks: Array[TurnLock] = []
		for code in scripted_locks[key]:
			var lock := parse_lock_code(String(code))
			if lock != null:
				locks.append(lock)
		unit.intent.locks = locks
		unit.intent.recalculate_power()

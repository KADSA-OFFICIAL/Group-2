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
		if seen.has(step.step_id):
			problems.append("step_id가 중복되었습니다: " + String(step.step_id))
		seen[step.step_id] = true

	return problems

extends Resource
class_name TutorialStepData

# 튜토리얼 한 단계의 단일 정의 출처 (data definition).
#
# 담는 것은 **무엇을 보여 주고 무엇으로 넘어가는지**뿐이다.
# 진행 상태(지금 몇 번째인지·끝났는지)는 TutorialSystem 이 들고 있고,
# 그리기는 HUD 가 한다. 셋을 나눠 두면 단계를 늘려도 코드가 늘지 않는다.
#
# 왜 데이터인가: 안내 문구와 순서는 기획이 고치는 값이다. 스크립트에 박아 두면
# 문구 한 줄을 바꿀 때마다 코드를 고쳐야 하고, 스테이지가 늘면 분기가 늘어난다.
# 이 저장소의 다른 도메인(EnemyData/SkillData/StageData)과 같은 규약을 따른다.
#
# 참고: entities/tutorial/TutorialSequenceData.gd, autoload/TutorialSystem.gd

# ===== 진행 조건 (Advance) =====
#
# 이 단계를 벗어나는 조건. **플레이어가 실제로 그 행동을 했을 때** 넘어가게 하려고
# 신호 기반으로 정의한다(시간이 지나면 넘어가는 방식은 배우지 않아도 지나간다).
#
# 각 항목이 어느 신호에 걸리는지는 TutorialSystem 이 안다 — 여기서는 종류만 정한다.
enum Advance {
	CONFIRM,          # 확인 키 입력
	DASH,             # 플레이어가 대시했다 (EventBus.player_dashed)
	EFFECT_APPLIED,   # 적에게 effect_id 가 부여됐다 (EventBus.status_effect_applied)
	EFFECT_BURST,     # effect_id 게이지가 임계치에서 터졌다 (EventBus.status_effect_burst)
	EXECUTE,          # 처형이 성사됐다 (EventBus.enemy_executed)
}

# ===== 식별 (Identity) =====
@export var step_id: StringName = &""    # 시퀀스 안에서 고유 (예: &"dash")

# ===== 표시 (Presentation) =====
@export var title: String = ""
@export_multiline var body: String = ""

# ===== 진행 (Advance) =====
@export var advance: Advance = Advance.CONFIRM

## EFFECT_APPLIED / EFFECT_BURST 전용. 상태 효과 정의(data/status_effects/*.tres)의 id 다.
## 여기서 효과를 정의하지 않는다 — 출처는 StatusEffectDatabase 다.
@export var effect_id: StringName = &""

## 조건이 이 횟수만큼 성립해야 넘어간다. 1 이면 한 번으로 넘어간다.
@export var required_count: int = 1


# ===== 무결성 점검 (Validation) =====
# EnemyData / StageData 와 같은 규약. 문제 메시지 배열을 반환한다.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(step_id).is_empty():
		problems.append("step_id가 비어 있습니다.")
	if body.is_empty():
		problems.append("body가 비어 있습니다: " + String(step_id))
	if required_count < 1:
		problems.append("required_count는 1 이상이어야 합니다: %d" % required_count)

	# 효과 조건인데 effect_id 가 없으면 그 단계는 **영원히 넘어가지 않는다.**
	# 튜토리얼이 전투를 멈춘 채 대기하므로 게임이 사실상 멈춘다 — 로드 때 잡는다.
	if advance in [Advance.EFFECT_APPLIED, Advance.EFFECT_BURST] and String(effect_id).is_empty():
		problems.append("effect_id가 필요한 진행 조건입니다: " + String(step_id))

	return problems

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
	# ----- 턴제 (#594) — 값이 .tres 에 숫자로 저작되므로 반드시 뒤에 붙인다 -----
	TURN_BASIC,        # actor_id 가 평타를 썼다 (EventBus.turn_action_used)
	TURN_SKILL,        # actor_id 가 전투 스킬을 썼다 (skill_id 가 있으면 그 스킬)
	TURN_ULTIMATE,     # actor_id 가 궁극기를 썼다
	TURN_LOCK_CLEARED, # target_id 적의 자물쇠가 열렸다 (EventBus.turn_lock_cleared)
	TURN_BREAK,        # target_id 적이 격파됐다 (EventBus.turn_weakness_broken)
	TURN_VICTORY,      # 전투에서 이겼다 (EventBus.turn_battle_ended)
}

## 턴제 진행 조건인가. 턴제 조건은 실시간 전투에서 영원히 오지 않고, 그 반대도 같다.
static func is_turn_advance(value: int) -> bool:
	return value >= Advance.TURN_BASIC

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

# ===== 턴제 안내 (#594) — 실시간 단계는 전부 비워 둔다 =====
#
# 턴제 단계는 "누가 · 무엇을 · 누구에게"를 정해 두고 **그 조작만** 받는다(강제 진행).
# 판정·입력 차단은 TutorialSystem 이, 그리기(하이라이트·대사 패널)는 화면이 한다.

## 이 단계를 말하는 인물의 id. 스토리 대사(`StoryLineData.character_id`)와 같은 순서로 푼다 —
## CharacterDatabase -> EnemyDatabase -> StoryCastDatabase. 이름·초상은 거기서 온다(복제하지 않는다).
## 비우면 이름표 없는 안내문으로 뜬다.
@export var speaker_id: StringName = &""

## 화면이 강조할 곳. 화면이 아는 키다:
##   timeline · resonance · intent · toggles
##   action:<skill_id> · ultimate:<unit_id> · target:<unit_id>
## 비우면 강조하지 않는다.
@export var highlight: StringName = &""

## 행동해야 할 아군(`TurnUnit.unit_id` = character_id). 이 단계가 오면 이 아군의 차례를 당긴다.
@export var actor_id: StringName = &""

## 써야 할 행동(`SkillData.skill_id`). 비우면 그 아군의 어떤 행동이든 된다.
@export var skill_id: StringName = &""

## 노려야 할 적(`TurnUnit.unit_id`, 예: &"mammoth_beastfolk#1"). 비우면 대상 제한 없음.
@export var target_id: StringName = &""

## 이 단계부터 배속·자동·일시정지를 쓸 수 있다. 그 전에는 안내가 끝까지 보이도록 잠근다.
@export var unlock_controls: bool = false

## 첫 궁극기처럼 **크게 보여 줄** 단계. 화면이 연출을 키운다(컷인 설정과 무관하게 풀 컷인).
@export var showcase: bool = false


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

	# 누가 행동해야 하는지 모르면 그 아군의 차례를 당길 수 없어 단계가 멈춘다.
	if advance in [Advance.TURN_BASIC, Advance.TURN_SKILL, Advance.TURN_ULTIMATE] 			and String(actor_id).is_empty():
		problems.append("actor_id가 필요한 진행 조건입니다: " + String(step_id))
	if advance in [Advance.TURN_LOCK_CLEARED, Advance.TURN_BREAK] and String(target_id).is_empty():
		problems.append("target_id가 필요한 진행 조건입니다: " + String(step_id))

	return problems

extends Resource
class_name CaptureZoneData

# 거점 존 한 곳의 정의 (data definition). 설계 §5.1 의 "점령" 프리미티브가 걸리는 대상이다.
#
# 왜 별도 리소스인가: StageSpawn 과 같은 이유다. 존은 "어디에 / 얼마나 크게 / 몇 초"
# 세 값의 묶음이고, StageData 에 배열 세 개로 두면 인덱스가 어긋난 저작 실수를 막을 수 없다.
#
# 여기 없는 것과 그 이유:
#   - 진행도: **런타임 상태**다. CaptureZone 노드가 소유한다(정의에 담으면 .tres 가 플레이 중에 변한다).
#   - 차는 속도·감소 배수: 스테이지마다 다를 값이 아니라 **게임 공통 규칙**이라
#     CombatTuning(capture_hold_seconds / capture_decay_multiplier)이 소유한다.
#     EnemyData 가 절대 속도 대신 배수만 갖는 것과 같은 분리다.
#   - 적이 역으로 점령하는 규칙, 존 활성화 순서: 설계 §5.2 에서 아직 [미정]이라 필드를 만들지 않았다.
#
# 참고: entities/stage/StageData.gd, entities/stage/CaptureZone.gd, docs/combat-screen-design.md §5

# 존 중심(스테이지 로컬 좌표). StageSpawn.position 과 같은 좌표계다.
@export var position: Vector2 = Vector2.ZERO

# 존 반경(px). 파티원이 이 안에 있으면 점유로 본다.
#
# 기본값 140 의 근거: 파티가 셋이 함께 서 있을 수 있고(아군 AI 대열 폭), 강지 지대(200)보다
# 작아 "지대를 겹쳐 깔면 이득"이 남는 크기다. [임시값].
@export var radius: float = 140.0

# 이 존만의 확보 시간(초). **0 이면 CombatTuning.capture_hold_seconds 를 따른다.**
#
# 존마다 다르게 하고 싶을 때만 저작한다 — 기본은 게임 공통 값 하나여야 한다.
@export var hold_seconds: float = 0.0


# 실제로 쓸 확보 시간. 저작값이 없으면 공통 튜닝을 따른다.
#
# CombatConfig 를 **전역 식별자로 쓰지 않는다**: 리소스 스크립트는 autoload 가 등록되기 전에
# 컴파일될 수 있어 "Identifier not found: CombatConfig" 로 깨진다(실제로 그렇게 깨졌다).
# 그러면 이 정의를 담은 .tres 가 통째로 로드되지 않아 스테이지까지 사라진다.
# PlayerStats.get_tuning() 이 같은 이유로 이미 런타임 조회 + 폴백을 갖고 있으므로 그것을 쓴다.
func get_hold_seconds() -> float:
	if hold_seconds > 0.0:
		return hold_seconds
	return PlayerStats.get_tuning().capture_hold_seconds


# ===== 무결성 점검 (Validation) =====
# StageSpawn / EnemyData 와 같은 규약. 문제 메시지 배열을 반환한다.
func validate() -> Array[String]:
	var problems: Array[String] = []
	# 반경이 0 이면 아무도 안에 들어갈 수 없어 그 스테이지는 클리어 불가가 된다.
	if radius <= 0.0:
		problems.append("radius는 0보다 커야 합니다: %.1f" % radius)
	# 음수는 저작 실수다. 0 은 "공통 튜닝을 따른다"는 뜻이라 유효하다.
	if hold_seconds < 0.0:
		problems.append("hold_seconds는 0 이상이어야 합니다(0 = 공통 튜닝): %.1f" % hold_seconds)
	return problems

extends Resource
class_name StageData

# 스테이지의 단일 정의 출처 (data definition).
#
# 담는 것은 docs/combat-screen-design.md §5 의 [확정] 사항뿐이다:
#   - 스테이지 타입 3종 (전투 / 점령 / 점령+전투)
#   - 승리 조건 프리미티브 2종 (소탕 / 점령)
#
# CharacterData / EnemyData / EquipmentData 와 같은 규약을 따른다:
#   식별 필드 + @export, validate(), 그리고 전용 레지스트리(StageDatabase)로 조회.
#
# 실제 스테이지는 data/stages/*.tres 로 저작하고 StageDatabase 가 로드한다.
# 이 파일은 스키마만 정의한다.
#
# 참고: docs/combat-screen-design.md §5, SYSTEM_CONVENTIONS.md

# ===== 승리 조건 프리미티브 (Objective primitives) — §5.1 [확정] =====
# 승리 조건은 이 두 가지의 조합으로만 구성된다.
enum Objective {
	CLEAR,    # 소탕 — 방어 병력을 전멸시킨다
	CAPTURE,  # 점령 — 거점 존에 들어가 일정 시간 확보한다
}

# ===== 스테이지 타입 (Type) — §5.2 [확정] =====
# 타입이 곧 승리 조건 조합이다. 아래 표(§5.2)가 정본이다.
#   전투      -> 소탕만
#   점령      -> 점령만
#   점령+전투 -> 소탕 + 점령 둘 다
enum Type {
	BATTLE,             # 전투
	CAPTURE,            # 점령
	CAPTURE_AND_BATTLE, # 점령+전투
}

# ===== 식별 (Identity) =====
@export var stage_id: StringName = &""   # 고유 식별자 (예: &"stage_1_1")
@export var display_name: String = ""     # 화면 표시 이름
@export_multiline var description: String = ""

# ===== 승리 조건 (Victory) =====
# 기본값 BATTLE: 첫 값을 기본으로 두어 누락된 .tres 도 안전하게 로드된다.
@export var type: Type = Type.BATTLE

# ----- 여기에 없는 것과 그 이유 (Extensibility) -----
# 아래는 설계 문서에서 아직 [미정] 이므로 **필드를 만들지 않았다.**
# 임의의 기본값을 넣으면 나중에 밸런스를 정할 때 그 값이 근거처럼 남는다.
#
#   - 존 확보 시간, 존 위치, 리스폰 규칙 (§5.2 [미정])
#   - "점령+전투" 에서 두 프리미티브를 순차/동시/보완 중 무엇으로 엮을지 (§5.2 [미정])
#   - 잠입/전투 루트 선택의 실제 파라미터 (§7 [미정], 전투 화면 작업 범위 밖)
#   - 적 배치·웨이브 규칙, 보상 테이블
#
# 정해지면 위 "승리 조건" 절에 @export 필드를 **기본값과 함께** 추가한다.
# 기본값이 있으면 기존 .tres 는 누락 필드를 기본값으로 로드하므로 호환이 유지된다.


# ===== 승리 조건 조회 (Victory accessors) =====
# 프리미티브를 .tres 에 따로 저작하지 않고 타입에서 도출한다.
# 둘을 각각 저작하면 "전투인데 점령이 필요"처럼 서로 어긋나는 데이터가 만들어질 수 있다.
# §5.2 가 타입->조건 대응을 [확정] 했으므로 타입 하나가 출처다.

# 이 스테이지의 승리에 필요한 프리미티브 전부.
func get_objectives() -> Array[Objective]:
	match type:
		Type.BATTLE:
			return [Objective.CLEAR]
		Type.CAPTURE:
			return [Objective.CAPTURE]
		Type.CAPTURE_AND_BATTLE:
			return [Objective.CLEAR, Objective.CAPTURE]
		_:
			return []


# 특정 프리미티브가 승리에 필요한가.
func requires(objective: Objective) -> bool:
	return get_objectives().has(objective)


# 편의 조회. 화면·전투 코드가 enum 을 직접 비교하지 않도록 한다.
func requires_clear() -> bool:
	return requires(Objective.CLEAR)


func requires_capture() -> bool:
	return requires(Objective.CAPTURE)


# ===== 표시 이름 (Display names) =====
# 한글 표시 이름의 단일 출처. 화면에서 문자열을 다시 적지 않는다.

func get_type_name() -> String:
	return type_to_name(type)


static func type_to_name(t: Type) -> String:
	match t:
		Type.BATTLE:
			return "전투"
		Type.CAPTURE:
			return "점령"
		Type.CAPTURE_AND_BATTLE:
			return "점령+전투"
		_:
			return "알 수 없음"


static func objective_to_name(o: Objective) -> String:
	match o:
		Objective.CLEAR:
			return "소탕"
		Objective.CAPTURE:
			return "점령"
		_:
			return "알 수 없음"


# 승리 조건을 화면 표시용 한 줄로. 예: "소탕 + 점령"
func get_objectives_display_name() -> String:
	var names: Array[String] = []
	for o in get_objectives():
		names.append(objective_to_name(o))
	return " + ".join(names)


# ===== 무결성 점검 (Validation) =====
# CharacterData / EnemyData / EquipmentData 의 validate() 와 같은 규약.
# 문제 메시지 배열을 반환한다. 비어 있으면 정상이다.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(stage_id).is_empty():
		problems.append("stage_id가 비어 있습니다.")
	if display_name.is_empty():
		problems.append("display_name이 비어 있습니다.")
	# 타입이 enum 밖이면 승리 조건을 도출할 수 없다(저작 실수로 클리어 불가 스테이지가 된다).
	if get_objectives().is_empty():
		problems.append("type이 알 수 없는 값입니다: %d" % type)
	return problems

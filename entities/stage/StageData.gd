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

# ===== 챕터와 컨셉 (Chapter & Concept) — #408 =====
#
# 스테이지 전체 규모는 **3챕터 x 3스테이지 = 9스테이지**로 확정되어 있다.
# 챕터 하나가 컨셉 하나를 갖는다: 1챕터 육지 / 2챕터 바다 / 3챕터 하늘.
#
# 왜 컨셉이 @export 필드가 아닌가: 챕터가 컨셉을 **결정한다.** 둘을 각각 저작하게 두면
# "2챕터인데 육지"처럼 서로 어긋나는 데이터가 만들어질 수 있다 —
# 승리 조건을 type 에서 도출한 것(아래 "승리 조건 조회")과 같은 이유다. 챕터가 출처다.
#
# 왜 stage_id 에서 파싱하지 않는가: id 는 식별자일 뿐 형식을 약속한 적이 없다.
# &"stage_test" 처럼 챕터에 속하지 않는 id 가 이미 있고, 파싱은 그런 id 를 만나면
# 조용히 0 이나 엉뚱한 값을 내놓는다. 번호는 저작된 값이어야 한다.

# 챕터에 속하지 않는 스테이지를 뜻하는 값. 테스트·연습 스테이지가 이 값을 쓴다.
#
# 기본값으로 둔 이유: 이 필드가 없는 기존 .tres(stage_test.tres)는 누락 필드를
# 기본값으로 로드한다. 기본값이 1 이면 테스트 스테이지가 조용히 1챕터에 끼어든다.
const NO_CHAPTER := 0

# 챕터 수와 챕터당 스테이지 수. 저작 실수를 validate() 가 잡는 근거다.
const CHAPTER_COUNT := 3
const STAGES_PER_CHAPTER := 3

# 컨셉 3종. 챕터에서 도출되며 저작 대상이 아니다.
enum Concept {
	LAND,  # 육지
	SEA,   # 바다
	SKY,   # 하늘
}

# 이 스테이지가 속한 챕터 (1..CHAPTER_COUNT). NO_CHAPTER 면 챕터 밖이다.
@export_range(0, CHAPTER_COUNT) var chapter: int = NO_CHAPTER

# 챕터 안에서의 순번 (1..STAGES_PER_CHAPTER). 표시 번호("1-2")와 목록 정렬에 쓴다.
# 챕터가 NO_CHAPTER 면 이 값은 쓰이지 않는다.
@export_range(0, STAGES_PER_CHAPTER) var number: int = 0

# ===== 승리 조건 (Victory) =====
# 기본값 BATTLE: 첫 값을 기본으로 두어 누락된 .tres 도 안전하게 로드된다.
@export var type: Type = Type.BATTLE

# ===== 적 배치 (Spawns) =====
# 이 스테이지에 놓이는 적. 한 줄이 StageSpawn 하나다(무엇을/어디에/몇 마리).
#
# 왜 데이터인가: 배치가 스크립트에 박혀 있으면 스테이지를 하나 더 만들 때마다
# 코드를 고쳐야 하고, 저작된 .tres 를 골라도 화면이 달라지지 않는다.
# §5 는 승리 조건이 "스테이지별로 달라진다(데이터 기반)"고 [확정] 했고,
# 배치는 그 조건이 걸리는 대상이다.
#
# 비어 있어도 유효하다 — 적 없이 점령만 하는 스테이지가 가능하다.
@export var spawns: Array[StageSpawn] = []

# ===== 웨이브 (Waves) — #375 =====
#
# 순서대로 나오는 적 무리. 한 웨이브를 전멸시키면 다음 웨이브가 놓인다.
#
# 왜 spawns 와 따로인가: spawns 는 **시작 시 한 번에** 놓는 배치라는 뜻이 이미 굳어 있다.
# 거기에 순서를 얹으면 한 필드가 두 가지를 뜻하게 되고, 웨이브를 쓰지 않는 기존
# 스테이지(1-1)의 동작이 조용히 달라진다.
#
# 둘 다 있으면 **spawns 를 먼저 놓고, 그것을 전멸시킨 뒤 웨이브가 시작된다.**
# 비어 있으면 웨이브 없는 스테이지다 — 지금까지 저작된 .tres 는 이 필드가 없어 그대로 동작한다.
@export var waves: Array[StageWave] = []


# ===== 강제 파티 (Forced party) — #345 =====
#
# 이 스테이지에서 **플레이어 편성을 덮어쓸** 파티. 비어 있으면(기본값) 플레이어가 편성한
# 파티를 그대로 쓴다 — 지금까지 저작된 .tres 는 이 필드가 없어 그대로 동작한다.
#
# 왜 필요한가: 튜토리얼 스테이지(1-1)는 **가르치는 내용이 화면에서 실제로 일어나야** 한다.
# 시너지 체인(표식 -> 기절 -> 처형)을 설명하려면 세 역할이 각 1카운트인 파티여야 하고
# (설계 §8.2 — 순혈 3인 조합 하나뿐이다), 플레이어가 겸직 3명으로 들어오면
# 시너지가 하나도 켜지지 않아 안내가 거짓말이 된다.
#
# 왜 id 만 담는가: 캐릭터 정의의 출처는 CharacterDatabase 다(SYSTEM_CONVENTIONS 기초 시스템).
# 여기에 스텟·역할을 적으면 같은 데이터가 두 곳에 생긴다.
@export var forced_party: Array[StringName] = []

# ===== 거점 존 (Capture zones) — #377 =====
#
# 점령(§5.1)이 걸리는 자리. 한 줄이 존 하나이며 **전부 확보해야** 점령 목표가 충족된다.
#
# 왜 spawns 와 나누는가: 배치는 "적을 어디에 몇 마리", 존은 "어디를 얼마나 오래 지키는가"다.
# 둘을 한 배열에 섞으면 타입 검사로만 구별되고, 점령이 없는 스테이지에도 빈 자리가 생긴다.
#
# 비어 있는 것이 정상이다 — 전투(소탕) 타입 스테이지는 존을 갖지 않는다.
@export var capture_zones: Array[CaptureZoneData] = []

# ===== 보상 (Rewards) =====
# 클리어 보상. 재화 id(String) -> 수량(int).
# 키는 CurrencySystem.DEFAULT_CURRENCIES 의 재화 id 를 참조한다(단일 출처).
# EquipmentData.craft_cost 와 같은 규약이다.
#
# 비어 있으면 보상 없는 스테이지다(연습·튜토리얼 등).
# 지급은 StageProgress 가 CurrencySystem 을 통해 한다 — 여기는 정의만 담는다.
#
# 수치는 [임시값]이다. 밸런스(획득 속도 대비 제작 비용)는 별도 작업이다.
# 성장 재료인 프로틴도 재화이므로 여기에 함께 적는다 (예: {"gold": 40, "protein": 50}).
# #192 에서는 clear_protein 이라는 별도 필드였으나, #204 에서 프로틴이 재화가 되면서
# 보상 정의가 이 하나로 합쳐졌다.
@export var clear_rewards: Dictionary = {}


# ----- 여기에 없는 것과 그 이유 (Extensibility) -----
# 아래는 설계 문서에서 아직 [미정] 이므로 **필드를 만들지 않았다.**
# 임의의 기본값을 넣으면 나중에 밸런스를 정할 때 그 값이 근거처럼 남는다.
#
#   - 존 확보 시간, 존 위치, 리스폰 규칙 (§5.2 [미정])
#   - **시간차 스폰**(N초 뒤 등장): 웨이브 방아쇠는 "앞 웨이브 전멸"(#375)과
#     점령(StageWave.requires_capture, #442)뿐이다
#   - 첫 클리어 보너스·별점·드랍 테이블: 보상 규칙이 아직 clear_rewards 하나뿐이다
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


# ===== 챕터 조회 (Chapter accessors) — #408 =====
# 승리 조건과 같은 규약: 컨셉을 .tres 에 저작하지 않고 챕터에서 도출한다.

# 이 스테이지가 챕터에 속하는가. 테스트·연습 스테이지는 false 다.
func has_chapter() -> bool:
	return chapter != NO_CHAPTER


# 이 스테이지의 컨셉. 챕터 밖이면 -1 (Concept 값이 아니다 — 호출부는 has_chapter() 를 먼저 본다).
func get_concept() -> int:
	return chapter_to_concept(chapter)


# 챕터 -> 컨셉. 대응표의 정본이다. 화면·전투 코드가 이 대응을 다시 쓰지 않는다.
# 챕터 밖(NO_CHAPTER 포함)이면 -1.
static func chapter_to_concept(c: int) -> int:
	match c:
		1:
			return Concept.LAND
		2:
			return Concept.SEA
		3:
			return Concept.SKY
		_:
			return -1


# 목록 정렬 기준. 챕터 없는 스테이지는 맨 끝으로 간다(테스트 스테이지가 1챕터 사이에 끼지 않도록).
# 값 자체에 뜻은 없다 — 크기 비교에만 쓴다.
func get_sort_key() -> int:
	if not has_chapter():
		return (CHAPTER_COUNT + 1) * 100 + number
	return chapter * 100 + number


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


# 컨셉의 한글 이름. 챕터 밖(-1)이면 "알 수 없음".
static func concept_to_name(c: int) -> String:
	match c:
		Concept.LAND:
			return "육지"
		Concept.SEA:
			return "바다"
		Concept.SKY:
			return "하늘"
		_:
			return "알 수 없음"


func get_concept_name() -> String:
	return concept_to_name(get_concept())


# 챕터 머리에 쓰는 한 줄. 예: "2챕터 · 바다"
static func chapter_to_display_name(c: int) -> String:
	if c == NO_CHAPTER:
		return "챕터 밖"
	return "%d챕터 · %s" % [c, concept_to_name(chapter_to_concept(c))]


# 스테이지 표시 번호. 예: "1-2". 챕터 밖이면 빈 문자열이다
# (display_name 에 번호가 없는 stage_test 에 "0-0" 을 붙이지 않는다).
func get_stage_number_text() -> String:
	if not has_chapter():
		return ""
	return "%d-%d" % [chapter, number]


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

	# 챕터·번호(#408). 범위 밖이면 목록에서 자리를 잃거나 표시 번호가 거짓이 된다.
	# NO_CHAPTER 는 유효하다 -- 테스트·연습 스테이지가 챕터에 속하지 않는 것은 정상이다.
	if chapter != NO_CHAPTER:
		if chapter < 1 or chapter > CHAPTER_COUNT:
			problems.append("chapter는 1..%d 또는 %d(챕터 밖)여야 합니다: %d"
				% [CHAPTER_COUNT, NO_CHAPTER, chapter])
		if number < 1 or number > STAGES_PER_CHAPTER:
			problems.append("챕터에 속한 스테이지의 number는 1..%d 여야 합니다: %d"
				% [STAGES_PER_CHAPTER, number])
	elif number != 0:
		# 챕터가 없는데 번호가 있으면 어느 쪽이 저작 실수인지 알 수 없다.
		problems.append("chapter가 %d(챕터 밖)인데 number가 저작되어 있습니다: %d"
			% [NO_CHAPTER, number])

	# 배치 한 줄이 잘못되면 그 적만 조용히 빠진다. 저작 시점에 드러나야 한다.
	for i in range(spawns.size()):
		var spawn := spawns[i]
		if spawn == null:
			problems.append("spawns[%d]가 비어 있습니다." % i)
			continue
		for problem in spawn.validate():
			problems.append("spawns[%d]: %s" % [i, problem])

	# 웨이브도 같은 이유로 저작 시점에 검사한다. 빈 웨이브는 즉시 넘어가 버려
	# "적이 안 나온다"로만 보이고 원인이 드러나지 않는다.
	for i in range(waves.size()):
		var wave := waves[i]
		if wave == null:
			problems.append("waves[%d]가 비어 있습니다." % i)
			continue
		for problem in wave.validate():
			problems.append("waves[%d]: %s" % [i, problem])

		# 점령 조건 웨이브(#442)의 저작 실수 둘. 둘 다 **판이 영영 끝나지 않는**
		# 교착 상태를 만들고, 플레이어에게는 원인이 전혀 보이지 않는다.
		if wave.requires_capture:
			# ① 존이 없으면 Stage._all_zones_captured() 가 항상 false 라 이 웨이브가
			#    영원히 놓이지 않는다. 적이 없으니 소탕도 충족되지 않는다.
			if not requires_capture():
				problems.append(
					"waves[%d]: requires_capture 인데 이 스테이지는 점령을 요구하지 않습니다(type=%s)."
						% [i, get_type_name()])
			# ② spawns 가 비어 있으면 진입 시 _advance_wave() 가 **게이트를 거치지 않고**
			#    첫 웨이브를 놓는다. 거기에 게이트를 넣으면 적이 하나도 놓이지 않아
			#    _begin_judging() 이 판정을 꺼 버린다. 그래서 이 조합 자체를 막는다.
			#    (spawns 가 있으면 첫 웨이브 게이트는 정상이다 — 시작 배치를 치우고
			#     점령한 뒤 1파가 온다.)
			if i == 0 and spawns.is_empty():
				problems.append(
					"waves[0]: spawns 가 비어 있는데 requires_capture 입니다 — 진입 시 놓을 적이 없습니다.")

	# 소탕이 조건인데 놓을 적이 아무 데도 없으면 진입하자마자 승리가 된다.
	if requires_clear() and spawns.is_empty() and waves.is_empty():
		problems.append("소탕 스테이지인데 spawns 도 waves 도 비어 있습니다.")

	# 보상 키/수량 검증. 잘못된 값은 지급 시점이 아니라 저작 시점에 드러나야 한다.
	for key in clear_rewards:
		if typeof(clear_rewards[key]) != TYPE_INT or int(clear_rewards[key]) < 0:
			problems.append("clear_rewards['%s']는 0 이상의 정수여야 합니다." % str(key))
		elif not CurrencySystem.DEFAULT_CURRENCIES.has(str(key)):
			problems.append("clear_rewards['%s']는 알 수 없는 재화입니다." % str(key))

	# 점령 존(#377). 소탕과 같은 이유로 양쪽을 다 잡는다 —
	# 존이 없으면 클리어 불가이고, 필요 없는데 저작돼 있으면 화면에 존이 뜨는데 아무 의미가 없다.
	if requires_capture() and capture_zones.is_empty():
		problems.append("점령이 필요한 스테이지인데 capture_zones가 비어 있습니다.")
	if not requires_capture() and not capture_zones.is_empty():
		problems.append("점령이 필요하지 않은데 capture_zones가 저작되어 있습니다(%d개)."
			% capture_zones.size())
	for i in range(capture_zones.size()):
		var zone := capture_zones[i]
		if zone == null:
			problems.append("capture_zones[%d]가 비어 있습니다." % i)
			continue
		for problem in zone.validate():
			problems.append("capture_zones[%d]: %s" % [i, problem])

	# 강제 파티(#345). 편성이 거부되면 그 스테이지는 파티 없이 열려 아무것도 못 한다.
	# 캐릭터 정의·편성 가능 여부의 출처는 CharacterDatabase 이므로 그쪽에 묻는다.
	#
	# 정원(PartySystem.PARTY_SIZE)은 여기서 보지 않는다: StageDatabase 가 PartySystem 보다
	# 먼저 초기화되므로(project.godot autoload 순서) 로드 시점에 그 시스템이 아직 없다.
	# 정원 초과는 PartySystem.set_party() 가 거부하며 경고를 남긴다.
	var seen_members := {}
	for id in forced_party:
		if seen_members.has(id):
			problems.append("forced_party에 중복 캐릭터가 있습니다: " + String(id))
		seen_members[id] = true
		if not CharacterDatabase.has_character(id):
			problems.append("forced_party의 알 수 없는 character_id: " + String(id))
			continue
		var member := CharacterDatabase.get_character(id)
		if member != null and not member.playable:
			problems.append("forced_party에 편성할 수 없는 캐릭터가 있습니다: " + String(id))

	return problems

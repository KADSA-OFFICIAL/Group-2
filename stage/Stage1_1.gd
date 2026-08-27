extends Node2D
class_name Stage

# 거점 존 씬(#377). 무엇을 어디에 놓을지는 데이터가 정하고 씬은 하나뿐이라 여기서 preload 한다.
const CAPTURE_ZONE_SCENE := preload("res://entities/stage/CaptureZone.tscn")

# ===== 파티 시작 자리 (#448) =====
#
# 세 스테이지(1-1·1-2·1-3)가 공유하는 유일한 파티 스폰이다.
#
# **왜 상수로 꺼냈는가**: 좌표가 spawn_party() 안에 박혀 있는 동안 이 자리가
# 프롭 충돌과 겹치는지 아무 데서도 검사되지 않았고, 실제로 3번째 멤버가 초원
# 울타리 충돌 안에 스폰됐다(실측: FenceLeft1 사각형 [(42,168) 96x24] 안).
# 게다가 같은 좌표를 검증 두 곳이 손으로 베껴 갖고 있어, 스폰이 바뀌면 조용히 낡았다.
# 이제 검증이 여기서 derive 한다.
#
# **왜 y=50 에서 시작하는가**: 초원의 울타리 띠가 스테이지 좌표로 y 168..192 / x 42..330
# 이 이어져 있다(울타리 셋이 x 42..138 / 138..234 / 234..330). 통로는 x 330..450 뿐이라
# **y=180 에서는 좌우로 옮겨도 여전히 울타리 안**이고, 세로로 올리는 것이 유일한 답이다.
# 마지막 멤버가 y=130 이고 플레이어 캡슐이 중심에서 ±15 이므로 몸이 y 115..145 —
# 울타리 위쪽(168)까지 23px 여유가 남는다.
#
# 아래(남)로 내리면 파티가 통로를 지나지 않고 시작하는데, 그것은 세 스테이지의
# 여는 그림을 바꾸는 디자인 변경이라 이 자리에서 정할 일이 아니다.
const PARTY_SPAWN_ORIGIN := Vector2(100, 50)

# 멤버마다 더해지는 간격. 겹치지 않게 세로로 세운다.
const PARTY_SPAWN_STEP := Vector2(0, 40)


# index 번째(0부터) 파티원이 놓이는 자리. 검증도 이 함수를 쓴다.
static func get_party_spawn_position(index: int) -> Vector2:
	return PARTY_SPAWN_ORIGIN + PARTY_SPAWN_STEP * index


# 전장을 찾는 그룹 (#444). HUD 가 CaptureZone.GROUP 으로 존을 찾는 것과 같은 방식이다.
#
# 왜 필요한가: 이 노드의 이름은 stage_name 을 따라 **동적으로 바뀌므로** 노드 경로로
# 찾을 수 없고, GameManager 도 전장을 들고 있지 않다.
const GROUP := &"stage"

# 씬 트리 노드 이름이자 stage_started/completed 에 실리는 값.
# 어떤 스테이지가 로드됐는지 드러나야 하므로 현재 스테이지 id 를 따른다.
var stage_name: String = "Stage"
var current_room: Node = null

# 전장 맵 노드의 이름. 컨셉마다 다른 씬이 들어오므로 이름은 씬과 무관하게 고정한다
# ("GrasslandMap" 이라는 이름이 바다 맵에 붙어 있으면 트리를 읽을 수 없다).
const MAP_NODE_NAME := "StageMap"

# 지금 놓여 있는 맵의 씬 경로. 같은 맵으로 다시 진입할 때 재생성을 건너뛰는 판단에 쓴다.
var _map_scene_path: String = ""


func _ready():
	add_to_group(GROUP)
	StageSystem.stage_requested.connect(_on_stage_requested)
	_enter_current_stage()


# 출격 화면에서 다른 스테이지를 고르면 그 배치로 다시 만든다.
func _on_stage_requested(_stage_id: StringName) -> void:
	_enter_current_stage()


func _enter_current_stage() -> void:
	var stage := StageSystem.get_current_stage()
	stage_name = String(StageSystem.get_current_id()) if stage != null else "Stage"
	name = stage_name
	_place_map(stage)
	EventBus.stage_started.emit(stage_name)
	load_room()

# 이 스테이지의 컨셉에 맞는 전장 맵을 놓는다 (#420).
#
# 맵은 여태 stage/Stage1_1.tscn 에 GrasslandMap 인스턴스로 박혀 있었다. 그래서 어떤
# 스테이지로 출격해도 초원이었다 -- 컨셉(#408)이 이름만 바꾸고 화면은 바꾸지 않았다.
#
# 컨셉->씬 대응은 StageMaps 가 안다. 여기에 경로를 적지 않는다.
func _place_map(stage: StageData) -> void:
	var path := StageMaps.resolve_for_stage(stage)
	var existing := get_node_or_null(MAP_NODE_NAME)

	# 같은 맵이면 다시 만들지 않는다. 초원은 96x64 = 6144 셀을 코드로 깔기 때문에
	# 1-1 -> 1-2 처럼 컨셉이 같은 스테이지로 갈아탈 때마다 다시 생성하면 진입이 눈에 띄게 멈춘다.
	if existing != null and path == _map_scene_path:
		return

	# 트리에서 **즉시** 떼어낸다. queue_free 는 프레임 끝에 실제로 지우므로,
	# 그때까지 남겨 두면 이름이 겹쳐 새 맵이 "StageMap2" 로 들어간다
	# (load_room() 이 예전에 겪은 것과 같은 함정이다).
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	_map_scene_path = ""

	var scene := load(path) as PackedScene
	if scene == null:
		# 전장이 맵 없이 열린다. 파티·적은 그대로 놓이므로 판은 돌아간다.
		push_warning("Stage: 맵 씬을 불러올 수 없습니다: " + path)
		return

	var map := scene.instantiate() as Node2D
	if map == null:
		push_warning("Stage: 맵 씬의 루트가 Node2D 가 아닙니다: " + path)
		return

	map.name = MAP_NODE_NAME
	map.position = StageMaps.MAP_OFFSET
	add_child(map)
	# 첫 자식으로 옮긴다 -- 파티·적(Room1)보다 먼저 그려져야 바닥이 된다.
	move_child(map, 0)
	_map_scene_path = path

# 방을 새로 만들고 파티와 적을 놓는다. 다시 부르면 이전 방을 통째로 버린다.
#
# 예전 코드는 current_room 을 queue_free 한 **뒤에 같은 노드를 다시 찾아** 거기에
# 스폰했다. queue_free 는 프레임 끝에 실제로 지우므로, 새로 놓은 파티·적이
# 그 방과 함께 사라졌다(다시 로드하면 전장이 텅 비었다).
# 진입이 한 번뿐일 때는 드러나지 않던 버그다.
func load_room() -> void:
	var previous := get_node_or_null("Room1")
	if previous != null:
		# 트리에서 즉시 떼어낸다. 프레임 끝까지 남겨 두면 이름이 겹치고
		# 적 등록 해제(EnemyBase._exit_tree)도 늦는다.
		remove_child(previous)
		previous.queue_free()

	current_room = Node2D.new()
	current_room.name = "Room1"
	add_child(current_room)

	spawn_party()
	spawn_enemies()
	spawn_capture_zones()

	# 적이 놓인 뒤에 판정을 켠다. 순서가 바뀌면 진입하자마자 승리가 된다.
	_begin_judging()

# 파티가 비어 있고 **스테이지가 강제 파티를 저작하지 않았을 때** 쓰는 기본 편성.
#
# 1-1 은 더 이상 이 값을 쓰지 않는다(#345): StageData.forced_party 로 순혈 3인
# (미나·태희·설아)을 강제한다. 아래 [알려진 문제] 는 강제 파티가 없는 스테이지에
# 그대로 남아 있다 — 기본 편성의 구성을 바꾸는 것은 여전히 별 이슈다.
#
# 역할 카운트는 **탱커 0 / 원거리 2 / 버퍼 2** 다 — 강지가 버퍼+원거리 겸직이고
# 태희가 순혈 원거리, 설아가 순혈 버퍼이기 때문이다.
#
# **[알려진 문제] 이 편성에서는 시너지가 하나도 켜지지 않는다.** 2카운트가 죽은 구간이고
# (docs §8.1) 탱커는 0 이라, 표식·기절·평타 스택·처형이 전부 동작하지 않는다.
# §8.2 가 세어 둔 "시너지가 하나도 켜지지 않는 파티 20개 중 4개" 가운데 하나다.
#
# 어쩌다 이렇게 됐는가: 이 자리를 들고 있던 shipduck 이 #328 에서 겸직 탱커/버퍼 ->
# 버퍼/원거리로 옮겨 갔고(하랑과 슬롯 맞바꿈), 그때 탱커 카운트가 사라졌다.
# 그 전에는 탱커 1 / 원거리 1 / 버퍼 2 로 탱커·원거리 1단계가 켜져 있었다.
#
# 여기서 고치지 않은 이유: 기본 편성의 **구성**을 정하는 것은 밸런스·설계 판단이고
# 이 이슈(#334, 강지 재제작)의 범위가 아니다. 별 이슈로 다룬다.
# 고치려면 탱커를 넣으면 된다 — 예: 하랑(탱커/버퍼)을 넣으면 #328 이전과 같은 1/1/2 가 되고,
# 미나(순혈 탱커)를 넣으면 순혈 3명이 되어 세 역할 1단계가 모두 켜진다.
#
# 원거리 자리는 #263 에서 순혈 원거리 슬롯을 이어받은 taehee 다(플레이스홀더 ranged_pure 대체).
# 버퍼 자리는 #276 에서 순혈 버퍼 슬롯을 이어받은 seola 다(플레이스홀더 buffer_pure 대체).
# 첫 자리는 #334 에서 shipduck 을 다시 만든 gangji(강지)다.
# (편성 UI가 생기면 이 기본값 대신 플레이어 선택을 쓴다.)
const DEFAULT_PARTY := [&"gangji", &"taehee", &"seola"]

# 파티 멤버를 스폰한다.
# 캐릭터 정의는 PartySystem(-> CharacterDatabase)이 출처이며 여기서 재정의하지 않는다.
# 조종 여부도 PartySystem이 정하므로 노드에는 party_index만 넘긴다.
func spawn_party():
	# 강제 파티가 저작된 스테이지는 **플레이어 편성을 덮어쓴다**(#345).
	# 튜토리얼 스테이지(1-1)가 이것을 쓴다 — 가르치는 시너지 체인이 실제로 켜져 있어야
	# 안내가 화면과 맞는다(설계 §8.2: 세 역할이 모두 켜지는 파티는 순혈 3인뿐이다).
	# 강제 대상의 유효성(존재·편성 가능·중복)은 PartySystem 이 판정한다.
	var stage := StageSystem.get_current_stage()
	if stage != null and not stage.forced_party.is_empty():
		PartySystem.set_party(stage.forced_party)
	elif PartySystem.is_empty():
		PartySystem.set_party(DEFAULT_PARTY)

	_party_spawned = 0

	var member_scene = load("res://entities/player/Player.tscn")
	if member_scene == null:
		push_warning("Stage: Player.tscn을 불러올 수 없습니다.")
		return

	var members = PartySystem.get_members()
	_party_spawned = members.size()
	for i in range(members.size()):
		var node = member_scene.instantiate()
		node.data = members[i]
		node.party_index = i
		current_room.add_child(node)
		node.global_position = get_party_spawn_position(i)

# 적을 배치한다. 무엇을 어디에 몇 마리 놓을지는 **StageData.spawns** 가 정한다.
#
# 예전에는 씬 경로 상수 3개와 좌표가 이 파일에 박혀 있었다. 그래서 스테이지를
# 저작해도 화면이 달라지지 않았고, 새 배치를 만들려면 코드를 고쳐야 했다.
func spawn_enemies() -> void:
	var stage := StageSystem.get_current_stage()
	if stage == null:
		# 저작된 스테이지가 없어도 전장은 열린다(파티만 놓인다).
		push_warning("Stage: 현재 스테이지 정의가 없습니다. 적 없이 시작합니다.")
		return

	_wave_index = -1
	var placed := _place(stage.spawns)

	# spawns 가 비었고 웨이브만 저작된 스테이지는 첫 웨이브를 바로 놓는다.
	# 놓지 않으면 _begin_judging 이 "적이 없다"며 판정을 꺼서 영영 끝나지 않는다.
	if placed == 0:
		_advance_wave()


# ===== 웨이브 (Waves) — #375 =====
#
# 지금 놓여 있는 웨이브 번호. -1 은 **StageData.spawns**(웨이브 이전의 시작 배치)다.
# 전멸할 때마다 하나씩 올라가고, 마지막 웨이브까지 전멸시켜야 승리다.
#
# 왜 "마지막 웨이브 == 보스" 로 두지 않는가: 보스 뒤에 잔당 웨이브를 붙이는 순간 깨진다.
# 보스 여부는 StageWave.is_boss 가 따로 들고 있고, 승리 조건은 그것과 무관하다.
var _wave_index: int = -1


# 적 배치 한 묶음을 방에 놓는다. 실제로 놓은 마리 수를 돌려준다.
func _place(spawns: Array[StageSpawn]) -> int:
	var placed := 0
	for spawn in spawns:
		if spawn == null or spawn.enemy_scene == null:
			continue
		for i in range(spawn.count):
			var enemy = spawn.enemy_scene.instantiate()
			current_room.add_child(enemy)
			enemy.global_position = spawn.get_position(i)
			placed += 1
	return placed


# 다음 웨이브를 놓는다. 놓을 것이 남아 있지 않으면 false — 그때가 소탕 완료다.
#
# 비어 있는 웨이브는 **건너뛴다**(멈추지 않는다). 거기서 멈추면 적도 없고 승리도 없어
# 판이 영영 끝나지 않고, 플레이어에게는 원인이 전혀 보이지 않는다.
# 저작 시점에는 StageData.validate() 가 이미 걸러 준다 — 여기는 그 그물을 빠져나온
# 경우(씬 로드 실패 등)를 위한 마지막 방어선이다.
func _advance_wave() -> bool:
	var stage := StageSystem.get_current_stage()
	if stage == null:
		return false

	while _wave_index + 1 < stage.waves.size():
		_wave_index += 1
		var wave := stage.waves[_wave_index]
		if wave == null:
			push_warning("Stage: waves[%d]가 비어 있습니다(건너뜀): %s" % [_wave_index, stage_name])
			continue

		if _place(wave.spawns) == 0:
			push_warning("Stage: waves[%d]에 놓인 적이 없습니다(건너뜀): %s" % [_wave_index, stage_name])
			continue

		EventBus.stage_wave_started.emit(stage_name, _wave_index, stage.waves.size(), wave)
		return true

	return false


# 거점 존을 놓는다(#377). 무엇을 어디에 놓을지는 **StageData.capture_zones** 가 정한다.
#
# 적 배치(spawn_enemies)와 같은 구조다: 코드에 좌표를 박지 않고 저작된 데이터를 읽는다.
# 존이 없는 스테이지(전투 타입)에서는 아무 일도 하지 않는다.
func spawn_capture_zones() -> void:
	var stage := StageSystem.get_current_stage()
	if stage == null:
		return

	for zone_data in stage.capture_zones:
		if zone_data == null:
			continue
		var zone = CAPTURE_ZONE_SCENE.instantiate()
		current_room.add_child(zone)
		zone.setup(zone_data)


# ===== 승패 판정 (Outcome) =====
#
# 승리 = 스테이지 타입이 요구하는 프리미티브를 **모두** 충족. 패배 = 파티 전멸.
# docs §5.1/§5.2 의 [확정] 사항이며, 무엇을 요구하는지는 StageData 가 답한다
# (requires_clear / requires_capture) — 여기서 타입을 다시 해석하지 않는다.
#
#   소탕  — 전장에 살아 있는 적이 없다.
#   점령  — 저작된 모든 거점 존이 확보됐다(#377). 존의 진행도는 CaptureZone 이 소유한다.
#
# 결과 화면을 여는 일은 여기서 하지 않는다. 전장은 화면을 모르고,
# EventBus 로 알리기만 한다(screens/result/stage_result_launcher.gd 가 받는다).

# 판정이 도는 중인가. 승패가 한 번 나면 꺼져서 같은 판을 두 번 끝내지 않는다.
var _judging: bool = false

# 이번 판에 놓인 파티 인원. 전멸 판정의 기준이다.
#
# 살아 있는 노드만 세면 전멸을 알 수 없다 — Player.die() 가 노드를 queue_free 해서
# 마지막 한 명이 죽는 순간 그룹이 비고, "아직 스폰 전"과 구별되지 않는다.
var _party_spawned: int = 0


func _process(_delta: float) -> void:
	if not _judging:
		return

	if _party_wiped():
		_finish(false)
		return

	# 소탕이 걸린 스테이지에서 적이 다 죽었다면, 승리를 판정하기 **전에** 다음 웨이브를 놓는다(#375).
	#
	# 왜 _objectives_met() 안에서 스폰하지 않는가: 그 함수는 "지금 조건이 충족됐는가"를 묻는
	# 질의다. 질의가 적을 스폰하면 부를 때마다 전장이 달라져서, 나중에 판정을 한 프레임에
	# 두 번 부르는 순간(디버그 표시·리플레이 등) 웨이브가 두 번 나온다.
	_advance_wave_if_cleared()

	if _objectives_met():
		_finish(true)


# 소탕이 조건이고 남은 적이 없을 때만 다음 웨이브를 놓는다.
#
# 점령 전용 스테이지에서는 아무것도 하지 않는다 — 적이 없는 것이 정상이라
# 여기서 웨이브를 밀면 점령하는 동안 저작하지도 않은 적이 계속 나온다.
func _advance_wave_if_cleared() -> void:
	var stage := StageSystem.get_current_stage()
	if stage == null or not stage.requires_clear():
		return
	if not GameManager.get_all_enemies().is_empty():
		return
	if not _next_wave_unlocked(stage):
		return
	_advance_wave()


# 다음 웨이브의 추가 조건이 채워졌는가 (#442).
#
# 지금 있는 조건은 StageWave.requires_capture 하나다 — 그 웨이브는 앞 무리 전멸에
# 더해 **모든 거점 존 확보**까지 채워져야 놓인다.
#
# 왜 _advance_wave() 안이 아니라 여기인가: _advance_wave() 는 진입 시
# spawn_enemies() 가 **직접** 부르는 경로에도 쓰인다(spawns 가 비었을 때).
# 거기에 게이트를 넣으면 진입 시 적이 하나도 놓이지 않고, 그러면
# _begin_judging() 이 "적이 없어 소탕을 판정하지 않습니다"로 판정을 꺼서
# 판이 영영 끝나지 않는다. 그래서 게이트는 **진행 경로에만** 둔다.
# (그 조합 자체는 StageData.validate() 가 저작 시점에 막는다.)
#
# 조건이 안 됐으면 그냥 기다린다. 전장에 적이 없고 점령 게이지만 차는 상태가 되며,
# 점령이 미완이므로 _objectives_met() 가 false 라 승리로 끝나지도 않는다.
# ===== 웨이브 조회 (Wave queries) — #444 =====
#
# HUD 가 부대 판을 그리는 데 쓴다. **신호(stage_wave_started)로는 부족하다**:
# main.tscn 에서 전장이 HUD 보다 먼저 _ready 를 돌아 1파 신호를 이미 쏘므로,
# HUD 는 그것을 놓친 채 시작한다(HUD._ready 의 튜토리얼 주석에 같은 문제가 적혀 있다).
# 그래서 상태를 물어볼 수 있게 열어 둔다 — HUD 는 매 프레임 조회하는 방식이다.

# 지금 놓여 있는 웨이브 번호(0부터). -1 은 StageData.spawns(웨이브 이전의 시작 배치)다.
func get_wave_index() -> int:
	return _wave_index


# 저작된 웨이브 수. 웨이브를 쓰지 않는 스테이지는 0 이다.
func get_wave_total() -> int:
	var stage := StageSystem.get_current_stage()
	return stage.waves.size() if stage != null else 0


# 다음 파가 점령 조건(#442)으로 막혀 기다리는 중인가.
#
# 왜 이 판단을 HUD 가 아니라 여기서 하는가: 조건이 셋(적이 없음 + 다음 파가
# requires_capture + 존 미확보)이고 _next_wave_unlocked() 가 이미 그 논리를 갖고 있다.
# HUD 에서 다시 조립하면 같은 규칙이 두 곳에 생겨, 한쪽만 고쳐지는 순간 화면과
# 실제 동작이 어긋난다.
func is_waiting_for_capture() -> bool:
	var stage := StageSystem.get_current_stage()
	if stage == null or not stage.requires_clear():
		return false
	if not GameManager.get_all_enemies().is_empty():
		return false
	# 놓을 웨이브가 남아 있는데 잠겨 있을 때만 "기다리는 중"이다.
	# 마지막 파까지 전멸시킨 상태는 대기가 아니라 소탕 완료다.
	if _wave_index + 1 >= stage.waves.size():
		return false
	return not _next_wave_unlocked(stage)


func _next_wave_unlocked(stage: StageData) -> bool:
	var next_index := _wave_index + 1
	if next_index >= stage.waves.size():
		return true
	var wave := stage.waves[next_index]
	if wave == null:
		# 비어 있는 웨이브는 _advance_wave() 가 건너뛴다. 여기서 막으면 그 건너뜀이
		# 일어나지 않아 판이 멈춘다.
		return true
	if wave.requires_capture and not _all_zones_captured():
		return false
	return true


# 이 스테이지가 요구하는 프리미티브가 모두 충족됐는가.
#
# 요구 목록의 출처는 StageData 다. 그래서 타입이 늘어도 이 함수는 그대로다.
func _objectives_met() -> bool:
	var stage := StageSystem.get_current_stage()
	if stage == null:
		return false

	# 소탕 조건은 진입 시 확인했다(_begin_judging). 여기서는 남은 적만 본다.
	if stage.requires_clear() and not GameManager.get_all_enemies().is_empty():
		return false

	# 점령(#377): 저작된 존을 **전부** 확보해야 한다.
	if stage.requires_capture() and not _all_zones_captured():
		return false

	return true


# 전장의 모든 거점 존이 확보됐는가. 존이 하나도 없으면 false 다 —
# 점령이 필요한 스테이지에서 존이 없다는 것은 아직 놓이지 않았다는 뜻이고,
# 그것을 true 로 보면 진입 즉시 승리가 된다.
func _all_zones_captured() -> bool:
	var zones := get_tree().get_nodes_in_group(CaptureZone.GROUP)
	if zones.is_empty():
		return false
	for zone in zones:
		if not is_instance_valid(zone) or not zone.is_captured():
			return false
	return true


# 방을 새로 만든 직후에 부른다. 판정 가능 여부는 이때 한 번만 따진다.
func _begin_judging() -> void:
	_judging = false

	var stage := StageSystem.get_current_stage()
	if stage == null:
		return

	# 요구 조건이 하나도 없는 타입은 판정할 것이 없다(enum 밖의 값 등).
	if stage.get_objectives().is_empty():
		push_warning("Stage: 승리 조건을 도출할 수 없습니다(type=%d): %s" % [stage.type, stage_name])
		return

	# 적이 하나도 스폰되지 않았으면 진입하자마자 승리가 되어 버린다.
	# (StageData.validate 가 막지만, 씬이 비어 있는 경우까지 여기서 막는다.)
	if stage.requires_clear() and GameManager.get_all_enemies().is_empty():
		push_warning("Stage: 적이 없어 소탕을 판정하지 않습니다: " + stage_name)
		return

	# 같은 이유로 존이 없는 점령 스테이지도 판정하지 않는다.
	if stage.requires_capture() and get_tree().get_nodes_in_group(CaptureZone.GROUP).is_empty():
		push_warning("Stage: 거점 존이 없어 점령을 판정하지 않습니다: " + stage_name)
		return

	_judging = true


func _party_wiped() -> bool:
	if _party_spawned <= 0:
		# 아직 스폰 전이거나 놓을 파티가 없다. 전멸로 보지 않는다.
		return false

	for member in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if is_instance_valid(member) and member.is_alive:
			return false
	return true


func _finish(victory: bool) -> void:
	_judging = false
	if victory:
		EventBus.stage_completed.emit(stage_name)
	else:
		EventBus.stage_failed.emit(stage_name)


# 바깥에서 판을 끝내야 할 때(치트·연출 등) 쓰는 진입점.
func complete_stage():
	_finish(true)

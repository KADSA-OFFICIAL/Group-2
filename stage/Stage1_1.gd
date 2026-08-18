extends Node2D
class_name Stage

# 씬 트리 노드 이름이자 stage_started/completed 에 실리는 값.
# 어떤 스테이지가 로드됐는지 드러나야 하므로 현재 스테이지 id 를 따른다.
var stage_name: String = "Stage"
var current_room: Node = null


func _ready():
	StageSystem.stage_requested.connect(_on_stage_requested)
	_enter_current_stage()


# 출격 화면에서 다른 스테이지를 고르면 그 배치로 다시 만든다.
func _on_stage_requested(_stage_id: StringName) -> void:
	_enter_current_stage()


func _enter_current_stage() -> void:
	var stage := StageSystem.get_current_stage()
	stage_name = String(StageSystem.get_current_id()) if stage != null else "Stage"
	name = stage_name
	EventBus.stage_started.emit(stage_name)
	load_room()

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

	# 적이 놓인 뒤에 판정을 켠다. 순서가 바뀌면 진입하자마자 승리가 된다.
	_begin_judging()

# 파티가 비어 있을 때 쓰는 기본 편성.
# 순혈 3명이라 각 역할이 1카운트씩 되어 세 시너지가 모두 1단계로 켜진다.
# (편성 UI가 생기면 이 기본값 대신 플레이어 선택을 쓴다.)
const DEFAULT_PARTY := [&"shipduck", &"ranged_pure", &"buffer_pure"]

# 파티 멤버를 스폰한다.
# 캐릭터 정의는 PartySystem(-> CharacterDatabase)이 출처이며 여기서 재정의하지 않는다.
# 조종 여부도 PartySystem이 정하므로 노드에는 party_index만 넘긴다.
func spawn_party():
	if PartySystem.is_empty():
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
		# 겹치지 않게 세로로 배치한다.
		node.global_position = Vector2(100, 100 + i * 40)

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

	for spawn in stage.spawns:
		if spawn == null or spawn.enemy_scene == null:
			continue
		for i in range(spawn.count):
			var enemy = spawn.enemy_scene.instantiate()
			current_room.add_child(enemy)
			enemy.global_position = spawn.get_position(i)


# ===== 승패 판정 (Outcome) =====
#
# 소탕(적 전멸) = 승리, 파티 전멸 = 패배. docs §5.1 의 [확정] 사항이다.
#
# 점령은 판정하지 않는다: 존 위치와 확보 시간이 §5.2 에서 [미정]이라 만들 근거가 없다.
# 점령이 필요한 스테이지에서는 판정을 켜지 않고 경고만 남긴다(전투는 계속된다).
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

	# 소탕 조건은 진입 시 확인했다(_begin_judging). 여기서는 남은 적만 본다.
	if GameManager.get_all_enemies().is_empty():
		_finish(true)


# 방을 새로 만든 직후에 부른다. 판정 가능 여부는 이때 한 번만 따진다.
func _begin_judging() -> void:
	_judging = false

	var stage := StageSystem.get_current_stage()
	if stage == null:
		return

	if not stage.requires_clear():
		# 점령 전용 스테이지. 판정할 수단이 없다.
		push_warning("Stage: 점령 판정은 아직 없습니다(§5.2 미정). 승패를 판정하지 않습니다: " + stage_name)
		return

	# 적이 하나도 스폰되지 않았으면 진입하자마자 승리가 되어 버린다.
	# (StageData.validate 가 막지만, 씬이 비어 있는 경우까지 여기서 막는다.)
	if GameManager.get_all_enemies().is_empty():
		push_warning("Stage: 적이 없어 소탕을 판정하지 않습니다: " + stage_name)
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

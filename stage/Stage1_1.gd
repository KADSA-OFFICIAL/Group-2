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

	var member_scene = load("res://entities/player/Player.tscn")
	if member_scene == null:
		push_warning("Stage: Player.tscn을 불러올 수 없습니다.")
		return

	var members = PartySystem.get_members()
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


func complete_stage():
	EventBus.stage_completed.emit(stage_name)

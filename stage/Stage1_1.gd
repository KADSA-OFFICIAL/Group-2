extends Node2D
class_name Stage

var stage_name: String = "Stage1_1"
var current_room: Node = null

func _ready():
	name = stage_name
	EventBus.stage_started.emit(stage_name)
	load_room()

func load_room():
	# Load the first room
	if current_room:
		current_room.queue_free()
	
	# Get or create room
	current_room = get_node_or_null("Room1")
	if not current_room:
		current_room = Node2D.new()
		current_room.name = "Room1"
		add_child(current_room)
	
	# Clear existing children in room
	for child in current_room.get_children():
		child.queue_free()
	
	# Spawn party
	spawn_party()
	
	# Spawn enemies
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

# 훈련용 고블린. data가 없어 AI가 꺼진 샌드백이다(피해 확인용).
const TRAINING_GOBLIN_SCENE := "res://entities/enemies/TrainingGoblin.tscn"
# 서아. EnemyData가 지정되어 있어 추적·공격 AI가 동작한다.
const SEOA_SCENE := "res://entities/enemies/Seoa.tscn"
# 브라키오 수인. 추적·공격 AI + 4방향 워크 모션.
# 스텟/AI 파라미터는 아직 기본값이라 서아보다 빠르고 물렁하다(밸런스 미정).
const BRACHIO_BEASTFOLK_SCENE := "res://entities/enemies/BrachioBeastfolk.tscn"

func spawn_enemies():
	var goblin_scene = load(TRAINING_GOBLIN_SCENE)
	if goblin_scene:
		for i in range(2):
			var goblin = goblin_scene.instantiate()
			current_room.add_child(goblin)
			goblin.global_position = Vector2(400 + i * 100, 200)

	# 추적·공격하는 적 1마리.
	# 파티 스폰 지점(x=100)에서 탐지 범위(300) 밖에 두어, 플레이어가 전진했을 때
	# "탐지 -> 접근 -> 공격" 과정이 눈에 보이게 한다.
	var seoa_scene = load(SEOA_SCENE)
	if seoa_scene == null:
		push_warning("Stage: Seoa.tscn을 불러올 수 없습니다.")
		return

	var seoa = seoa_scene.instantiate()
	current_room.add_child(seoa)
	seoa.global_position = Vector2(600, 140)

	# 브라키오 수인 1마리.
	# 돌창병과 세로로 떨어뜨려 둔다. 둘이 같은 파티 멤버를 쫓아와 겹치면
	# 어느 쪽 모션인지 구분이 안 되기 때문이다.
	# 파티 스폰 지점(x=100)에서 탐지 범위(300) 밖이라 전진해야 반응한다.
	var brachio_scene = load(BRACHIO_BEASTFOLK_SCENE)
	if brachio_scene == null:
		push_warning("Stage: BrachioBeastfolk.tscn을 불러올 수 없습니다.")
		return

	var brachio = brachio_scene.instantiate()
	current_room.add_child(brachio)
	brachio.global_position = Vector2(600, 320)

func complete_stage():
	EventBus.stage_completed.emit(stage_name)


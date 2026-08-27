extends Camera2D
class_name GameCamera

# 전장 카메라. **플레이어**(직접 조작하는 캐릭터)를 따라간다.
#
# 단일 출처 원칙:
#   누가 조작 대상인가는 PartySystem 이 정한다. 카메라는 그 판정을 다시 하지 않고
#   파티원 노드의 is_controlled() 를 읽어 고른다.
#
# 왜 "player" 그룹을 쓰지 않는가 (#210):
#   Player.gd 는 자기를 MEMBER_GROUP 과 "player" 두 그룹에 넣는다. 그래서
#   get_first_node_in_group("player") 은 **파티 전원 중 먼저 등록된 하나**(보통 0번)를
#   돌려준다 — 조작 여부와 무관하다. 그 값을 _ready() 에서 한 번만 잡고 있었으므로
#   조작 대상을 바꿔도 카메라가 0번에 붙어 있었다.
#
# 왜 매 틱 다시 확인하는가:
#   ① 카메라의 _ready() 가 파티 스폰보다 먼저 돌 수 있다(main.tscn 의 노드 순서에
#      의존하고 싶지 않다). ② Stage1_1.load_room() 이 방을 통째로 버리고 파티를 새로
#      스폰하므로 기존 대상이 무효가 된다. 신호만 듣고 있으면 그 사이 빈 상태가 남는다.

# 목표 위치로 붙는 속도. 클수록 빠르게 따라붙는다.
@export var smoothing: float = 5.0

# ===== 세로 프레이밍 (Vertical framing) =====
#
# 시점을 위로 올리는 값은 **Camera2D 내장 offset** 이다(main.tscn 에 저작). 여기서
# 보간 대상을 밀어 올리지 않는다 — 그러면 "따라가는 대상"과 "화면에 보이는 중심"이
# 코드 두 곳으로 갈린다. 엔진이 이미 그 목적의 값을 제공하므로 knob 을 두 개 만들지 않는다.
#
# 왜 올려야 하는가(#212): 파티원의 노드 원점은 **발** 위치이고 스프라이트는 거기서
# 위로 그려진다. 원점을 화면 중앙에 두면 캐릭터(화면 높이 약 119px)가 중앙 위쪽에
# 몰리고 중앙 아래 절반은 빈 땅이 된다.
#   zoom 1.0 / 뷰포트 720 -> 보이는 높이 720, 반높이 360
#   offset.y = -120 이면 발이 위에서 480px(67%), 머리가 361px(50%) 지점에 온다.
#
# ===== 왜 zoom 1.0 인가 (#392) =====
#
# 처음에는 zoom 1.5(보이는 세계 853x480)였는데 **적 탐지 범위(600px)가 화면 반폭(427px)보다
# 넓었다.** 적은 화면 밖에서 플레이어를 보고 다가오고, 플레이어는 자기를 향해 오는 적을
# 볼 수 없었다. 캐릭터 하나가 보이는 높이의 25%를 차지해 "너무 가깝다"고 느껴진 것도 그 때문이다.
#
#   zoom 1.0 / 뷰포트 1280x720 -> 보이는 세계 1280x720, 반폭 640
#   640 > 600(탐지) 이라 적이 다가오기 시작하는 순간이 화면 안에 들어온다.
#   #386 의 수비 반경 320(지름 640)도 한 화면에 담긴다.
#   캐릭터 키 119px 는 화면 높이의 16.5%가 된다.
#
# offset.y 를 -80 에서 -120 으로 함께 올린 이유: 발 위치 비율(67%)을 그대로 두기 위해서다.
# zoom 만 바꾸면 반높이가 240 -> 360 으로 커져 발이 화면 중앙 쪽으로 올라간다.

# 지금 따라가는 노드. 조작 대상이 없으면 null 이고, 그때는 마지막 위치에 머문다.
var player: Node2D = null


func _ready() -> void:
	make_current()
	_acquire_target(true)

	# 조작 전환과 스테이지 재로드는 대상이 바뀌는 두 사건이다.
	EventBus.party_control_changed.connect(func(_index: int): _acquire_target(false))
	# 재로드 시점에는 새 파티가 아직 없다. 무효화만 하고 다음 틱에 다시 찾는다.
	EventBus.stage_started.connect(func(_stage_name): player = null)


func _physics_process(delta: float) -> void:
	# 대상을 잃었거나(재로드·사망) 더 이상 조작 대상이 아니면 다시 찾는다.
	if not _is_valid_target(player):
		_acquire_target(true)

	if player == null:
		return

	# lerp 가중치를 1.0 으로 묶는다. 프레임이 길게 튀면 smoothing * delta 가 1 을 넘어
	# 목표를 지나쳐 흔들린다.
	var weight: float = clampf(smoothing * delta, 0.0, 1.0)
	global_position = global_position.lerp(player.global_position, weight)


# 플레이어 노드를 찾는다. snap 이면 찾은 즉시 그 위치로 붙인다.
#
# 처음 잡을 때와 대상을 잃었다 다시 잡을 때는 스냅한다 — 그 경우 카메라가 엉뚱한
# 곳에 있어서, 부드럽게 가면 화면이 한참 미끄러진다.
# 조작 전환(snap = false)은 부드럽게 따라가는 편이 자연스럽다.
func _acquire_target(snap: bool) -> void:
	var found := _find_controlled_member()
	if found == null:
		player = null
		return

	var changed := found != player
	player = found
	if snap and changed:
		global_position = player.global_position


# MEMBER_GROUP 에서 is_controlled() 인 노드. 없으면 null.
# 그룹 이름의 단일 출처는 PartySystem.MEMBER_GROUP 이다(문자열을 여기 다시 적지 않는다).
func _find_controlled_member() -> Node2D:
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if _is_valid_target(node):
			return node as Node2D
	return null


# 따라갈 수 있는 대상인가. 살아 있는 노드이고 지금 조작 중이어야 한다.
func _is_valid_target(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not (node is Node2D):
		return false
	# is_controlled() 가 없는 노드가 그룹에 들어와도 안전하게 넘긴다.
	if not node.has_method("is_controlled"):
		return false
	return bool(node.is_controlled())

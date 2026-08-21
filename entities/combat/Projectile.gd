extends Node2D
class_name Projectile

# 적이 쏘는 투사체. 직선으로 날아가 파티원에 닿으면 피해를 준다.
#
# 이 프로젝트의 첫 투사체다(#214). 그전까지 모든 공격은 사거리 안이면 그 자리에서
# take_damage 를 부르는 즉시 피해(hitscan)였다.
#
# 단일 출처 원칙:
#   피해량은 **발사한 쪽**이 정해서 실어 보낸다(EnemyBase 가 get_physical_attack() 을 읽는다).
#   방어 적용과 피해 공식은 계속 대상의 take_damage -> PlayerStats.apply_defense() 다.
#   여기서 피해를 다시 계산하지 않는다.
#
# 왜 Area2D 를 쓰지 않는가:
#   이 프로젝트는 충돌 레이어를 분리하지 않았다(플레이어·적 모두 기본 레이어 1).
#   Area2D 로 잡으면 적 탄이 적에게도 반응하므로 마스크 작업이 먼저 필요하다.
#   EnemyBase 가 이미 쓰는 방식(MEMBER_GROUP 순회 + 거리 판정)을 따른다 —
#   레이어 설정에 의존하지 않고 헤드리스로 검증할 수 있다.
#
# 유도하지 않는다: 발사 순간의 방향으로만 날아간다. 그래서 **빗나갈 수 있고**,
# 플레이어가 피할 여지가 생긴다. 그게 원거리 적을 두는 이유다.

# 진행 방향(단위 벡터) x 속도. setup() 이 정한다.
var velocity: Vector2 = Vector2.ZERO

# 명중 시 대상에게 넘길 피해량. 발사한 쪽이 이미 계산해 넣는다.
var damage: int = 0

# 쏜 주체. take_damage 의 source 로 넘겨 반사·처형 등 기존 규칙이 그대로 돌게 한다.
var source: Node = null

# 명중 시 대상에게 걸 상태 효과 id. 비어 있으면 피해만 준다.
# (강화 평타를 가진 적이 원거리가 되어도 그 효과가 따라가도록 통로를 열어 둔다.)
var effect_id: StringName = &""

# 이 반경 안에 파티원이 들어오면 명중이다.
var hit_radius: float = 12.0

# 이만큼 날아가면 스스로 사라진다. 화면 밖으로 무한히 날아가지 않게 한다.
var max_distance: float = 0.0

# 그린 원의 색. 쏜 적의 tint 를 받아 누가 쏜 탄인지 구분한다.
var color: Color = Color.WHITE

var _travelled: float = 0.0


# 발사 직후 한 번 호출한다. direction 은 정규화하지 않아도 된다.
func setup(direction: Vector2, speed: float, p_damage: int, p_source: Node,
		p_max_distance: float, p_hit_radius: float = 12.0,
		p_effect_id: StringName = &"", p_color: Color = Color.WHITE) -> void:
	velocity = direction.normalized() * speed
	damage = p_damage
	source = p_source
	max_distance = p_max_distance
	hit_radius = p_hit_radius
	effect_id = p_effect_id
	color = p_color
	queue_redraw()


func _physics_process(delta: float) -> void:
	var step: Vector2 = velocity * delta
	global_position += step
	_travelled += step.length()

	var target := _find_hit()
	if target != null:
		_hit(target)
		return

	# 빗나간 탄을 남겨 두면 노드가 계속 쌓인다.
	if max_distance > 0.0 and _travelled >= max_distance:
		queue_free()


# 명중 반경 안의 살아 있는 파티원. 없으면 null.
#
# **파티원만 찾는다** — 적 그룹은 보지 않으므로 적 탄이 적을 맞히지 않는다.
# 그룹 이름의 단일 출처는 PartySystem.MEMBER_GROUP 이다.
func _find_hit() -> Node2D:
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if node == null or not is_instance_valid(node):
			continue
		var member := node as Node2D
		if member == null:
			continue
		# 죽은 대상은 맞히지 않는다. is_alive 가 없는 노드는 살아 있다고 본다.
		var alive = member.get("is_alive")
		if alive != null and not bool(alive):
			continue
		if global_position.distance_to(member.global_position) <= hit_radius:
			return member
	return null


# 피해를 주고 사라진다. 관통하지 않으므로 첫 명중 하나만 맞힌다.
func _hit(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage, source)

	# 대상이 이 타격으로 죽었을 수 있다. 죽은 대상에 효과를 걸지 않는다.
	if effect_id != &"" and is_instance_valid(target) and target.get("is_alive") != false:
		StatusEffectSystem.apply(target, effect_id, source)

	queue_free()


# 아트가 없다. 도형인 것이 드러나야 아트가 들어올 때 무엇이 임시였는지 알 수 있다
# (적 플레이스홀더와 같은 규약).
func _draw() -> void:
	draw_circle(Vector2.ZERO, hit_radius, color)
	draw_arc(Vector2.ZERO, hit_radius, 0.0, TAU, 16, Color(0, 0, 0, 0.55), 2.0)

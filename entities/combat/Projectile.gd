extends Node2D
class_name Projectile

# 직선으로 날아가 닿은 대상에게 피해를 주는 탄.
#
# 이 프로젝트의 첫 투사체다(#214). 그전까지 모든 공격은 사거리 안이면 그 자리에서
# take_damage 를 부르는 즉시 피해(hitscan)였다.
#
# 두 방향을 모두 태운다(#259):
#   적 -> 파티원 : 원거리 적의 평타. hits_enemies = false (기본값).
#   파티 -> 적   : 미나의 방울 같은 투사체 스킬. hits_enemies = true.
# 방향 하나를 위해 같은 비행·명중 코드를 두 벌 두지 않으려고 여기서 갈래를 잡는다.
#
# 단일 출처 원칙:
#   피해량은 **발사한 쪽**이 정해서 실어 보낸다(EnemyBase 는 get_physical_attack(),
#   스킬은 SkillData.get_effective_power() 를 읽는다).
#   방어 적용과 피해 공식은 계속 대상의 take_damage -> PlayerStats.apply_defense() 다.
#   여기서 피해를 다시 계산하지 않는다.
#
# 왜 Area2D 를 쓰지 않는가:
#   이 프로젝트는 충돌 레이어를 분리하지 않았다(플레이어·적 모두 기본 레이어 1).
#   Area2D 로 잡으면 탄이 쏜 쪽에도 반응하므로 마스크 작업이 먼저 필요하다.
#   EnemyBase 가 이미 쓰는 방식(그룹/목록 순회 + 거리 판정)을 따른다 —
#   레이어 설정에 의존하지 않고 헤드리스로 검증할 수 있다.
#
# 유도하지 않는다: 발사 순간의 방향으로만 날아간다. 그래서 **빗나갈 수 있고**,
# 맞는 쪽이 피할 여지가 생긴다. 그게 원거리 공격을 두는 이유다.

# 진행 방향(단위 벡터) x 속도. setup() 이 정한다.
var velocity: Vector2 = Vector2.ZERO

# 명중 시 대상에게 넘길 피해량. 발사한 쪽이 이미 계산해 넣는다.
var damage: int = 0

# 쏜 주체. take_damage 의 source 로 넘겨 반사·처형 등 기존 규칙이 그대로 돌게 한다.
var source: Node = null

# 명중 시 대상에게 걸 상태 효과 id. 비어 있으면 피해만 준다.
# (강화 평타를 가진 적이 원거리가 되어도 그 효과가 따라가도록 통로를 열어 둔다.)
var effect_id: StringName = &""

# 이 반경 안에 대상이 들어오면 명중이다.
var hit_radius: float = 12.0

# 이만큼 날아가면 사라진다(광역탄이면 그 자리에서 터진다).
var max_distance: float = 0.0

# 그린 원의 색. 쏜 쪽의 tint 를 받아 누구의 탄인지 구분한다.
var color: Color = Color.WHITE

# true 면 **적**을 맞힌다(파티가 쏜 탄). false 면 파티원을 맞힌다(적이 쏜 탄).
var hits_enemies: bool = false

# 착탄 반경(px). 0 보다 크면 맞은 하나가 아니라 이 반경 **안의 모두**에게 들어간다.
# 광역탄은 아무것도 맞히지 못해도 최대 사거리에서 터진다 — 빗나갔다고 아무 일도
# 없으면 조준을 요구하는 대가만 있고 보상이 없다.
var aoe_radius: float = 0.0

var _travelled: float = 0.0


# 발사 직후 한 번 호출한다. direction 은 정규화하지 않아도 된다.
#
# 뒤의 두 인자는 나중에 붙었다(#259). 기본값이 기존 동작(적 탄, 단일 대상)이라
# 인자를 넘기지 않는 기존 호출부(EnemyBase)는 그대로 돈다.
func setup(direction: Vector2, speed: float, p_damage: int, p_source: Node,
		p_max_distance: float, p_hit_radius: float = 12.0,
		p_effect_id: StringName = &"", p_color: Color = Color.WHITE,
		p_hits_enemies: bool = false, p_aoe_radius: float = 0.0) -> void:
	velocity = direction.normalized() * speed
	damage = p_damage
	source = p_source
	max_distance = p_max_distance
	hit_radius = p_hit_radius
	effect_id = p_effect_id
	color = p_color
	hits_enemies = p_hits_enemies
	aoe_radius = p_aoe_radius
	queue_redraw()


func _physics_process(delta: float) -> void:
	var step: Vector2 = velocity * delta
	global_position += step
	_travelled += step.length()

	var target := _find_hit()
	if target != null:
		_hit(target)
		return

	if max_distance > 0.0 and _travelled >= max_distance:
		# 광역탄은 빗나가도 그 자리에서 터진다. 단일탄은 그냥 사라진다
		# (빗나간 탄을 남겨 두면 노드가 계속 쌓인다).
		if aoe_radius > 0.0:
			_explode()
		queue_free()


# 명중 반경 안의 살아 있는 대상. 없으면 null.
func _find_hit() -> Node2D:
	for node in _candidates():
		var body := node as Node2D
		if body == null or not is_instance_valid(body):
			continue
		if not _is_alive(body):
			continue
		if global_position.distance_to(body.global_position) <= hit_radius:
			return body
	return null


# 이 탄이 맞힐 수 있는 대상 목록.
#
# 적 목록의 단일 출처는 GameManager, 파티원 그룹의 단일 출처는 PartySystem.MEMBER_GROUP 이다.
# 여기서 이름을 다시 적지 않는다.
func _candidates() -> Array:
	if hits_enemies:
		return GameManager.get_all_enemies()
	return get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP)


# is_alive 가 없는 노드는 살아 있다고 본다(기존 규약).
func _is_alive(node: Node) -> bool:
	var alive = node.get("is_alive")
	return alive == null or bool(alive)


# 맞았다. 광역탄이면 터지고, 아니면 맞은 하나에게만 들어간다.
func _hit(target: Node2D) -> void:
	if aoe_radius > 0.0:
		_explode()
	else:
		_deliver(target)
	queue_free()


# 착탄 지점 반경 안의 모든 대상에게 피해와 효과를 넣는다.
func _explode() -> void:
	var origin := global_position
	for node in _candidates():
		var body := node as Node2D
		if body == null or not is_instance_valid(body) or not _is_alive(body):
			continue
		if origin.distance_to(body.global_position) > aoe_radius:
			continue
		_deliver(body)


# 대상 하나에게 피해를 주고, 살아남았으면 효과를 건다.
func _deliver(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage, source)

	# 대상이 이 타격으로 죽었을 수 있다. 죽은 대상에 효과를 걸지 않는다.
	if effect_id != &"" and is_instance_valid(target) and _is_alive(target):
		StatusEffectSystem.apply(target, effect_id, source)


# 아트가 없다. 도형인 것이 드러나야 아트가 들어올 때 무엇이 임시였는지 알 수 있다
# (적 플레이스홀더와 같은 규약).
func _draw() -> void:
	draw_circle(Vector2.ZERO, hit_radius, color)
	draw_arc(Vector2.ZERO, hit_radius, 0.0, TAU, 16, Color(0, 0, 0, 0.55), 2.0)

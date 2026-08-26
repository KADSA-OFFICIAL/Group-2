extends Node2D
class_name Shockwave

# 시전 지점에서 바깥으로 **퍼져 나가는** 원형 파동(#276).
#
# BeamEffect(#263)와 반대다. 저쪽은 판정이 발사 순간에 끝나고 그림만 남지만,
# 이쪽은 **판정 자체가 시간에 따라 퍼진다** — 파동이 닿는 그 순간 적중한다.
# 그래서 달려서 피할 수 있고, 먼 대상일수록 늦게 맞는다. 그 차이가 이 스킬의 성질이라
# 연출로 흉내 내지 않고 실제로 퍼지게 했다.
#
# 한 대상은 **한 번만** 맞는다. 반경이 계속 커지므로 걸러 내지 않으면 매 프레임 다시 맞는다.
#
# 단일 출처 원칙:
#   피해량·회복량은 **시전한 쪽**이 정해서 실어 보낸다(Projectile 과 같은 규약).
#   방어 적용과 피해 공식은 계속 대상의 take_damage -> PlayerStats.apply_defense() 다.
#   여기서 피해를 다시 계산하지 않는다.
#
# 왜 Area2D 를 쓰지 않는가: Projectile 과 같은 이유다. 이 프로젝트는 충돌 레이어를 분리하지
# 않아서 Area2D 로 잡으면 시전자에게도 반응한다. 그룹/목록 순회 + 거리 판정이 기존 방식이고,
# 레이어 설정에 의존하지 않아 헤드리스로 검증할 수 있다.

# 지금 파동의 반경(px). 0 에서 시작해 max_radius 까지 커진다.
var radius: float = 0.0

# 여기까지 커지면 파동이 끝나고 노드가 사라진다.
var max_radius: float = 0.0

# 반경이 커지는 속도(px/s).
var speed: float = 0.0

# 적에게 넣을 피해량. 시전한 쪽이 이미 계산해 넣는다.
var damage: int = 0

# 아군에게 넣을 회복량. 시전한 쪽이 이미 계산해 넣는다.
var heal: int = 0

# 시전자. take_damage 의 source 로 넘겨 반사·처형 등 기존 규칙이 그대로 돌게 한다.
var source: Node = null

# 그린 원의 색. 시전자의 tint 를 받아 누구의 파동인지 구분한다.
var color: Color = Color.WHITE

# 이미 맞힌 대상들. 반경이 커져도 다시 맞지 않게 한다.
var _hit: Array = []


# 시전 직후 한 번 호출한다.
func setup(p_max_radius: float, p_speed: float, p_damage: int, p_heal: int,
		p_source: Node, p_color: Color = Color.WHITE) -> void:
	max_radius = maxf(p_max_radius, 0.0)
	speed = maxf(p_speed, 0.0)
	damage = p_damage
	heal = p_heal
	source = p_source
	color = p_color
	queue_redraw()


func _physics_process(delta: float) -> void:
	if speed <= 0.0 or max_radius <= 0.0:
		queue_free()
		return

	radius = minf(radius + speed * delta, max_radius)
	_sweep()
	queue_redraw()

	if radius >= max_radius:
		queue_free()


# 지금 반경 안에 새로 들어온 대상을 처리한다.
#
# "이번 프레임에 링이 지나간 띠"가 아니라 "반경 안 전체"를 본다. 띠로만 잡으면 프레임이
# 튀었을 때 그 사이 구간이 통째로 건너뛰어져 조용히 맞지 않는 대상이 생긴다.
# 이미 맞힌 대상은 _hit 이 걸러 내므로 반경 전체를 봐도 중복되지 않는다.
func _sweep() -> void:
	if damage > 0:
		for enemy in GameManager.get_all_enemies():
			_try_reach(enemy, true)

	if heal > 0:
		for member in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
			_try_reach(member, false)


func _try_reach(node, hostile: bool) -> void:
	var body := node as Node2D
	if body == null or not is_instance_valid(body) or _hit.has(body):
		return
	if not _is_alive(body):
		return
	if global_position.distance_to(body.global_position) > radius:
		return

	_hit.append(body)
	if hostile:
		if body.has_method("take_damage"):
			body.take_damage(damage, source)
	elif body.has_method("heal"):
		body.heal(heal)


# is_alive 가 없는 노드는 살아 있다고 본다(Projectile 과 같은 규약).
func _is_alive(node: Node) -> bool:
	var alive = node.get("is_alive")
	return alive == null or bool(alive)


# 아트가 없다. 도형인 것이 드러나야 아트가 들어올 때 무엇이 임시였는지 알 수 있다
# (Projectile·BeamEffect 와 같은 규약).
#
# 링만 그린다(채우지 않는다). 채우면 파동이 지나간 안쪽까지 계속 덮여, 지금 판정이 일어나는
# 자리가 어디인지 화면에서 사라진다.
func _draw() -> void:
	if radius <= 0.0:
		return
	var fade: float = 1.0
	if max_radius > 0.0:
		fade = clampf(1.0 - radius / max_radius, 0.15, 1.0)
	var ring := color
	ring.a = 0.9 * fade
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, ring, 6.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.5 * fade), 2.0)

extends Node2D
class_name AuraZone

# 시전 자리에 **머무는** 원형 지대(#334).
#
# Shockwave(#276)와 반대다. 저쪽은 판정이 퍼져 나가고 한 대상을 한 번만 맞히지만,
# 이쪽은 반경이 고정된 채 **안에 있는 동안 계속** 효과를 건다.
# 그래서 값어치가 "맞혔는가"가 아니라 **"아군이 거기 서 있는가"** 다.
#
# 지대는 시전 자리에 **고정**된다. 시전자를 따라다니면 시전자는 항상 안에 있어서
# "안에 있는가"라는 판단이 사라지고, 지대를 깔 위치를 고르는 조작도 없어진다.
#
# 단일 출처 원칙:
#   효과의 내용(공속·받는 피해 감소)과 지속시간은 StatusEffectData 가 소유한다.
#   여기서는 **누가 안에 있는지**만 판정하고 걸고 푼다. 수치를 만들지 않는다.
#
# 왜 Area2D 를 쓰지 않는가: Projectile·Shockwave 와 같은 이유다. 이 프로젝트는 충돌
# 레이어를 분리하지 않아서 Area2D 로 잡으면 엉뚱한 것까지 반응하고, 레이어 설정에
# 의존하면 헤드리스로 검증할 수 없다. 그룹 순회 + 거리 판정이 기존 방식이다.
#
# 참고: entities/combat/Shockwave.gd, autoload/StatusEffectSystem.gd

# 지대 반경(px).
var radius: float = 0.0

# 남은 수명(초). 0 이하가 되면 지대가 사라진다.
var time_left: float = 0.0

# 지대 안 아군에게 걸 효과 id.
var effect_id: StringName = &""

# 지대를 놓은 쪽. 효과의 source 로 넘겨 기존 규칙(출처 조회 등)이 그대로 돌게 한다.
var source: Node = null

# 그린 원의 색. 시전자의 tint 를 받아 누구의 지대인지 구분한다.
var color: Color = Color.WHITE

# 지금 안에 있어서 효과가 걸려 있는 대상들.
#
# 왜 들고 있어야 하는가: 나간 대상의 효과를 **그 즉시** 풀어야 한다. 효과의 duration 에
# 맡기면 지대를 벗어나고도 남은 시간만큼 버프가 따라다녀서, "안에 있는 동안만"이라는
# 계약이 깨진다. 누가 안에 있었는지 알아야 나간 순간을 알 수 있다.
var _inside: Array = []


# 시전 직후 한 번 호출한다.
func setup(p_radius: float, p_duration: float, p_effect_id: StringName,
		p_source: Node, p_color: Color = Color.WHITE) -> void:
	radius = maxf(p_radius, 0.0)
	time_left = maxf(p_duration, 0.0)
	effect_id = p_effect_id
	source = p_source
	color = p_color
	queue_redraw()


func _physics_process(delta: float) -> void:
	if radius <= 0.0 or effect_id == &"":
		queue_free()
		return

	time_left -= delta
	if time_left <= 0.0:
		# 사라질 때 걸어 둔 효과를 직접 푼다. 수명이 끝난 지대의 버프가 남아 있으면
		# "지대 안에서만"이라는 계약이 깨진다.
		_release_all()
		queue_free()
		return

	_sweep()
	queue_redraw()


# 트리에서 빠질 때도 걸어 둔 효과를 푼다.
#
# _physics_process 의 만료 경로와 중복이 아니다: 방을 버릴 때(Stage1_1.load_room) 등
# 지대가 **수명과 무관하게** 사라지는 길이 있다. 그때 풀지 않으면 버프가 영구히 남는다.
func _exit_tree() -> void:
	_release_all()


# 지금 반경 안/밖을 다시 판정한다. 들어온 대상에게 걸고, 나간 대상에게서 푼다.
func _sweep() -> void:
	var members := get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP)

	# 들어온 대상: 매 프레임 다시 apply 하지 않는다. 중첩 규칙이 REFRESH 여도 매번
	# 신호(status_effect_applied)를 쏘게 되어 화면이 떨고, STACK_INTENSITY 였다면
	# 프레임마다 한 겹씩 쌓여 상한까지 순식간에 올라간다.
	for node in members:
		var member := node as Node2D
		if member == null or not is_instance_valid(member) or not _is_alive(member):
			continue
		if global_position.distance_to(member.global_position) > radius:
			continue
		if _inside.has(member):
			continue
		_inside.append(member)
		StatusEffectSystem.apply(member, effect_id, _live_source())

	# 나간 대상: 뒤에서부터 지운다(순회 중 제거).
	for i in range(_inside.size() - 1, -1, -1):
		var member = _inside[i]
		var gone := not is_instance_valid(member)
		if not gone:
			gone = not _is_alive(member) \
				or global_position.distance_to(member.global_position) > radius
		if not gone:
			continue
		_inside.remove_at(i)
		if is_instance_valid(member):
			StatusEffectSystem.remove(member, effect_id)


# 아직 살아 있는 시전자. 이미 해제됐으면 null 이다(#391).
#
# 지대는 **시전자보다 오래 산다** — 부모가 시전자가 아니라 전장이고(vfx-guide §1.7),
# 수명은 aura_duration 이 따로 갖는다. 그래서 지대가 도는 동안 시전자가 죽을 수 있다.
#
# 그때 해제된 노드를 그대로 넘기면 `StatusEffectSystem.apply()` 의 인자 타입 검사에서
# "previously freed" 로 터진다 — 매 프레임 새로 들어오는 대상마다 난다.
# 실제로 익룡 여왕이 체력 25% 에서 지대를 깔고 6초 안에 죽으면서 이 경로를 밟았다.
# 강지 Q 도 같은 구조라(시전자가 파티원이고 죽을 수 있다) 같은 보호를 받는다.
#
# 효과 자체는 그대로 걸어야 한다 — 지대가 살아 있는 한 그 안은 위험한 자리다.
# source 는 "누가 걸었는가"라는 부가 정보이지 효과의 전제가 아니다(apply 의 기본값도 null).
func _live_source() -> Node:
	if source != null and is_instance_valid(source):
		return source
	return null


# 걸어 둔 효과를 전부 푼다.
func _release_all() -> void:
	for member in _inside:
		if is_instance_valid(member):
			StatusEffectSystem.remove(member, effect_id)
	_inside.clear()


# is_alive 가 없는 노드는 살아 있다고 본다(Shockwave·Projectile 과 같은 규약).
func _is_alive(node: Node) -> bool:
	var alive = node.get("is_alive")
	return alive == null or bool(alive)


# 아트가 없다. 도형인 것이 드러나야 아트가 들어올 때 무엇이 임시였는지 알 수 있다
# (Shockwave·Projectile·BeamEffect 와 같은 규약).
#
# Shockwave 와 달리 **안쪽을 옅게 채운다.** 저쪽은 판정이 링 위에서만 일어나므로 채우면
# 거짓말이 되지만, 이쪽은 원 안 전체가 판정 범위다 — 서 있어야 할 곳이 보여야 한다.
#
# 수명이 줄면 함께 옅어진다. 언제 사라질지가 화면에서 읽혀야 서 있을지 나갈지 판단할 수 있다.
func _draw() -> void:
	if radius <= 0.0:
		return

	var fade: float = clampf(time_left, 0.0, 1.0)
	var fill := color
	fill.a = 0.12 * (0.4 + 0.6 * fade)
	draw_circle(Vector2.ZERO, radius, fill)

	var ring := color
	ring.a = 0.85 * (0.3 + 0.7 * fade)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, ring, 4.0)

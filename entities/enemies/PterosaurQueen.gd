extends BossEnemyBase
class_name PterosaurQueen

# 익룡 여왕 보스 (#391).
#
# 공략 축이 매머드 우두머리와 **반대**다.
#
#   매머드 — 붙어서 버틴다.   보스는 돌진·도약으로 **따라붙는다.**
#   여왕   — 거리를 좁힌다.   보스는 후퇴·차단으로 **떼어놓는다.**
#
# 같은 뼈대(BossEnemyBase) 위에서 방향만 뒤집었다. 안무 3종은 전부 "거리를 지키려는 저항"이다.
#
#   1. 후퇴 사격 — 붙은 쪽 반대로 물러난다. 좁힌 거리를 한 번 되돌린다.
#   2. 관통 직선 — 준비 후 직선을 쏜다. 붙어 있을수록 반응 시간이 짧다.
#   3. 속박 지대 — 파티 자리에 지대를 깔아 다가오는 길을 늦춘다.
#
# 수치의 출처는 SkillData(.tres) 다(docs/vfx-guide.md §1.3).

const AURA_ZONE_SCENE := preload("res://entities/combat/AuraZone.tscn")

# 후퇴 속도(px/s). 거동값이라 여기 둔다 — 후퇴는 피해가 아니라 이동이라
# 속도가 무엇을 맞고 안 맞고를 바꾸지 않는다(MammothBoss.CHARGE_SPEED 와 같은 자리).
const RETREAT_SPEED: float = 700.0

# 강화탄 조준 시간(초). 4타째에만 붙는 선딜이다.
#
# 왜 SkillData 가 아니라 여기인가: 강화 평타는 EnemyData.charged_attack_* 가 정의하는
# **평타의 변형**이지 스킬이 아니라서 실을 SkillData 가 없다. 새 EnemyData 필드를 만들지
# 않은 이유는 이 선딜을 쓰는 적이 여왕 하나뿐이기 때문이다 — 원거리 적 일반의 발사 예고는
# 별개 작업이다(여왕 문서 #380 §5-3).
const AIM_TIME: float = 0.6

# 조준 예고 띠의 폭(px). 판정이 아니라 **어느 쪽을 노리는지**만 보여 준다 —
# 강화탄은 여전히 투사체라 실제 명중은 projectile_hit_radius 가 정한다.
const AIM_BEAM_WIDTH: float = 40.0

enum Act {
	NONE = 0,  # BossEnemyBase.ACT_NONE
	RETREAT,   # 안무 1 — 후퇴
	AIM_BEAM,  # 안무 2 — 관통 직선 준비
	AIM_SHOT,  # 강화탄 조준 (안무이지만 페이즈 스킬이 아니다)
}

# 후퇴 방향. 시작할 때 정하고 도중에 바꾸지 않는다.
var _retreat_direction: Vector2 = Vector2.ZERO
# 관통 직선의 방향. 준비 시작 시점에 굳힌다.
var _beam_direction: Vector2 = Vector2.ZERO


# ===== 페이즈 스킬 =====
#
# 어느 안무인지는 스킬 데이터가 정한다 — 스크립트가 인덱스로 분기하면
# .tres 순서를 바꿀 때 조용히 다른 안무가 나간다.
func _start_skill(skill: SkillData) -> void:
	if skill.aura_radius > 0.0:
		_begin_zone(skill)
	elif skill.beam_length > 0.0:
		_begin_beam(skill)
	else:
		_begin_retreat(skill)


# ----- 안무 1: 후퇴 사격 -----
#
# 가장 가까운 파티원 **반대 방향**으로 물러난다. 대시(EnemyBase)와 같은 부품을 쓰지만
# 방향이 반대다 — 그것이 이 보스의 정체성이다.
#
# 예고가 없는 이유: 피해가 아니라 이동이라 맞고 안 맞고가 없다. 예고를 붙이면
# 플레이어가 피할 것을 찾다가 아무 일도 일어나지 않는다.
func _begin_retreat(skill: SkillData) -> void:
	var target := _nearest_party_member()
	if target == null:
		_end_act()
		return

	# 대상에게서 멀어지는 쪽. 겹쳐 서 있으면(거리 0) 방향이 없으므로 그냥 끝낸다.
	var away: Vector2 = target.global_position.direction_to(global_position)
	if away.length() < 0.001:
		_end_act()
		return

	_retreat_direction = away
	_act = Act.RETREAT
	_act_left = maxf(skill.cast_time, 0.01)


func _tick_retreat(_delta: float) -> void:
	velocity = _retreat_direction * RETREAT_SPEED
	move_and_slide()
	if _act_left <= 0.0:
		_end_act()


# ----- 안무 2: 관통 직선 -----

func _begin_beam(skill: SkillData) -> void:
	var target := _resolve_target()
	if target == null:
		_end_act()
		return

	# 방향을 준비 시작에 굳힌다(매머드 돌진과 같은 규약). 쏠 때 다시 조준하면
	# 준비 시간이 회피 창이 아니라 대기 시간이 된다.
	_beam_direction = global_position.direction_to(target.global_position)
	_act = Act.AIM_BEAM
	_act_left = maxf(skill.cast_time, 0.01)

	# 그리는 크기 = 판정 크기(vfx-guide §1.2).
	var telegraph := _spawn_telegraph()
	if telegraph != null:
		telegraph.setup_beam(global_position, _beam_direction,
			skill.beam_length, skill.beam_width, _act_left)


# 준비가 끝나면 한 번에 판정한다. 매머드 돌진과 달리 **보스는 움직이지 않는다** —
# 여왕은 자리를 지키는 쪽이다.
#
# 띠 안에 있으면 맞는다. 거리 제한(beam_length)과 폭(beam_width) 둘 다 본다.
func _fire_beam() -> void:
	var length := _skill.beam_length
	var half := _skill.beam_width * 0.5
	for node in _living_party_members():
		var to_node: Vector2 = node.global_position - global_position
		var along: float = to_node.dot(_beam_direction)
		if along < 0.0 or along > length:
			continue
		if absf(to_node.dot(Vector2(-_beam_direction.y, _beam_direction.x))) > half:
			continue
		_hit_max_hp(node, _skill)
	_end_act()


# ----- 안무 3: 속박 지대 -----
#
# 파티 자리에 지대를 깔고 바로 평소로 돌아간다. 지대는 스스로 살아 있는 노드라
# 보스가 계속 붙잡고 있을 이유가 없다.
#
# AuraZone 을 그대로 쓴다 — 아군 버프용으로 만들어졌지만 MEMBER_GROUP 에 효과를 걸므로
# 디버프를 넣으면 그대로 동작한다. 여기서 지대를 새로 만들지 않는다.
func _begin_zone(skill: SkillData) -> void:
	var target := _resolve_target()
	if target == null:
		_end_act()
		return

	var host := get_parent()
	if host != null:
		var zone: Node2D = AURA_ZONE_SCENE.instantiate()
		# 부모는 전장이다(vfx-guide §1.7) — 여왕이 물러나도 지대는 그 자리에 남는다.
		host.add_child(zone)
		zone.global_position = target.global_position
		zone.setup(skill.aura_radius, skill.aura_duration, skill.aura_effect_id, self)

	_end_act()


# ===== 강화탄 조준 (페이즈 스킬이 아니다) =====
#
# 4타째 강화탄에 짧은 선딜과 예고를 붙인다. 붙이지 않으면 기절을 **볼 수는 있어도
# 준비할 수 없다**(여왕 문서 #380 §5-3).
#
# 페이즈 스킬이 판당 세 번인 데 비해 이쪽은 계속 나오므로 체감이 가장 크다.
# 발사가 AIM_TIME 만큼 늦어져 DPS 가 내려가는 것은 의도다.
func try_attack() -> bool:
	# 이미 조준 중이거나 안무 중이면 여기서 쏘지 않는다.
	if is_acting():
		return false
	if not _next_attack_is_charged():
		return super.try_attack()
	if not can_attack() or not _is_valid_target(_target):
		return false

	_begin_aim()
	return true


# 이번 평타가 강화 평타가 되는가. 판정 규칙의 출처는 EnemyBase.try_attack() 이고
# 여기서 다시 정의하지 않는다 — 같은 식을 읽기만 한다.
func _next_attack_is_charged() -> bool:
	if data == null or data.charged_attack_threshold <= 0:
		return false
	return _charge_count >= data.charged_attack_threshold


func _begin_aim() -> void:
	_beam_direction = global_position.direction_to(_target.global_position)
	_act = Act.AIM_SHOT
	_act_left = AIM_TIME

	# 노리는 방향만 보여 준다. 강화탄은 투사체라 이 띠가 판정은 아니다 —
	# 그래서 폭을 판정이 아니라 읽히는 굵기로 잡았다(위 상수 주석).
	var telegraph := _spawn_telegraph()
	if telegraph != null:
		telegraph.setup_beam(global_position, _beam_direction,
			data.attack_range, AIM_BEAM_WIDTH, AIM_TIME)


# 조준이 끝나면 그대로 평타를 낸다. 강화 판정·피해·상태 효과는 EnemyBase 가 갖는다 —
# 여기서 다시 계산하면 두 벌이 된다.
func _release_aim() -> void:
	_clear_telegraph()
	_act = ACT_NONE
	_act_left = 0.0
	if _is_valid_target(_target):
		super.try_attack()
	_end_act()


# ===== 진행 =====

func _tick_act(delta: float) -> void:
	match _act:
		Act.RETREAT:
			_tick_retreat(delta)
		Act.AIM_BEAM:
			velocity = Vector2.ZERO
			if _act_left <= 0.0:
				_fire_beam()
		Act.AIM_SHOT:
			velocity = Vector2.ZERO
			if _act_left <= 0.0:
				_release_aim()
		_:
			_end_act()


# 자기를 뺀 살아 있는 파티원 중 가장 가까운 쪽. 후퇴 방향의 기준이다.
#
# EnemyBase._find_nearest_party_member() 와 나눠 두지 않고 _living_party_members() 를 쓰는
# 이유: 저쪽은 도발(TAUNT)을 반영한 "지금 노리는 대상"을 고르는 경로이고, 후퇴는
# **물리적으로 가장 가까운 위협**에서 물러나는 것이라 도발과 무관하다.
func _nearest_party_member() -> Node:
	var best: Node = null
	var best_distance := INF
	for node in _living_party_members():
		var distance: float = global_position.distance_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best

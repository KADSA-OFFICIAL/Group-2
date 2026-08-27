extends BossEnemyBase
class_name MammothBoss

# 매머드 수인 보스 (#376).
#
# 광역 평타·3타 기절·대시는 EnemyBase 와 EnemyData 가 가진 일반 기능이라 여기 없다.
# 체력 임계선·안무 뼈대·예고는 BossEnemyBase 가 갖는다(#391 에서 여왕과 공유하려고 뺐다).
# 이 스크립트가 갖는 것은 **이 보스의 안무 2종**뿐이다.
#
# 공략 축: **붙어서 버틴다.** 두 안무 모두 거리를 지우고 따라붙는 쪽이다
# — 여왕(PterosaurQueen)이 정확히 반대다.
#
# 수치의 출처는 SkillData(.tres) 다(docs/vfx-guide.md §1.3).

# 돌진 속도(px/s). **거동값이라 여기 둔다.**
#
# 회피 창은 준비자세 시간(SkillData.cast_time)이 정한다 — 돌진이 시작된 뒤에는 이미 방향이
# 굳어 있어 속도가 회피 가능성을 바꾸지 않는다. 그래서 이 값은 "돌진이 얼마나 빨라 보이는가"
# 쪽에 가깝고, BeamEffect.DURATION 과 같은 자리의 값이다(vfx-guide §1.3 예외).
const CHARGE_SPEED: float = 1400.0

# 도약과 도약 사이의 짧은 정지(초). 공중에 떠 있는 시간은 SkillData.cast_time 이 정한다.
const LEAP_RECOVER: float = 0.15

# 이 보스의 안무. ACT_NONE(0)은 BossEnemyBase 가 "평소"로 예약해 두었다.
enum Act {
	NONE = 0,  # BossEnemyBase.ACT_NONE
	WINDUP,    # 특별 스킬 1 — 준비자세
	CHARGE,    # 특별 스킬 1 — 돌진 중
	LEAP_AIR,  # 특별 스킬 2 — 공중
	LEAP_LAND, # 특별 스킬 2 — 착지 직후 짧은 정지
}

# 돌진 상태
var _charge_direction: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _charge_hit: Array = []

# 도약 상태
var _leaps_left: int = 0
var _leap_target: Vector2 = Vector2.ZERO


# 어느 안무를 쓸지는 스킬 데이터가 정한다 — repeat_count 가 있으면 연속 도약이다.
func _start_skill(skill: SkillData) -> void:
	if skill.repeat_count > 1:
		_begin_leap_sequence(skill)
	else:
		_begin_windup(skill)


# ===== 특별 스킬 1 — 2초 준비 후 직선 돌진 =====

func _begin_windup(skill: SkillData) -> void:
	var target := _resolve_target()
	if target == null:
		_end_act()
		return

	# 방향을 **준비 시작 시점**에 굳힌다. 돌진 순간에 다시 조준하면 유도 돌진이 되어
	# 준비자세 2초가 회피 창이 아니라 그냥 대기 시간이 된다.
	_charge_direction = global_position.direction_to(target.global_position)
	_act = Act.WINDUP
	_act_left = maxf(skill.cast_time, 0.01)

	# 그리는 크기 = 판정 크기(vfx-guide §1.2). 둘 다 SkillData 에서 읽는다.
	var telegraph := _spawn_telegraph()
	if telegraph != null:
		telegraph.setup_beam(global_position, _charge_direction,
			skill.beam_length, skill.beam_width, _act_left)


func _begin_charge() -> void:
	_act = Act.CHARGE
	_charge_left = _skill.beam_length / CHARGE_SPEED
	_charge_hit.clear()


func _tick_charge(delta: float) -> void:
	_charge_left -= delta
	velocity = _charge_direction * CHARGE_SPEED
	move_and_slide()

	# 지나가는 길에 있으면 맞는다. 매 프레임 자리를 다시 보는 이유는 대시와 같다 —
	# 시작·끝점 선분으로 한 번만 잡으면 도중에 경로로 들어온 사람이 통과한다.
	var half := _skill.beam_width * 0.5
	for node in _living_party_members():
		if _charge_hit.has(node):
			continue
		if global_position.distance_to(node.global_position) > half:
			continue
		_charge_hit.append(node)
		_hit_max_hp(node, _skill)

	if _charge_left <= 0.0:
		_end_act()


# ===== 특별 스킬 2 — 3연 도약 내리찍기 =====

func _begin_leap_sequence(skill: SkillData) -> void:
	_leaps_left = skill.repeat_count
	_begin_leap()


func _begin_leap() -> void:
	var target := _resolve_target()
	if target == null:
		_end_act()
		return

	# 착지 지점은 **이 도약이 시작될 때**의 대상 자리다. 도약마다 다시 읽으므로
	# 예고를 보고 움직이면 뒤 타는 피할 수 있다.
	_leap_target = target.global_position
	_act = Act.LEAP_AIR
	_act_left = maxf(_skill.cast_time, 0.01)

	var telegraph := _spawn_telegraph()
	if telegraph != null:
		telegraph.setup_circle(_leap_target, _skill.instant_aoe_radius, _act_left)


func _tick_leap_air(delta: float) -> void:
	# 공중에 뜬 동안 착지 지점으로 옮겨 간다. 남은 시간에 비례해 좁혀 가므로
	# 착지 순간에 정확히 그 자리에 선다.
	var t: float = 1.0 - clampf(_act_left / maxf(_skill.cast_time, 0.01), 0.0, 1.0)
	global_position = global_position.lerp(_leap_target, minf(t * delta * 12.0, 1.0))

	if _act_left <= 0.0:
		_land()


# 착지. **지금 이 순간** 원 안에 있는 대상만 맞는다 — 예고 밖으로 나갔으면 맞지 않는다.
func _land() -> void:
	global_position = _leap_target
	for node in _living_party_members():
		if _leap_target.distance_to(node.global_position) <= _skill.instant_aoe_radius:
			_hit_max_hp(node, _skill)

	_leaps_left -= 1
	_act = Act.LEAP_LAND
	_act_left = LEAP_RECOVER


# ===== 진행 =====

func _tick_act(delta: float) -> void:
	match _act:
		Act.WINDUP:
			velocity = Vector2.ZERO
			if _act_left <= 0.0:
				_begin_charge()
		Act.CHARGE:
			_tick_charge(delta)
		Act.LEAP_AIR:
			_tick_leap_air(delta)
		Act.LEAP_LAND:
			velocity = Vector2.ZERO
			if _act_left <= 0.0:
				if _leaps_left > 0:
					_begin_leap()
				else:
					_end_act()
		_:
			_end_act()


func _end_act() -> void:
	_leaps_left = 0
	_charge_hit.clear()
	super._end_act()

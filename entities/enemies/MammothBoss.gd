extends EnemyBase
class_name MammothBoss

# 매머드 수인 보스 (#376).
#
# EnemyBase 위에 **체력을 계기로 움직이는 층**을 얹는다. 광역 평타·3타 기절·대시는 전부
# EnemyBase 와 EnemyData 가 가진 일반 기능이라 여기 없다 — 이 스크립트가 갖는 것은
# **특별 스킬 2종의 진행**뿐이다.
#
# 왜 나눴는가: 광역 평타와 대시는 다음 적도 쓸 수 있는 행동이라 데이터로 켜고 끈다.
# 반면 "2초 준비 후 돌진" 과 "3연 도약" 은 이 보스의 안무다. 그것까지 EnemyData 필드로
# 일반화하면 쓰는 적이 하나뿐인 필드가 열 개 늘어난다.
#
# 수치의 출처는 SkillData(.tres) 다. 이 스크립트는 진행만 하고 수치를 다시 적지 않는다
# (docs/vfx-guide.md §1.3).

const TELEGRAPH_SCENE := preload("res://entities/combat/BossTelegraph.tscn")

# 돌진 속도(px/s). **거동값이라 여기 둔다.**
#
# 회피 창은 준비자세 시간(SkillData.cast_time)이 정한다 — 돌진이 시작된 뒤에는 이미 방향이
# 굳어 있어 속도가 회피 가능성을 바꾸지 않는다. 그래서 이 값은 "돌진이 얼마나 빨라 보이는가"
# 쪽에 가깝고, BeamEffect.DURATION 과 같은 자리의 값이다(vfx-guide §1.3 예외).
const CHARGE_SPEED: float = 1400.0

# 도약 한 번이 공중에 떠 있는 시간(초)에 곱하는 값이 아니라, 착지 예고를 띄우는 시간이다.
# 실제 값은 SkillData.cast_time 에서 읽는다 — 이 상수는 도약과 도약 사이의 짧은 정지다.
const LEAP_RECOVER: float = 0.15

# 지금 무엇을 하고 있는가.
enum Act {
	NONE,     # 평소 (EnemyBase 의 추격/평타/대시)
	WINDUP,   # 특별 스킬 1 — 준비자세
	CHARGE,   # 특별 스킬 1 — 돌진 중
	LEAP_AIR, # 특별 스킬 2 — 공중
	LEAP_LAND,# 특별 스킬 2 — 착지 직후 짧은 정지
}

var _act: Act = Act.NONE
var _act_left: float = 0.0
var _skill: SkillData = null

# 아직 지나지 않은 체력 임계선(비율). 큰 것부터 소모한다.
var _thresholds: Array[float] = []
# 다음에 쓸 특별 스킬 인덱스. 임계선을 지날 때마다 돌려 가며 쓴다.
var _skill_cursor: int = 0

# 돌진 상태
var _charge_direction: Vector2 = Vector2.ZERO
var _charge_left: float = 0.0
var _charge_hit: Array = []

# 도약 상태
var _leaps_left: int = 0
var _leap_target: Vector2 = Vector2.ZERO

var _telegraph: Node2D = null


func _ready() -> void:
	super._ready()
	_build_thresholds()


# 75% / 50% / 25% ... 를 만든다. step 이 0 이면 특별 스킬이 없는 적이다.
#
# 큰 것부터 담아 두고 앞에서부터 꺼낸다 — 체력은 줄기만 하므로 순서가 뒤집히지 않는다.
func _build_thresholds() -> void:
	_thresholds.clear()
	if data == null or data.phase_skill_hp_step <= 0.0:
		return
	var step: float = data.phase_skill_hp_step
	var at: float = 1.0 - step
	# 0 이하는 담지 않는다 — 죽는 순간에 스킬이 터져도 볼 사람이 없다.
	while at > 0.0001:
		_thresholds.append(at)
		at -= step


func is_acting() -> bool:
	return _act != Act.NONE


func _physics_process(delta: float) -> void:
	# 특별 스킬 중에는 평타·대시·추격이 겹치지 않는다. 안무가 끊기면 예고가 거짓이 된다.
	if is_acting():
		_tick_act(delta)
		_update_walk_animation()
		return
	super._physics_process(delta)


# 피해를 받은 뒤 임계선을 지났는지 본다.
#
# take_damage 에 거는 이유: 체력이 줄어드는 곳이 여기 하나라, 새 피해 경로가 생겨도
# 자동으로 포함된다(EnemyBase 가 광역·대시·상태 효과 틱을 전부 이리로 보낸다).
func take_damage(amount: int, source = null, ignore_defense: bool = false) -> int:
	var dealt := super.take_damage(amount, source, ignore_defense)
	_maybe_start_phase_skill()
	return dealt


# 지나간 임계선이 있으면 특별 스킬을 시작한다.
#
# 이미 안무 중이면 **소모하지 않고 남겨 둔다** — 돌진 도중에 다음 선을 지났다고 두 안무가
# 겹치면 예고와 실제가 어긋난다. 안무가 끝날 때 다시 본다.
func _maybe_start_phase_skill() -> void:
	if not is_alive or is_acting() or _thresholds.is_empty():
		return
	if data == null or data.phase_skills.is_empty() or max_hp <= 0:
		return

	var ratio := float(hp) / float(max_hp)
	if ratio > _thresholds[0]:
		return

	# 때릴 대상이 없으면 **선을 소모하지 않고** 그대로 둔다.
	#
	# 두 안무 모두 대상 자리를 읽어야 시작할 수 있어서, 대상이 없으면 시작하자마자 끝난다.
	# 그때 선을 소모해 버리면 보스는 특별 스킬을 한 번 잃는다 — 파티가 전부 죽었다가
	# 부활했거나(여신 스킬), 도발 대상이 사라진 프레임에 피해가 들어오는 경우가 그렇다.
	# 다음 피해나 안무 종료 때 다시 본다.
	if _resolve_target() == null:
		return

	# 한 번에 여러 선을 지났으면(큰 피해) 그만큼 소모하되 스킬은 한 번만 쓴다.
	# 남겨 두면 다음 타격 때 몰아서 터져 무슨 일이 일어난 건지 읽히지 않는다.
	while not _thresholds.is_empty() and ratio <= _thresholds[0]:
		_thresholds.remove_at(0)

	var skill: SkillData = data.phase_skills[_skill_cursor % data.phase_skills.size()]
	_skill_cursor += 1
	if skill == null:
		return
	_start_skill(skill)


func _start_skill(skill: SkillData) -> void:
	_skill = skill
	# 대시가 돌던 중이면 멈춘다 — 안무가 시작되면 다른 이동은 없다.
	_dash_left = 0.0
	velocity = Vector2.ZERO

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

	_show_beam_telegraph(skill, _act_left)


func _show_beam_telegraph(skill: SkillData, duration: float) -> void:
	_telegraph = _spawn_telegraph()
	if _telegraph == null:
		return
	# 그리는 크기 = 판정 크기(vfx-guide §1.2). 둘 다 SkillData 에서 읽는다.
	_telegraph.setup_beam(global_position, _charge_direction,
		skill.beam_length, skill.beam_width, duration)


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

	_telegraph = _spawn_telegraph()
	if _telegraph != null:
		_telegraph.setup_circle(_leap_target, _skill.instant_aoe_radius, _act_left)


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


# ===== 공통 =====

# 대상 최대 체력 비례 피해. 방어 적용은 대상의 take_damage 가 한다 —
# 여기서 피해 공식을 다시 쓰지 않는다(SkillData.target_max_hp_damage_percent 주석).
func _hit_max_hp(target: Node, skill: SkillData) -> void:
	if skill.target_max_hp_damage_percent <= 0.0:
		return
	var target_max = target.get("max_hp")
	if target_max == null:
		return
	var damage := int(round(float(target_max) * skill.target_max_hp_damage_percent))
	if damage <= 0:
		return
	_hit_one(target, damage, &"")


func _tick_act(delta: float) -> void:
	if _act_left > 0.0:
		_act_left -= delta

	# 안무 중에 죽거나 CC 에 걸리면 그 자리에서 끊는다. 예고만 남아 있으면
	# 오지 않을 공격을 피하게 되고, 기절한 보스가 돌진하면 CC 가 의미를 잃는다.
	if not is_alive or StatusEffectSystem.blocks_movement(self):
		_end_act()
		return

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
	_act = Act.NONE
	_act_left = 0.0
	_skill = null
	_leaps_left = 0
	_charge_hit.clear()
	velocity = Vector2.ZERO
	_clear_telegraph()
	# 안무 중에 지나간 선이 남아 있을 수 있다. 여기서 이어 받는다.
	_maybe_start_phase_skill()


func _spawn_telegraph() -> Node2D:
	_clear_telegraph()
	# 부모는 전장이다(vfx-guide §1.7). 보스의 자식으로 붙이면 보스가 움직일 때
	# 착지 예고가 따라다녀 예고가 아니게 된다.
	var host := get_parent()
	if host == null:
		return null
	var node := TELEGRAPH_SCENE.instantiate()
	host.add_child(node)
	return node


func _clear_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.cancel()
	_telegraph = null


func die() -> void:
	_clear_telegraph()
	super.die()

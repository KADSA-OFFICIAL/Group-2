extends EnemyBase
class_name BossEnemyBase

# 보스 공용 뼈대 (#391). EnemyBase 위에 **체력을 계기로 움직이는 층**을 얹는다.
#
# 여기 있는 것 (보스가 다 같이 쓰는 것):
#   - 체력 임계선 생성·소모 (EnemyData.phase_skill_hp_step / phase_skills)
#   - 안무 상태기계의 뼈대 — 진행 중에는 평타·대시·추격이 멈추고, CC·사망이면 끊긴다
#   - 예고(BossTelegraph) 스폰·정리
#   - 대상 최대 체력 비례 피해
#
# 여기 **없는** 것 (보스마다 다른 것):
#   - 실제 안무. `_start_skill()` 과 `_tick_act()` 를 상속받는 쪽이 채운다.
#
# 왜 나눴는가: 이 층은 #376 에서 MammothBoss 에만 있었다. 여왕(#391)에 같은 것을 다시 쓰면
# 임계선 규칙이 두 벌이 되어 한쪽만 고쳐지는 순간이 온다(CLAUDE.md 단일 출처).
# 안무까지 여기로 올리지는 않는다 — 보스마다 다른 것을 공통 필드로 일반화하면
# 쓰는 보스가 하나뿐인 상태가 늘어난다.
#
# 수치의 출처는 SkillData(.tres) 다. 이 층은 진행만 하고 수치를 다시 적지 않는다
# (docs/vfx-guide.md §1.3).

const TELEGRAPH_SCENE := preload("res://entities/combat/BossTelegraph.tscn")

# 지금 안무 중인가. 0 은 "평소"(EnemyBase 의 추격/평타/대시)를 뜻하고,
# 그 위의 값은 상속받는 쪽이 자기 enum 으로 정의한다.
const ACT_NONE: int = 0

var _act: int = ACT_NONE
var _act_left: float = 0.0
var _skill: SkillData = null

# 아직 지나지 않은 체력 임계선(비율). 큰 것부터 소모한다.
var _thresholds: Array[float] = []
# 다음에 쓸 특별 스킬 인덱스. 임계선을 지날 때마다 돌려 가며 쓴다.
var _skill_cursor: int = 0

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
	return _act != ACT_NONE


func _physics_process(delta: float) -> void:
	# 안무 중에는 평타·대시·추격이 겹치지 않는다. 안무가 끊기면 예고가 거짓이 된다.
	if is_acting():
		_tick_act_common(delta)
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
# 이미 안무 중이면 **소모하지 않고 남겨 둔다** — 안무 도중에 다음 선을 지났다고 두 안무가
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
	# 안무는 대상 자리를 읽어야 시작할 수 있어서, 대상이 없으면 시작하자마자 끝난다.
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

	_skill = skill
	# 대시가 돌던 중이면 멈춘다 — 안무가 시작되면 다른 이동은 없다.
	_dash_left = 0.0
	velocity = Vector2.ZERO
	_start_skill(skill)


# 안무를 시작한다. **상속받는 쪽이 채운다.**
func _start_skill(_skill_data: SkillData) -> void:
	_end_act()


# 안무 한 틱. **상속받는 쪽이 채운다.** _act / _act_left 는 이미 갱신된 뒤다.
func _tick_act(_delta: float) -> void:
	_end_act()


# 모든 보스가 같이 지키는 부분만 여기서 처리하고 나머지는 넘긴다.
func _tick_act_common(delta: float) -> void:
	if _act_left > 0.0:
		_act_left -= delta

	# 안무 중에 죽거나 CC 에 걸리면 그 자리에서 끊는다. 예고만 남아 있으면
	# 오지 않을 공격을 피하게 되고, 기절한 보스가 돌진하면 CC 가 의미를 잃는다.
	if not is_alive or StatusEffectSystem.blocks_movement(self):
		_end_act()
		return

	_tick_act(delta)


# 안무를 끝내고 평소로 돌아간다. 상속받는 쪽은 자기 상태를 지운 뒤 super 를 부른다.
func _end_act() -> void:
	_act = ACT_NONE
	_act_left = 0.0
	_skill = null
	velocity = Vector2.ZERO
	_clear_telegraph()
	# 안무 중에 지나간 선이 남아 있을 수 있다. 여기서 이어 받는다.
	_maybe_start_phase_skill()


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


func _spawn_telegraph() -> Node2D:
	_clear_telegraph()
	# 부모는 전장이다(vfx-guide §1.7). 보스의 자식으로 붙이면 보스가 움직일 때
	# 예고가 따라다녀 예고가 아니게 된다.
	var host := get_parent()
	if host == null:
		return null
	var node := TELEGRAPH_SCENE.instantiate()
	host.add_child(node)
	_telegraph = node
	return node


func _clear_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.cancel()
	_telegraph = null


func die() -> void:
	_clear_telegraph()
	super.die()

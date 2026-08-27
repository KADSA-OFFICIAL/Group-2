extends Node2D
class_name CaptureZone

# 거점 존의 런타임 (#377). 저작된 CaptureZoneData 하나를 전장에 세운 것이다.
#
# 책임 둘:
#   1. **누가 안에 있는지** 판정한다(파티원 / 적).
#   2. 그 결과로 **진행도**를 올리거나 내린다.
#
# 하지 않는 것:
#   - 승패를 판정하지 않는다. 그것은 이미 승패를 판정하는 전장(Stage)의 일이고,
#     이쪽은 "이 존이 확보됐는가"까지만 답한다.
#   - 수치를 만들지 않는다. 확보 시간은 CaptureZoneData(-> CombatTuning), 감소 배수는 CombatTuning 이 출처다.
#
# 규칙 (#377 에서 확정, 설계 §5.2 의 [미정] 파라미터):
#   보완    — 존 안에 **살아 있는 적**이 있으면 진행이 멈춘다(줄지는 않는다).
#             전장 전체가 아니라 존 안의 적만 본다 — 그래야 점령이 소탕의 사족이 되지 않는다.
#   다툼    — 파티원이 있으면 차고, 아무도 없으면 **차는 속도 x capture_decay_multiplier** 로 줄어든다.
#   인원 무관 — 한 명이든 셋이든 같은 속도다. 전장을 나눠 쓸 여지를 남긴다.
#
# 왜 Area2D 를 쓰지 않는가: AuraZone(#334)·Projectile·Shockwave 와 같은 이유다.
# 이 프로젝트는 충돌 레이어를 분리하지 않아 Area2D 로 잡으면 엉뚱한 것까지 반응하고,
# 레이어 설정에 의존하면 헤드리스로 검증할 수 없다. 그룹 순회 + 거리 판정이 기존 방식이다.
#
# 참고: entities/combat/AuraZone.gd, stage/Stage1_1.gd, docs/combat-screen-design.md §5·§6

# 전장에 놓인 존을 밖에서 찾는 이름의 단일 출처. HUD·전장이 이 그룹으로 조회한다
# (적을 GameManager 에 묻는 것과 같은 모양이고, 새 autoload 를 만들지 않는다).
const GROUP := &"capture_zone"

# 표시 색. 확보 전/후를 구분한다.
const COLOR_NEUTRAL := Color(0.85, 0.75, 0.45, 0.9)
const COLOR_CAPTURED := Color(0.45, 0.8, 0.5, 0.95)
const COLOR_CONTESTED := Color(0.85, 0.35, 0.3, 0.95)

# 진행도 호(arc)를 그릴 때의 분할 수. 값이 작으면 각져 보인다.
const ARC_SEGMENTS: int = 48

var data: CaptureZoneData = null

# 확보까지 채워야 하는 시간(초)과 지금까지 채운 시간.
var _hold_seconds: float = 0.0
var _held: float = 0.0

# 이번 프레임의 점유 상태. 표시와 조회가 같은 값을 보게 캐시한다.
var _party_inside: int = 0
var _enemies_inside: int = 0


func _ready() -> void:
	add_to_group(GROUP)


# 스폰 직후 한 번 호출한다. 저작 데이터가 없으면 존이 성립하지 않으므로 스스로 사라진다.
func setup(zone: CaptureZoneData) -> void:
	data = zone
	if data == null:
		push_warning("CaptureZone: data가 없습니다. 존을 세우지 않습니다.")
		queue_free()
		return
	position = data.position
	_hold_seconds = data.get_hold_seconds()
	_held = 0.0
	queue_redraw()


# ===== 조회 (Query) =====

func is_captured() -> bool:
	return _hold_seconds > 0.0 and _held >= _hold_seconds


# 0~1. HUD 가 게이지로 그린다.
func get_progress_ratio() -> float:
	if _hold_seconds <= 0.0:
		return 0.0
	return clampf(_held / _hold_seconds, 0.0, 1.0)


# 존 안에 적이 있어 진행이 멈춰 있는가.
func is_contested() -> bool:
	return _enemies_inside > 0


func get_party_inside() -> int:
	return _party_inside


func get_enemies_inside() -> int:
	return _enemies_inside


# ===== 진행 (Tick) =====

func _physics_process(delta: float) -> void:
	if data == null or _hold_seconds <= 0.0:
		return

	_party_inside = _count_inside(get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP))
	_enemies_inside = _count_inside(GameManager.get_all_enemies())

	var before := _held

	if _enemies_inside > 0:
		# 보완 규칙: 지키는 적이 있는 동안은 아무 일도 일어나지 않는다.
		pass
	elif _party_inside > 0:
		# 인원 수는 속도에 영향을 주지 않는다(#377).
		_held = minf(_held + delta, _hold_seconds)
	else:
		var decay: float = maxf(CombatConfig.tuning.capture_decay_multiplier, 0.0)
		_held = maxf(_held - delta * decay, 0.0)

	if not is_equal_approx(before, _held):
		# 확보되는 순간 한 번만 알린다. 연출·소리는 이 신호를 듣는다.
		if before < _hold_seconds and _held >= _hold_seconds:
			EventBus.capture_zone_captured.emit(self)
		queue_redraw()


# 살아 있고 반경 안에 있는 노드 수. 죽은 파티원·죽은 적은 세지 않는다.
#
# 유효성 검사가 캐스팅보다 먼저다(#370): 해제된 객체는 `as` 로 걸러지지 않는다.
func _count_inside(nodes: Array) -> int:
	var n := 0
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		var body := node as Node2D
		if body == null:
			continue
		var alive = body.get("is_alive")
		if alive != null and not bool(alive):
			continue
		if global_position.distance_to(body.global_position) <= data.radius:
			n += 1
	return n


# ===== 표시 (Draw) =====
#
# 전장에 그린다(HUD 가 아니다) — 존은 화면 좌표가 아니라 **전장의 자리**이기 때문이다.
# HUD 는 같은 값을 숫자로 한 번 더 보여 준다.
func _draw() -> void:
	if data == null:
		return

	var color := COLOR_NEUTRAL
	if is_captured():
		color = COLOR_CAPTURED
	elif is_contested():
		color = COLOR_CONTESTED

	# 존 경계.
	draw_arc(Vector2.ZERO, data.radius, 0.0, TAU, ARC_SEGMENTS, color, 3.0, false)

	# 진행도: 12시부터 시계 방향으로 채우는 굵은 호.
	var ratio := get_progress_ratio()
	if ratio > 0.0:
		var start := -PI * 0.5
		draw_arc(Vector2.ZERO, data.radius - 6.0, start, start + TAU * ratio,
			ARC_SEGMENTS, color, 6.0, false)

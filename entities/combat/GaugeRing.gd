extends Node2D
class_name GaugeRing

# capability가 공개한 게이지 비율을 대상 발밑에 보여 주는 순수 연출 노드(#303).
# 스킬 반경·보호막 수치를 여기서 다시 계산하면 데이터와 표시가 따로 변한다.

const RADIUS: float = 28.0
const RING_WIDTH: float = 2.0
const ARC_POINTS: int = 64
const START_ANGLE: float = -PI * 0.5
const TRACK_ALPHA: float = 0.22
const FULL_FLASH_DURATION: float = 0.24
const BRIGHTEN_PARAMETER: StringName = &"brighten"
const HIGHLIGHT_PARAMETER: StringName = &"highlight_color"
const FULL_SHADER: Shader = preload("res://entities/combat/gauge_ring.gdshader")

var _target: Node2D = null
var _ratio: float = -1.0
var _tint: Color = UITheme.CREAM
var _was_full: bool = false
var _full_flash_left: float = 0.0
var _flash_material: ShaderMaterial = null


func _ready() -> void:
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = FULL_SHADER
	_flash_material.set_shader_parameter(BRIGHTEN_PARAMETER, 0.0)
	_flash_material.set_shader_parameter(HIGHLIGHT_PARAMETER, UITheme.CREAM)
	material = _flash_material
	set_process(false)


func setup(target: Node2D) -> void:
	if target == null or not target.has_method("has_skill_gauge") or not target.has_method("get_skill_gauge_ratio"):
		queue_free()
		return
	if not bool(target.call("has_skill_gauge")):
		queue_free()
		return
	var data: CharacterData = target.get("data") as CharacterData
	if data == null:
		queue_free()
		return

	_target = target
	_tint = data.tint
	_ratio = clampf(float(_target.call("get_skill_gauge_ratio")), 0.0, 1.0)
	_was_full = is_equal_approx(_ratio, 1.0)
	global_position = _target.global_position
	queue_redraw()
	set_process(true)


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	if not _target.has_method("has_skill_gauge") or not bool(_target.call("has_skill_gauge")):
		queue_free()
		return

	# 스테이지의 sibling이라 대상 수명에 묶이지 않으면서 transform만 따라간다(#303).
	# 위치 변화는 CanvasItem transform이 처리하므로 arc를 다시 그릴 필요가 없다.
	global_position = _target.global_position
	var new_ratio: float = clampf(float(_target.call("get_skill_gauge_ratio")), 0.0, 1.0)
	if not is_equal_approx(new_ratio, _ratio):
		_ratio = new_ratio
		var is_full: bool = is_equal_approx(_ratio, 1.0)
		if is_full and not _was_full:
			_start_full_flash()
		_was_full = is_full
		queue_redraw()

	_update_full_flash(delta)


func _start_full_flash() -> void:
	_full_flash_left = FULL_FLASH_DURATION
	_flash_material.set_shader_parameter(BRIGHTEN_PARAMETER, 1.0)


func _update_full_flash(delta: float) -> void:
	if _full_flash_left <= 0.0:
		return
	_full_flash_left = maxf(_full_flash_left - delta, 0.0)
	var amount: float = _full_flash_left / FULL_FLASH_DURATION
	_flash_material.set_shader_parameter(BRIGHTEN_PARAMETER, amount)


func _draw() -> void:
	# 상태 링은 최대 22px다. 28px 바깥 호를 써 두 정보가 한 덩어리로 합쳐지지 않게 한다(#303).
	var track: Color = _tint
	track.a = TRACK_ALPHA
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, ARC_POINTS, track, RING_WIDTH)
	if _ratio <= 0.0:
		return
	var end_angle: float = START_ANGLE + TAU * _ratio
	var point_count: int = maxi(2, int(ceil(float(ARC_POINTS) * _ratio)))
	draw_arc(Vector2.ZERO, RADIUS, START_ANGLE, end_angle, point_count, _tint, RING_WIDTH)

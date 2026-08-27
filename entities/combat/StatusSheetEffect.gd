extends SpriteSheetEffect
class_name StatusSheetEffect

# 상태 효과의 실제 제거 신호를 따라가는 시트 연출. 별도 타이머를 두지 않아 상태가 정화되거나
# 대상이 사라져도 화면에 잔상이 남지 않는다(#401).

var _target: Node = null
var _effect_id: StringName = &""


static func attach(
		target: Node2D,
		effect_id: StringName,
		sheet: Texture2D,
		frame_count: int,
		loop_start: int,
		offset: Vector2 = Vector2.ZERO,
		world_size: Vector2 = Vector2.ZERO,
		frames_per_second: float = 12.0
) -> StatusSheetEffect:
	if target == null or effect_id == &"" or sheet == null:
		return null
	var node_name := StringName("StatusSheet_%s" % String(effect_id))
	var existing := target.get_node_or_null(NodePath(String(node_name))) as StatusSheetEffect
	if existing != null:
		existing.position = offset
		existing.setup(sheet, frame_count, frames_per_second, world_size, loop_start)
		return existing

	var effect := StatusSheetEffect.new()
	effect.name = node_name
	effect._target = target
	effect._effect_id = effect_id
	target.add_child(effect)
	effect.position = offset
	effect.setup(sheet, frame_count, frames_per_second, world_size, loop_start)
	return effect


func _ready() -> void:
	if not EventBus.status_effect_removed.is_connected(_on_status_effect_removed):
		EventBus.status_effect_removed.connect(_on_status_effect_removed)


func _exit_tree() -> void:
	if EventBus.status_effect_removed.is_connected(_on_status_effect_removed):
		EventBus.status_effect_removed.disconnect(_on_status_effect_removed)


func _on_status_effect_removed(target: Variant, effect_id: StringName) -> void:
	if target == _target and effect_id == _effect_id:
		queue_free()

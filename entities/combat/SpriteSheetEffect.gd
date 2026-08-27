extends Sprite2D
class_name SpriteSheetEffect

# 판정과 상태 수명은 스킬 코드가 소유한다. 이 노드는 균등 가로 시트를 재생하고 끝나면 정리하는
# 공용 시각 어댑터일 뿐이며 피해·회복·상태를 다시 적용하지 않는다(#399).

var _frame_count: int = 1
var _frames_per_second: float = 12.0
var _loop_start: int = -1
var _elapsed: float = 0.0


func setup(
		sheet: Texture2D,
		frame_count: int,
		frames_per_second: float = 12.0,
		world_size: Vector2 = Vector2.ZERO,
		loop_start: int = -1
) -> void:
	texture = sheet
	_frame_count = maxi(frame_count, 1)
	_frames_per_second = maxf(frames_per_second, 0.01)
	_loop_start = loop_start if loop_start >= 0 and loop_start < _frame_count else -1
	_elapsed = 0.0
	hframes = _frame_count
	frame = 0
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	if texture != null and world_size.x > 0.0 and world_size.y > 0.0:
		var source_size := Vector2(
			float(texture.get_width()) / float(_frame_count),
			float(texture.get_height())
		)
		scale = Vector2(world_size.x / source_size.x, world_size.y / source_size.y)

	set_process(texture != null)


func _process(delta: float) -> void:
	_elapsed += delta
	var next_frame: int = floori(_elapsed * _frames_per_second)
	if next_frame < _frame_count:
		frame = next_frame
		return

	if _loop_start < 0:
		queue_free()
		return

	var loop_length: int = _frame_count - _loop_start
	frame = _loop_start + posmod(next_frame - _loop_start, loop_length)

extends Node2D
class_name GrasslandAmbient

# 초원 앰비언트. 풀·홀씨·구름 그림자는 모두 좌→우로 흐른다(#352).

const MAP_PIXELS := Vector2(1536, 960)
const MOTE_COLOR := Color("DCCDAF")
const CLOUD_COLOR := Color(0.18, 0.16, 0.14, 0.15)

var _elapsed := 0.0
var _motes := [
	Vector2(120, 150), Vector2(360, 520), Vector2(610, 220), Vector2(820, 680),
	Vector2(1050, 330), Vector2(1280, 760), Vector2(1450, 470),
]


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var cloud_x := fmod(_elapsed * 18.0, MAP_PIXELS.x + 600.0) - 300.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(cloud_x - 260, 120), Vector2(cloud_x + 220, 40),
		Vector2(cloud_x + 340, 260), Vector2(cloud_x - 180, 340),
	]), CLOUD_COLOR)
	for i in _motes.size():
		var base: Vector2 = _motes[i]
		var x := fmod(base.x + _elapsed * (16.0 + float(i % 3) * 4.0), MAP_PIXELS.x)
		var y := base.y + sin(_elapsed * 1.3 + float(i)) * 12.0
		var mote := MOTE_COLOR
		mote.a = 0.58
		draw_circle(Vector2(x, y), 2.0, mote)

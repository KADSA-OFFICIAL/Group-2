extends Node2D
class_name SkyClouds

# 하늘 맵의 구름 (#423).
#
# **왜 타일이 아닌가**: 처음에는 구름을 Ground 의 24px 타일로 깔았다. 그러면 구름 하나가
# 타일 경계에서 잘리고, 타일마다 같은 타원이 반복되어 **흰 벽돌 부스러기**처럼 보였다
# (미리보기에서 드러났다). 구름은 24px 격자보다 훨씬 크고 테두리가 부드러워야 한다.
# 그래서 맵 전체를 한 캔버스로 두고 여기서 직접 그린다.
#
# 섬(Overlay, z=-4)보다 **아래**에 있어야 한다 — 구름이 섬 위를 덮으면 발밑이 흐려진다.
# 그래서 씬에서 z_index = -5 이고 Ground 를 -6 으로 내렸다.
#
# 참고: stage/grassland/GrasslandAmbient.gd (같은 방식의 앰비언트 드로잉)

# 맵 크기의 출처는 SkyIslandMap 이다. 여기에 숫자를 다시 적으면 맵을 넓힐 때 어긋난다.
var _map_pixels: Vector2 = Vector2(
	SkyIslandMap.MAP_SIZE.x * SkyIslandMap.TILE_SIZE,
	SkyIslandMap.MAP_SIZE.y * SkyIslandMap.TILE_SIZE)

# 알파를 낮게 둔다. 겹치는 덩어리들이 같은 알파로 진하면 겹친 자리마다 **원 자국**이
# 남아 구름이 비눗방울 뭉치처럼 보인다(미리보기에서 드러났다). 옅게 여러 겹 쌓으면
# 겹침이 누적되어 안쪽이 자연히 짙어지고 테두리가 흐려진다.
const CLOUD_CORE := Color(0.90, 0.94, 0.98, 0.10)
const CLOUD_EDGE := Color(0.84, 0.89, 0.95, 0.05)

# 구름 하나 = {위치 비율, 크기, 속도}. 비율로 두어 맵이 넓어져도 분포가 유지된다.
const CLOUDS := [
	{ "at": Vector2(0.12, 0.18), "size": Vector2(300, 90), "speed": 7.0 },
	{ "at": Vector2(0.55, 0.10), "size": Vector2(380, 110), "speed": 5.0 },
	{ "at": Vector2(0.82, 0.30), "size": Vector2(260, 80), "speed": 9.0 },
	{ "at": Vector2(0.30, 0.48), "size": Vector2(420, 120), "speed": 4.0 },
	{ "at": Vector2(0.70, 0.62), "size": Vector2(340, 100), "speed": 8.0 },
	{ "at": Vector2(0.18, 0.78), "size": Vector2(390, 115), "speed": 6.0 },
	{ "at": Vector2(0.60, 0.88), "size": Vector2(300, 90), "speed": 10.0 },
]

var _elapsed := 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	for i in CLOUDS.size():
		var cloud: Dictionary = CLOUDS[i]
		var at: Vector2 = cloud["at"]
		var size: Vector2 = cloud["size"]
		var speed: float = cloud["speed"]

		# 좌->우로 흐르고 맵 밖으로 나가면 반대편에서 다시 들어온다.
		# 여유(size.x)를 둬야 구름이 화면 끝에서 튀어나오지 않는다.
		var span := _map_pixels.x + size.x * 2.0
		var x := fmod(at.x * _map_pixels.x + _elapsed * speed + size.x, span) - size.x
		var center := Vector2(x, at.y * _map_pixels.y)

		_draw_cloud(center, size, i)


const LOBES := 11

# 덩어리 여러 개를 옅게 겹쳐 하나의 구름을 만든다. 타원 하나면 알약처럼 보인다.
# 세 겹으로 쌓는다: 넓고 아주 옅은 바깥, 중간, 좁은 안쪽. 이러면 가장자리가
# 흐려지고 안쪽만 짙어져 뭉게구름처럼 읽힌다.
func _draw_cloud(center: Vector2, size: Vector2, salt: int) -> void:
	for pass_index in 3:
		# 바깥 -> 안쪽으로 좁아지고 진해진다.
		var spread := 1.35 - float(pass_index) * 0.28
		var color := CLOUD_EDGE if pass_index == 0 else CLOUD_CORE
		for i in LOBES:
			var t := float(i) / float(LOBES - 1)
			# 덩어리 높이를 hash 로 흔든다. 규칙적인 아치는 부채처럼 보인다.
			var lift := sin(t * PI) * -size.y * 0.28
			var wobble := float((_hash_cell(salt, i, 19) % 9) - 4) * size.y * 0.035
			var offset := Vector2((t - 0.5) * size.x, lift + wobble)
			var radius := Vector2(
				size.x * (0.22 - absf(t - 0.5) * 0.10),
				size.y * (0.55 - absf(t - 0.5) * 0.22))
			draw_colored_polygon(_ellipse(center + offset, radius * spread), color)


func _hash_cell(x: int, y: int, salt: int) -> int:
	var value := x * 374761393 + y * 668265263 + salt * 69069
	value = (value ^ (value >> 13)) * 1274126177
	return absi(value ^ (value >> 16))


func _ellipse(center: Vector2, radius: Vector2, steps: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points

extends Control
class_name OrderYard

# 본거지 뜰. 교단 화면 가운데에 들어간다.
#
# 보여 주는 것: 하늘·땅, 저작된 건물, 그 사이를 돌아다니는 신도들.
# 건물을 누르면 그 기능 화면이 열린다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   건물 목록·자리·연결 화면 -> OrderSystem.get_buildings() (data/order/buildings/*.tres)
#   신도 명부                -> CharacterDatabase.get_playable_ids()
#   외형(워크 시트·도형·색)  -> CharacterData
#   방향 애니메이션 규약     -> WalkAnimation (전투와 같은 규약을 쓴다)
#   색                       -> UITheme / HUDKit
#
# 좌표를 픽셀로 들지 않는다: 건물 자리도 인물 위치도 **뜰 크기 대비 비율**이다.
# 창 크기가 바뀌어도 같은 자리에 그대로 있어야 한다.

# 지평선. 이 비율 위쪽이 하늘, 아래쪽이 땅이다.
const HORIZON: float = 0.34

# ===== 장소로 보이게 하는 값들 (#313) =====
#
# 이 뜰이 UI 패널이 아니라 **장소**로 읽히려면 넷이 필요하다:
# 땅에 붙어 있을 것(그림자), 멀수록 옅을 것(대기 원근), 뜰 너머가 있을 것(능선),
# 사람이 다닌 자국이 있을 것(마당).

# 하늘·땅 그라데이션을 몇 겹으로 쪼개 그릴지. 많을수록 매끄럽지만 그릴 것이 는다.
const GRADIENT_BANDS: int = 40

# 먼 능선의 높이(뜰 세로 대비)와 봉우리 수. 둘을 겹쳐 그려 깊이를 만든다.
const RIDGE_FAR_HEIGHT: float = 0.085
const RIDGE_NEAR_HEIGHT: float = 0.055
const RIDGE_SEGMENTS: int = 48

# 다져진 마당. 건물이 모인 가운데가 밟혀서 풀이 없어진 자리다.
const PLAZA_CENTER := Vector2(0.5, 0.72)
const PLAZA_RADIUS := Vector2(0.42, 0.20)

# 그림자. 바닥에 눕는 타원이라 세로가 훨씬 납작하다.
const SHADOW_SEGMENTS: int = 20
const SHADOW_FLATNESS: float = 0.26      # 세로/가로 비
const SHADOW_ALPHA_NEAR: float = 0.26
const SHADOW_ALPHA_FAR: float = 0.14     # 멀수록 옅다(빛이 퍼진다)

# 건물 그림자 폭(건물 폭 대비). 발치보다 조금 넓게 깔려야 땅에 앉은 것으로 보인다.
const BUILDING_SHADOW_WIDTH: float = 0.62

# 신도 그림자 폭(신도 그림 폭 대비).
const MEMBER_SHADOW_WIDTH: float = 0.52

# 건물 플레이스홀더의 집 모양 비율.
const ROOF_RATIO: float = 0.34        # 전체 높이 중 지붕이 차지하는 몫
const EAVES_RATIO: float = 0.07       # 처마가 벽 밖으로 나온 폭
const DOOR_WIDTH_RATIO: float = 0.30
const DOOR_HEIGHT_RATIO: float = 0.42

# 신도는 앞으로 올수록 커진다. 건물은 **저작된 크기를 지킨다** — 원근으로 줄이면
# 데이터가 잡은 구도가 무너진다(data/order/README.md 의 width_ratio 가 정본이다).
const MEMBER_DEPTH_MIN: float = 0.82

# 인물이 걸어 다닐 수 있는 세로 범위(비율).
# 하늘 위를 걸으면 안 되고, 맨 아래는 발이 잘리므로 조금 띄운다.
# 건물이 선 자리를 피해 앞마당에서만 걷는다. 인물이 건물 위로 겹쳐 지나가면
# 어느 쪽이 앞인지 알 수 없어 그림이 뭉개진다.
const WALK_TOP: float = 0.80
const WALK_BOTTOM: float = 0.95

# 인물 이동 속도(뜰 가로 대비 초당 비율). 전투가 아니라 산책이라 느리다.
const WANDER_SPEED: float = 0.05

# 목적지에 이만큼(비율) 안으로 들어오면 도착으로 본다.
const ARRIVE_EPSILON: float = 0.012

# 도착 후 쉬는 시간(초) 범위.
const REST_MIN: float = 0.8
const REST_MAX: float = 3.0

# 인물 그림 높이(뜰 세로 대비). 워크 시트 원본이 커서 여기서 줄인다.
const MEMBER_HEIGHT: float = 0.14

# 워크 시트가 없는 인물이 쓰는 도형 높이(뜰 세로 대비).
const SHAPE_HEIGHT: float = 0.09


# 뜰을 돌아다니는 사람 하나.
class Wanderer:
	extends RefCounted

	var node: Node2D                          # 그림을 그리는 노드
	var animated: AnimatedSprite2D = null     # 워크 시트가 있을 때만
	var spot: Vector2 = Vector2.ZERO          # 지금 자리 (비율)
	var target: Vector2 = Vector2.ZERO        # 가려는 자리 (비율)
	var rest_left: float = 0.0


var _scenery: Control         # 하늘·땅·능선·마당을 직접 그리는 층
var _shadows: Control         # 건물·신도의 바닥 그림자
var _yard_layer: Control      # 건물·인물이 올라가는 자리
var _members: Array = []      # Wanderer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	# 뜰 밖으로 인물이 삐져나가지 않게 한다.
	clip_contents = true
	_build()
	resized.connect(_layout)


func _build() -> void:
	# 하늘·땅·능선·마당은 색판을 겹치지 않고 한 층이 직접 그린다.
	#
	# 예전에는 ColorRect 세 장(하늘·땅·지평선 3px)이었는데, 단색 두 판과 검은 선은
	# 자연물에 없는 형태라 화면이 **장소가 아니라 패널 두 개**로 읽혔다(#313).
	_scenery = Control.new()
	_scenery.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scenery.draw.connect(_draw_scenery)
	add_child(_scenery)

	# 그림자는 건물·신도보다 **아래**, 땅보다 위에 있어야 한다.
	# 한 층이 전부 그린다 — 그림자마다 노드를 두면 신도가 움직일 때마다 노드를
	# 따라 옮겨야 하고, 순서가 어긋나면 남의 그림자 위에 올라선다.
	_shadows = Control.new()
	_shadows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shadows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadows.draw.connect(_draw_shadows)
	add_child(_shadows)

	_yard_layer = Control.new()
	_yard_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_yard_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_yard_layer)

	_spawn_buildings()
	_spawn_members()
	_layout()


# ===== 배경 그리기 (#313) =====

# 하늘 -> 능선 -> 땅 -> 마당 순서로 깐다. 뒤에 있는 것부터 그린다.
func _draw_scenery() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var horizon := h * HORIZON

	# 하늘. 위가 진하고 지평선 쪽이 옅다 — 대기 원근이다. 단색이면 평면으로 읽힌다.
	var sky_high := UITheme.TAN.lerp(UITheme.CREAM, 0.30)
	var sky_low := UITheme.CREAM
	_draw_gradient(_scenery, Rect2(0.0, 0.0, w, horizon), sky_high, sky_low)

	# 먼 능선 둘. 뒤엣것이 더 옅고 높다. 뜰 너머에 무엇이 있어야 공간이 닫힌다.
	var ridge_far := UITheme.SAGE.lerp(UITheme.CREAM, 0.62)
	var ridge_near := UITheme.SAGE.lerp(UITheme.CREAM, 0.34)
	_draw_ridge(_scenery, horizon, h * RIDGE_FAR_HEIGHT, ridge_far, 1.7, 0.0)
	_draw_ridge(_scenery, horizon, h * RIDGE_NEAR_HEIGHT, ridge_near, 2.6, 1.3)

	# 땅. 지평선 쪽이 옅고 앞으로 올수록 진하다.
	var ground_far := UITheme.TAN_DEEP.lerp(UITheme.SAGE, 0.34).lerp(UITheme.CREAM, 0.22)
	var ground_near := UITheme.TAN_DEEP.lerp(UITheme.SAGE, 0.16)
	_draw_gradient(_scenery, Rect2(0.0, horizon, w, h - horizon), ground_far, ground_near)

	# 다져진 마당. 건물이 모인 가운데는 밟혀서 흙이 드러난다.
	# 테두리를 그리지 않는다 — 선이 있으면 땅이 아니라 판으로 보인다.
	var plaza := UITheme.TAN_DEEP.lerp(UITheme.TAN, 0.55)
	plaza.a = 0.55
	_scenery.draw_colored_polygon(
		_ellipse(Vector2(w * PLAZA_CENTER.x, h * PLAZA_CENTER.y),
			w * PLAZA_RADIUS.x, h * PLAZA_RADIUS.y, 36), plaza)


# 건물과 신도의 바닥 그림자. 이것이 없으면 전부 배경 위에 떠 있는 스티커로 보인다.
func _draw_shadows() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	for child in _yard_layer.get_children():
		if not child.has_meta("building"):
			continue
		var building: OrderBuildingData = child.get_meta("building")
		var foot := Vector2(size.x * building.spot.x, size.y * building.spot.y)
		_draw_shadow(foot, size.x * building.width_ratio * BUILDING_SHADOW_WIDTH, building.spot.y)

	for walker in _members:
		var node: Node2D = walker.node
		if node == null or not is_instance_valid(node):
			continue
		var source := _source_size(walker)
		if source.y <= 0.0:
			continue
		var foot := Vector2(size.x * walker.spot.x, size.y * walker.spot.y)
		_draw_shadow(foot, source.x * node.scale.x * MEMBER_SHADOW_WIDTH, walker.spot.y)


# 발치에 눕는 납작한 타원 하나.
# 멀수록 옅게 한다 — 가까운 것과 같은 진하기로 깔면 뒤엣것이 앞으로 튀어나온다.
func _draw_shadow(foot: Vector2, width: float, spot_y: float) -> void:
	if width <= 0.0:
		return
	var depth := clampf((spot_y - HORIZON) / maxf(1.0 - HORIZON, 0.001), 0.0, 1.0)
	var shade := UITheme.OUTLINE
	shade.a = lerpf(SHADOW_ALPHA_FAR, SHADOW_ALPHA_NEAR, depth)
	_shadows.draw_colored_polygon(
		_ellipse(foot, width * 0.5, width * 0.5 * SHADOW_FLATNESS, SHADOW_SEGMENTS), shade)


# 가로 띠를 여러 겹 깔아 세로 그라데이션을 만든다.
# 셰이더를 쓰지 않는 이유: 이 화면에 셰이더가 하나도 없고, 띠 40겹이면 눈으로
# 경계가 보이지 않는다. 셰이더 하나를 위해 재질을 들이는 값이 없다.
func _draw_gradient(on: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	if rect.size.y <= 0.0:
		return
	var band := rect.size.y / float(GRADIENT_BANDS)
	for i in GRADIENT_BANDS:
		var t := float(i) / float(GRADIENT_BANDS - 1)
		# 마지막 띠는 반올림 오차로 생기는 실틈을 덮게 조금 길게 그린다.
		var extra := 1.0 if i == GRADIENT_BANDS - 1 else 1.0
		on.draw_rect(
			Rect2(rect.position.x, rect.position.y + band * float(i),
				rect.size.x, band + extra),
			top.lerp(bottom, t))


# 지평선에 걸치는 능선 하나. 사인 둘을 겹쳐 규칙적으로 안 보이게 한다.
func _draw_ridge(on: CanvasItem, horizon: float, height: float, color: Color,
		frequency: float, phase: float) -> void:
	if height <= 0.0 or size.x <= 0.0:
		return
	var points := PackedVector2Array()
	for i in RIDGE_SEGMENTS + 1:
		var t := float(i) / float(RIDGE_SEGMENTS)
		var x := size.x * t
		var wave := sin(t * TAU * frequency + phase) * 0.6 + sin(t * TAU * frequency * 0.47 + phase * 2.1) * 0.4
		points.append(Vector2(x, horizon - height * (0.45 + 0.55 * (wave * 0.5 + 0.5))))
	# 지평선 아래로 조금 내려 닫는다. 딱 맞춰 닫으면 땅과의 경계에 실틈이 보인다.
	points.append(Vector2(size.x, horizon + 2.0))
	points.append(Vector2(0.0, horizon + 2.0))
	on.draw_colored_polygon(points, color)


# 타원 폴리곤. draw_circle 로는 납작한 그림자를 그릴 수 없다.
func _ellipse(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(a) * radius_x, sin(a) * radius_y))
	return points


# ===== 건물 =====

func _spawn_buildings() -> void:
	# OrderSystem 이 뒤(spot.y 작은 쪽)부터 정렬해 준다. 그 순서로 붙이면
	# 앞에 선 건물이 자연히 위에 온다.
	for building in OrderSystem.get_buildings():
		_yard_layer.add_child(_make_building(building))


func _make_building(building: OrderBuildingData) -> Control:
	var holder := Control.new()
	holder.name = String(building.building_id)
	holder.set_meta("building", building)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if building.art != null:
		var art := TextureRect.new()
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.offset_bottom = -24.0
		art.texture = building.art
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(art)
	else:
		holder.add_child(_make_building_placeholder(building))

	var label := HUDKit.label(building.display_name, 15, UITheme.INK, 700)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -22.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)

	if building.is_enterable():
		var button := Button.new()
		button.flat = true
		button.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.tooltip_text = building.description
		button.pressed.connect(_on_building_pressed.bind(building))
		holder.add_child(button)
		HUDKit.hover_lift(holder, button)

	return holder


# 그림이 없는 건물. 아이콘 + 색으로 "여기가 무엇의 자리"인지 보인다.
#
# 모양은 **집 실루엣**이다(#313). 예전에는 둥근 사각 판이었는데, 판은 아무리 배경을
# 손봐도 마당에 선 건물이 아니라 **마당 위에 얹힌 카드**로 읽혔다.
#
# 여전히 플레이스홀더다 — 팔레트 안의 단색 면과 윤곽선뿐이고 질감도 명암도 없다.
# 어설픈 그림을 흉내 내는 것이 아니라, 같은 플레이스홀더를 **건물 모양**으로 두는 것이다.
# 진짜 그림이 들어올 자리는 그대로 OrderBuildingData.art 다.
func _make_building_placeholder(building: OrderBuildingData) -> Control:
	var shell := Control.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.offset_bottom = -24.0
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.set_meta("building", building)
	shell.draw.connect(_draw_building_shell.bind(shell))

	# 아이콘은 지붕 아래 벽면에 붙는다. 크기는 _layout_buildings() 가 정한다
	# (이 시점에는 뜰 크기가 0 이라 비율로 잡으면 아이콘이 사라진다 — 실제로 사라졌다).
	var margin := MarginContainer.new()
	margin.name = "IconMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.anchor_top = ROOF_RATIO
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(margin)

	var icon := HUDKit.make_icon(building.icon_name, 1)
	if icon != null:
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# 건물이 실루엣만으로 구분되고 나면 아이콘은 "무엇의 자리인지" 알려 주는
		# 표식일 뿐이다. 불투명하게 두면 UI 아이콘이 건물 위에 떠 있는 것으로 보인다.
		# 살짝 눕혀서 벽에 그려 넣은 표식처럼 앉힌다.
		icon.modulate.a = 0.72
		margin.add_child(icon)
	return shell


# 건물 하나를 그 **양식**대로 그린다(#316).
#
# 양식은 데이터가 지시한다(OrderBuildingData.silhouette). building_id 로 분기하면
# 건물을 하나 더할 때마다 이 파일을 고쳐야 한다.
#
# 크기 기준: 뜰 폭의 0.18~0.24 라 실제로는 110~150px 안팎이다. 그 크기에서 뭉개지지
# 않을 만큼만 그린다 — 더 넣으면 얼룩이 된다.
func _draw_building_shell(shell: Control) -> void:
	var w := shell.size.x
	var h := shell.size.y
	if w <= 0.0 or h <= 0.0:
		return

	var building: OrderBuildingData = shell.get_meta("building")
	var p := _palette(building.tint)

	match building.silhouette:
		OrderBuildingData.Silhouette.FORGE:
			_draw_forge(shell, w, h, p)
		OrderBuildingData.Silhouette.SHRINE:
			_draw_shrine(shell, w, h, p)
		OrderBuildingData.Silhouette.STALL:
			_draw_stall(shell, w, h, p)
		OrderBuildingData.Silhouette.GRANARY:
			_draw_granary(shell, w, h, p)
		_:
			_draw_hut(shell, w, h, p)


# 건물 하나가 쓰는 색 한 벌. tint 에서 전부 파생한다 — 새 색을 만들지 않는다.
func _palette(tint: Color) -> Dictionary:
	return {
		"wall": tint,
		"wall_lit": tint.lerp(UITheme.CREAM, 0.22),
		"wall_dim": tint.lerp(UITheme.OUTLINE, 0.20),
		"roof": tint.lerp(UITheme.OUTLINE, 0.44),
		"roof_lit": tint.lerp(UITheme.OUTLINE, 0.28),
		"wood": tint.lerp(UITheme.OUTLINE, 0.58),
		"dark": tint.lerp(UITheme.OUTLINE, 0.78),
		"stone": UITheme.STONE_GRAY,
		"stone_lit": UITheme.STONE_GRAY.lerp(UITheme.CREAM, 0.30),
		"line": UITheme.OUTLINE,
	}


# 윤곽선 두께. 건물이 작아도 선이 사라지지 않게 하한을 둔다.
func _edge(w: float) -> float:
	return maxf(w * 0.016, 1.5)


# 초가 결. 지붕이 단색 삼각형이면 종이로 보인다. 가로 결을 몇 줄 그어 두께를 준다.
func _thatch(on: CanvasItem, top: Vector2, left: Vector2, right: Vector2, color: Color) -> void:
	var rows := 4
	for i in range(1, rows + 1):
		var t := float(i) / float(rows + 1)
		on.draw_line(top.lerp(left, t), top.lerp(right, t), color,
			maxf((right.x - left.x) * 0.012, 1.0))


# 기둥 하나. 나무 기둥은 이 마당의 공통 부재다.
func _post(on: CanvasItem, x: float, y_top: float, y_bottom: float, width: float,
		p: Dictionary, edge: float) -> void:
	var rect := Rect2(x - width * 0.5, y_top, width, y_bottom - y_top)
	on.draw_rect(rect, p["wood"])
	on.draw_rect(rect, p["line"], false, edge)


# 항아리 몇 개. 마당에 물건이 있어야 사람이 쓰는 곳으로 보인다.
func _jars(on: CanvasItem, base: Vector2, unit: float, count: int, p: Dictionary,
		edge: float) -> void:
	for i in count:
		var c := Vector2(base.x + unit * 1.5 * float(i), base.y - unit * 0.5)
		var shape := _ellipse(c, unit * 0.55, unit * 0.62, 12)
		on.draw_colored_polygon(shape, p["stone_lit"])
		on.draw_polyline(_closed(shape), p["line"], edge)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out


# 지붕 마루에서 처마로 흐르는 외쪽지붕의 결.
func _slope_grain(on: CanvasItem, ridge_a: Vector2, ridge_b: Vector2,
		eave_a: Vector2, eave_b: Vector2, color: Color, width: float) -> void:
	for i in range(1, 4):
		var t := float(i) / 4.0
		on.draw_line(ridge_a.lerp(eave_a, t), ridge_b.lerp(eave_b, t), color, width)


# ── 기본 맞배집 (양식 미지정) ──
func _draw_hut(on: CanvasItem, w: float, h: float, p: Dictionary) -> void:
	var edge := _edge(w)
	var roof_h := h * 0.34
	var inset := w * 0.07

	var wall := Rect2(inset, roof_h, w - inset * 2.0, h - roof_h)
	on.draw_rect(wall, p["wall"])
	on.draw_rect(Rect2(wall.position.x, wall.position.y, wall.size.x, wall.size.y * 0.30),
		p["wall_lit"])

	var door_w := wall.size.x * 0.30
	var door_h := wall.size.y * 0.42
	on.draw_rect(Rect2(wall.position.x + (wall.size.x - door_w) * 0.5, h - door_h,
		door_w, door_h), p["dark"])

	var top := Vector2(w * 0.5, 0.0)
	var left := Vector2(0.0, roof_h)
	var right := Vector2(w, roof_h)
	on.draw_colored_polygon(PackedVector2Array([top, right, left]), p["roof"])
	_thatch(on, top, left, right, p["roof_lit"])

	on.draw_rect(wall, p["line"], false, edge)
	on.draw_polyline(PackedVector2Array([left, top, right, left]), p["line"], edge)


# ── 제조소: 옆이 트인 작업장 ──
# 벽을 다 세우지 않는다. 안이 보여야 "작업하는 곳"으로 읽힌다.
func _draw_forge(on: CanvasItem, w: float, h: float, p: Dictionary) -> void:
	var edge := _edge(w)
	var roof_h := h * 0.32

	# 뒷벽(낮다). 트인 앞쪽과 대비되어 안쪽이 있다는 것을 보여 준다.
	var back := Rect2(w * 0.16, roof_h, w * 0.68, (h - roof_h) * 0.58)
	on.draw_rect(back, p["wall_dim"])
	on.draw_rect(back, p["line"], false, edge)

	# 모루 — 이 건물의 정체
	var anvil_w := w * 0.30
	var anvil := Rect2(w * 0.5 - anvil_w * 0.5, h - h * 0.22, anvil_w, h * 0.14)
	on.draw_rect(Rect2(anvil.position.x - w * 0.05, anvil.position.y,
		anvil.size.x + w * 0.10, anvil.size.y * 0.38), p["stone_lit"])
	on.draw_rect(anvil, p["stone"])
	on.draw_rect(anvil, p["line"], false, edge)

	# 앞기둥 둘
	_post(on, w * 0.12, roof_h, h, w * 0.07, p, edge)
	_post(on, w * 0.88, roof_h, h, w * 0.07, p, edge)

	# 외쪽지붕. 맞배가 아니라 한쪽으로 흘러야 작업장으로 보인다.
	var ridge_a := Vector2(w * 0.06, h * 0.04)
	var ridge_b := Vector2(w, h * 0.17)
	var eave_a := Vector2(0.0, roof_h)
	var eave_b := Vector2(w, roof_h)
	var slope := PackedVector2Array([eave_a, ridge_a, ridge_b, eave_b])
	on.draw_colored_polygon(slope, p["roof"])
	_slope_grain(on, ridge_a, ridge_b, eave_a, eave_b, p["roof_lit"], maxf(w * 0.012, 1.0))
	on.draw_polyline(_closed(slope), p["line"], edge)

	# 굴뚝과 연기
	var chimney := Rect2(w * 0.64, h * 0.01, w * 0.13, h * 0.17)
	on.draw_rect(chimney, p["stone"])
	on.draw_rect(chimney, p["line"], false, edge)
	var smoke: Color = p["stone_lit"]
	smoke.a = 0.5
	on.draw_colored_polygon(_ellipse(Vector2(w * 0.71, -h * 0.02), w * 0.10, h * 0.05, 12), smoke)


# ── 성소: 선돌과 상인방 ──
# 이 마당에서 가장 격이 높은 자리다. 나무가 아니라 돌로 짓는다.
func _draw_shrine(on: CanvasItem, w: float, h: float, p: Dictionary) -> void:
	var edge := _edge(w)
	var roof_h := h * 0.26
	var step_h := h * 0.11
	var body_bottom := h - step_h

	# 계단
	var steps := 3
	for i in steps:
		var t := float(i) / float(steps)
		var sw := w * (0.60 + 0.40 * t)
		var r := Rect2(w * 0.5 - sw * 0.5, body_bottom + step_h * t, sw,
			step_h / float(steps) + 1.0)
		on.draw_rect(r, p["stone"] if i % 2 == 0 else p["stone_lit"])
		on.draw_rect(r, p["line"], false, edge * 0.7)

	# 어두운 안쪽 + 선돌 둘
	on.draw_rect(Rect2(w * 0.30, roof_h, w * 0.40, body_bottom - roof_h), p["dark"])
	var pillar_w := w * 0.18
	for x in [w * 0.24, w * 0.76]:
		var taper := PackedVector2Array([
			Vector2(x - pillar_w * 0.42, roof_h),
			Vector2(x + pillar_w * 0.42, roof_h),
			Vector2(x + pillar_w * 0.50, body_bottom),
			Vector2(x - pillar_w * 0.50, body_bottom),
		])
		on.draw_colored_polygon(taper, p["stone"])
		on.draw_polyline(_closed(taper), p["line"], edge)

	# 상인방(가로 돌)
	var lintel := Rect2(w * 0.13, roof_h - h * 0.02, w * 0.74, h * 0.09)
	on.draw_rect(lintel, p["stone_lit"])
	on.draw_rect(lintel, p["line"], false, edge)

	# 처마가 넓은 지붕
	var top := Vector2(w * 0.5, 0.0)
	var left := Vector2(-w * 0.02, roof_h)
	var right := Vector2(w * 1.02, roof_h)
	on.draw_colored_polygon(PackedVector2Array([top, right, left]), p["roof"])
	_thatch(on, top, left, right, p["roof_lit"])
	on.draw_polyline(PackedVector2Array([left, top, right]), p["line"], edge)

	# 처마에 걸린 천
	for x in [w * 0.09, w * 0.91]:
		var cloth := PackedVector2Array([
			Vector2(x - w * 0.045, roof_h), Vector2(x + w * 0.045, roof_h),
			Vector2(x + w * 0.030, roof_h + h * 0.15), Vector2(x - w * 0.030, roof_h + h * 0.15),
		])
		on.draw_colored_polygon(cloth, p["wall_lit"])
		on.draw_polyline(_closed(cloth), p["line"], edge * 0.7)


# ── 상점: 차양을 친 좌판 ──
func _draw_stall(on: CanvasItem, w: float, h: float, p: Dictionary) -> void:
	var edge := _edge(w)
	var awning_y := h * 0.32
	var counter_y := h * 0.66

	_post(on, w * 0.10, awning_y, h, w * 0.06, p, edge)
	_post(on, w * 0.90, awning_y, h, w * 0.06, p, edge)

	# 차양. 가운데가 솟고 양끝이 처진다.
	var awning := PackedVector2Array([
		Vector2(w * 0.02, awning_y), Vector2(w * 0.5, h * 0.03),
		Vector2(w * 0.98, awning_y), Vector2(w * 0.5, awning_y - h * 0.06),
	])
	on.draw_colored_polygon(awning, p["roof"])
	on.draw_polyline(_closed(awning), p["line"], edge)
	# 차양 술
	for i in range(1, 6):
		var t := float(i) / 6.0
		var a := Vector2(w * 0.02, awning_y).lerp(Vector2(w * 0.98, awning_y), t)
		on.draw_line(a, a + Vector2(0.0, h * 0.05), p["roof_lit"], maxf(w * 0.014, 1.0))

	# 판매대
	var counter := Rect2(w * 0.06, counter_y, w * 0.88, h * 0.17)
	on.draw_rect(counter, p["wall"])
	on.draw_rect(Rect2(counter.position.x, counter.position.y, counter.size.x,
		counter.size.y * 0.34), p["wall_lit"])
	on.draw_rect(counter, p["line"], false, edge)

	# 늘어놓은 물건
	for i in 5:
		on.draw_colored_polygon(_ellipse(
			Vector2(w * (0.16 + 0.17 * float(i)), counter_y - h * 0.035),
			w * 0.05, h * 0.035, 10), p["stone_lit"])

	_jars(on, Vector2(w * 0.12, h), w * 0.11, 2, p, edge)


# ── 창고: 고상식 곳간 ──
# 기둥 위에 올려 습기와 짐승을 피한다. 창이 없다.
func _draw_granary(on: CanvasItem, w: float, h: float, p: Dictionary) -> void:
	var edge := _edge(w)
	var roof_h := h * 0.34
	var body_bottom := h * 0.74

	# 기둥 셋 — 몸체 아래가 비어 있어야 고상식으로 읽힌다
	for x in [w * 0.22, w * 0.50, w * 0.78]:
		_post(on, x, body_bottom - h * 0.02, h, w * 0.07, p, edge)

	# 몸체(창 없음)
	var body := Rect2(w * 0.12, roof_h, w * 0.76, body_bottom - roof_h)
	on.draw_rect(body, p["wall"])
	on.draw_rect(Rect2(body.position.x, body.position.y, body.size.x, body.size.y * 0.28),
		p["wall_lit"])
	for i in range(1, 4):
		var y := body.position.y + body.size.y * float(i) / 4.0
		on.draw_line(Vector2(body.position.x, y), Vector2(body.end.x, y), p["wall_dim"],
			maxf(w * 0.010, 1.0))
	on.draw_rect(body, p["line"], false, edge)

	# 작은 출입구
	var hatch := Rect2(w * 0.40, roof_h + body.size.y * 0.34, w * 0.20, body.size.y * 0.40)
	on.draw_rect(hatch, p["dark"])
	on.draw_rect(hatch, p["line"], false, edge * 0.8)

	# 가파른 지붕
	var top := Vector2(w * 0.5, 0.0)
	var left := Vector2(w * 0.02, roof_h)
	var right := Vector2(w * 0.98, roof_h)
	on.draw_colored_polygon(PackedVector2Array([top, right, left]), p["roof"])
	_thatch(on, top, left, right, p["roof_lit"])
	on.draw_polyline(PackedVector2Array([left, top, right]), p["line"], edge)

	# 통나무 사다리
	var la := Vector2(w * 0.72, h)
	var lb := Vector2(w * 0.58, roof_h + body.size.y * 0.72)
	var offset := Vector2(w * 0.10, 0.0)
	on.draw_line(la, lb, p["wood"], edge * 1.6)
	on.draw_line(la + offset, lb + offset, p["wood"], edge * 1.6)
	for i in range(1, 4):
		var t := float(i) / 4.0
		on.draw_line(la.lerp(lb, t), la.lerp(lb, t) + offset, p["wood"], edge)

	_jars(on, Vector2(w * 0.06, h), w * 0.10, 2, p, edge)


func _on_building_pressed(building: OrderBuildingData) -> void:
	# 화면을 여는 주체는 화면이다. 데이터가 가리키는 경로를 열기만 한다.
	var scene := load(building.screen_path) as PackedScene
	if scene == null:
		push_warning("OrderYard: 화면을 열 수 없습니다: " + building.screen_path)
		return
	ScreenManager.push(scene)


# ===== 신도 =====

func _spawn_members() -> void:
	for id in CharacterDatabase.get_playable_ids():
		var character := CharacterDatabase.get_character(id)
		if character == null:
			continue
		_members.append(_make_wanderer(character))


func _make_wanderer(character: CharacterData) -> Wanderer:
	var walker := Wanderer.new()

	if character.walk_frames != null:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = character.walk_frames
		anim.animation = WalkAnimation.ANIMATIONS[WalkAnimation.DOWN]
		anim.frame = 0
		anim.centered = false
		walker.animated = anim
		walker.node = anim
	else:
		# 시트가 없는 인물도 뜰에 있어야 한다. 전투와 같은 도형 플레이스홀더를 세운다.
		var sprite := Sprite2D.new()
		sprite.texture = character.sprite_texture
		sprite.self_modulate = character.tint
		sprite.centered = false
		walker.node = sprite

	_yard_layer.add_child(walker.node)

	walker.spot = _random_spot()
	walker.target = _random_spot()
	return walker


func _random_spot() -> Vector2:
	return Vector2(_rng.randf_range(0.07, 0.93), _rng.randf_range(WALK_TOP, WALK_BOTTOM))


func _process(delta: float) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	for walker in _members:
		_advance(walker, delta)
	_layout_members()
	# 신도가 움직였으니 그림자도 따라와야 한다. 그림자 층 하나만 다시 그린다.
	if _shadows != null:
		_shadows.queue_redraw()


# 한 사람의 산책 한 틱. 쉬는 중이면 서 있고, 아니면 목적지로 걷는다.
func _advance(walker: Wanderer, delta: float) -> void:
	if walker.rest_left > 0.0:
		walker.rest_left -= delta
		_play_walk(walker, Vector2.ZERO)
		return

	var to_target: Vector2 = walker.target - walker.spot
	if to_target.length() <= ARRIVE_EPSILON:
		walker.target = _random_spot()
		walker.rest_left = _rng.randf_range(REST_MIN, REST_MAX)
		_play_walk(walker, Vector2.ZERO)
		return

	walker.spot += to_target.normalized() * WANDER_SPEED * delta
	_play_walk(walker, to_target)


func _play_walk(walker: Wanderer, direction: Vector2) -> void:
	if walker.animated == null:
		return

	if direction == Vector2.ZERO:
		if walker.animated.is_playing():
			walker.animated.stop()
			walker.animated.frame = 0
		return

	var anim := WalkAnimation.animation_for(direction)
	if walker.animated.animation != anim or not walker.animated.is_playing():
		walker.animated.play(anim)


# ===== 배치 =====

func _layout() -> void:
	_layout_buildings()
	_layout_members()
	# 배경·그림자는 전부 뜰 크기 기준이라 창이 바뀌면 다시 그려야 한다.
	if _scenery != null:
		_scenery.queue_redraw()
	if _shadows != null:
		_shadows.queue_redraw()


func _layout_buildings() -> void:
	for child in _yard_layer.get_children():
		if not child.has_meta("building"):
			continue

		var building: OrderBuildingData = child.get_meta("building")
		var holder: Control = child

		var width: float = size.x * building.width_ratio
		# 높이는 그림 비율이 정한다. 그림이 없으면 정사각에 가깝게 둔다.
		var ratio := 1.15
		if building.art != null:
			var art_size := building.art.get_size()
			if art_size.x > 0.0:
				ratio = art_size.y / art_size.x
		var height: float = width * ratio

		holder.size = Vector2(width, height)
		_fit_placeholder_icon(holder, width)
		# spot 은 **바닥 가운데**다. 건물은 그 위로 선다.
		holder.position = Vector2(
			size.x * building.spot.x - width * 0.5,
			size.y * building.spot.y - height)


# 플레이스홀더 아이콘 여백. 건물 폭에 비례해 아이콘이 커진다.
func _fit_placeholder_icon(holder: Control, width: float) -> void:
	var margin := holder.find_child("IconMargin", true, false) as MarginContainer
	if margin == null:
		return
	var pad := int(width * 0.20)
	margin.add_theme_constant_override("margin_left", pad)
	margin.add_theme_constant_override("margin_right", pad)
	margin.add_theme_constant_override("margin_top", int(width * 0.06))
	# 아래는 문이 차지한다. 여백을 같게 두면 아이콘이 문 위에 겹친다.
	margin.add_theme_constant_override("margin_bottom", int(width * 0.30))


func _layout_members() -> void:
	for walker in _members:
		var node: Node2D = walker.node
		if node == null or not is_instance_valid(node):
			continue

		var source := _source_size(walker)
		if source.y <= 0.0:
			continue

		var height: float = size.y * (MEMBER_HEIGHT if walker.animated != null else SHAPE_HEIGHT)
		# 앞으로 올수록 커진다(#313). 건물과 달리 신도는 저작된 크기가 없고
		# 뜰 안을 돌아다니므로, 깊이에 따라 크기가 변해야 평면으로 안 보인다.
		var depth := clampf((walker.spot.y - HORIZON) / maxf(1.0 - HORIZON, 0.001), 0.0, 1.0)
		height *= lerpf(MEMBER_DEPTH_MIN, 1.0, depth)
		var factor: float = height / source.y
		node.scale = Vector2(factor, factor)
		# 발이 spot 에 닿게 둔다(그림은 그 위로 그려진다).
		node.position = Vector2(
			size.x * walker.spot.x - source.x * factor * 0.5,
			size.y * walker.spot.y - source.y * factor)

		# 앞에 선 사람이 위에 온다.
		node.z_index = int(walker.spot.y * 100.0)


# 그림 한 장의 원본 크기. 워크 시트는 프레임 하나 기준이다.
func _source_size(walker: Wanderer) -> Vector2:
	if walker.animated != null:
		var frames := walker.animated.sprite_frames
		if frames == null:
			return Vector2.ZERO
		var anim: StringName = walker.animated.animation
		if not frames.has_animation(anim) or frames.get_frame_count(anim) == 0:
			return Vector2.ZERO
		var texture := frames.get_frame_texture(anim, 0)
		return texture.get_size() if texture != null else Vector2.ZERO

	var sprite := walker.node as Sprite2D
	if sprite == null or sprite.texture == null:
		return Vector2.ZERO
	return sprite.texture.get_size()

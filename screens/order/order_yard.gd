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
	# 하늘 -> 땅. 배경이 한 판이 아니라 두 층이어야 "마당"으로 읽힌다.
	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.color = UITheme.TAN.lerp(UITheme.CREAM, 0.45)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	var ground := ColorRect.new()
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.anchor_top = HORIZON
	ground.color = UITheme.TAN_DEEP.lerp(UITheme.SAGE, 0.22)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var horizon_line := ColorRect.new()
	horizon_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	horizon_line.anchor_top = HORIZON
	horizon_line.anchor_bottom = HORIZON
	horizon_line.offset_bottom = 3.0
	horizon_line.color = UITheme.OUTLINE
	horizon_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(horizon_line)

	_yard_layer = Control.new()
	_yard_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_yard_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_yard_layer)

	_spawn_buildings()
	_spawn_members()
	_layout()


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


# 그림이 없는 건물. 아이콘 + 색 판으로 "여기가 무엇의 자리"인지만 보인다.
# docs §0 과 같은 태도다 — 어설픈 그림을 흉내 내지 않는다.
func _make_building_placeholder(building: OrderBuildingData) -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_bottom = -24.0
	panel.add_theme_stylebox_override("panel",
		HUDKit._box(building.tint, UITheme.OUTLINE, 3, 0, HUDKit.RADIUS_CARD))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 아이콘은 건물 크기를 따라가야 한다. 다만 이 시점에는 아직 레이아웃이 돌지 않아
	# 뜰 크기가 0이다(고정 px 로 잡으면 큰 건물에서 점처럼 보이고, 여기서 비율로
	# 계산하면 0이 되어 아예 사라진다 — 실제로 사라졌다).
	# 여백만 남겨 두고 실제 크기는 _layout_buildings() 가 정한다.
	var margin := MarginContainer.new()
	margin.name = "IconMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var icon := HUDKit.make_icon(building.icon_name, 1)
	if icon != null:
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(icon)
	return panel


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
	var pad := int(width * 0.26)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, pad)


func _layout_members() -> void:
	for walker in _members:
		var node: Node2D = walker.node
		if node == null or not is_instance_valid(node):
			continue

		var source := _source_size(walker)
		if source.y <= 0.0:
			continue

		var height: float = size.y * (MEMBER_HEIGHT if walker.animated != null else SHAPE_HEIGHT)
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

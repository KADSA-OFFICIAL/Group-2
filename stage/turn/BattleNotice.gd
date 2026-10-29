extends PanelContainer
class_name BattleNotice

# 전투 상태 알림 칩 (#576) — 격파 · 행동 무효 · 라운드 · 웨이브.
#
# 예전에는 화면 한가운데에 거대한 영문 배너(RUPTURE · NULLIFIED · N CYCLE)를 띄웠다.
# 지금은 **그 일이 일어난 대상 가까이**에 작은 한글 칩 하나를 띄운다.
#
#   - 글자는 한 계열(`HUDKit.notice_font`)이고 위계는 크기로만 만든다. 외곽선·기울기·확대 연출 없음.
#   - 속성색은 글자가 아니라 칩 왼쪽 포인트 선과 작은 아이콘에만 쓴다.
#   - 등장 → 유지 → 퇴장은 짧은 이동과 투명도뿐이다. 길이는 아래 상수로 조정한다.
#   - **대상 하나에 칩 하나.** 같은 대상에 알림이 또 오면 새 칩을 쌓지 않고 떠 있는 칩 안에 한 줄을
#     더한다(강조 줄이 맨 위). 적 카드 위 여백은 칩 하나 높이뿐이라 칩을 따로 쌓으면 화면 밖으로 밀려
#     겹치고, 한 줄로 이으면 칩이 옆 적의 칩까지 넓어진다. 같은 문구가 또 오면 유지 시간만 다시 센다.
#   - 칩 폭은 적 슬롯 간격(`TurnBattleHUD.ENEMY_SLOT_STEP`)보다 좁게 잡는다 — 이웃한 적의 칩끼리 겹치지 않는다.
#
# 호출부는 `post()` 한 줄이다. 칩은 스스로 지우므로 연달아 불려도 꼬이지 않는다.
# 칩은 히트스톱·슬로모션(`Engine.time_scale`)의 영향을 받지 않는다 — 읽는 시간이 줄지 않게 한다.

## 등장 / 유지 / 퇴장 (초, 배속 적용 전). 시작값은 이슈 #576 의 규격이다.
const IN_TIME: float = 0.10
const HOLD_TIME: float = 0.60
## 강조(격파) 칩은 조금 더 오래 머문다.
const HOLD_TIME_STRONG: float = 0.75
const OUT_TIME: float = 0.15
## 등장 때 올라오는 거리, 퇴장 때 더 올라가는 거리(px).
const RISE_IN: float = 8.0
const RISE_OUT: float = 6.0

const FONT_SIZE: int = 16
const FONT_SIZE_STRONG: int = 20
const ICON_SIZE: float = 16.0
## 배속이 빨라도 유지 시간은 이 배율 아래로 줄이지 않는다 — 3배속에서 0.3초 만에 사라지면 읽을 수 없다.
const MIN_HOLD_SCALE: float = 0.6
## 화면 가장자리 여백(px).
const SCREEN_MARGIN: float = 4.0

const BACKDROP := Color(0.06, 0.07, 0.11, 0.80)
const TEXT_COLOR := Color(0.97, 0.96, 0.92)
## 얇은 그림자. 배경 그림 위에서 글자가 묻히지 않을 만큼만 둔다.
const SHADOW := Color(0, 0, 0, 0.55)

const _REGISTRY_META := &"battle_notice_registry"

var _key: String = ""
var _texts: PackedStringArray = PackedStringArray()
var _anchor: Vector2 = Vector2.ZERO
var _pivot_x: float = 0.5
var _strong: bool = false
var _k: float = 1.0
var _lines: VBoxContainer = null
var _style: StyleBoxFlat = null
var _tween: Tween = null


# layer     — 칩을 얹을 노드(화면 고정 레이어).
# anchor    — 칩 아래 가장자리 기준점(화면 좌표).
# key       — 같은 대상끼리 묶는 이름. 같은 key 의 알림은 칩 하나에 합쳐진다.
# strong    — 격파처럼 한 단계 강조할 때.
# pivot_x   — anchor 가 칩 폭의 어디인가(0.5 = 가운데, 0 = 왼쪽 끝).
# k         — 배속 배율(배속 2배면 0.5).
static func post(layer: Node, anchor: Vector2, key: String, text: String, color: Color,
		strong: bool = false, icon: Texture2D = null, pivot_x: float = 0.5,
		k: float = 1.0) -> BattleNotice:
	if layer == null or not layer.is_inside_tree():
		return null

	var registry := _registry_of(layer)
	var existing: BattleNotice = registry.get(key)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		existing._merge(text, color, strong, k)
		return existing

	var notice := BattleNotice.new()
	notice._key = key
	notice._texts = PackedStringArray([text])
	notice._anchor = anchor
	notice._pivot_x = pivot_x
	notice._strong = strong
	notice._k = k
	notice._build(text, color, strong, icon)
	layer.add_child(notice)
	notice._place()

	registry[key] = notice
	notice.tree_exiting.connect(func() -> void: _forget(layer, key, notice))
	notice._play(true)
	return notice


static func _registry_of(layer: Node) -> Dictionary:
	if not layer.has_meta(_REGISTRY_META):
		layer.set_meta(_REGISTRY_META, {})
	return layer.get_meta(_REGISTRY_META)


static func _forget(layer: Node, key: String, notice: BattleNotice) -> void:
	if not is_instance_valid(layer):
		return
	var registry := _registry_of(layer)
	if registry.get(key) == notice:
		registry.erase(key)


# 떠 있는 칩에 알림을 합친다. 새 문구면 덧붙이고, 강조가 오면 강조로 올린다. 유지 시간은 다시 센다.
func _merge(text: String, color: Color, strong: bool, k: float) -> void:
	if not _texts.has(text):
		_texts.append(text)
		_add_line(text, strong)
	if strong and not _strong:
		_strong = true
		_apply_strong(color)
	_k = k
	_place()
	_play(false)


# 크기를 다시 재고 anchor 에 맞춰 세운다. 화면 밖으로 나가지 않게 가장자리에서 멈춘다.
func _place() -> void:
	var canvas := get_viewport().get_visible_rect().size
	size = Vector2.ZERO
	size = get_combined_minimum_size()
	var pos := _anchor - Vector2(size.x * _pivot_x, size.y)
	pos.x = clampf(pos.x, SCREEN_MARGIN, maxf(canvas.x - size.x - SCREEN_MARGIN, SCREEN_MARGIN))
	pos.y = maxf(pos.y, SCREEN_MARGIN)
	position = pos


func _build(text: String, color: Color, strong: bool, icon: Texture2D) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = BACKDROP
	style.set_corner_radius_all(6)
	# 속성색 포인트 선. 글자 전체를 물들이지 않는다.
	style.border_width_left = 4
	style.border_color = color
	style.content_margin_left = 10.0
	style.content_margin_right = 12.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", style)
	_style = style

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	if icon != null:
		var mark := TextureRect.new()
		mark.texture = icon
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		mark.modulate = color.lightened(0.25)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)

	_lines = VBoxContainer.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.add_theme_constant_override("separation", 0)
	_lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_lines)
	_add_line(text, strong)
	if strong:
		_apply_strong(color)


# 문구 한 줄. 강조 줄은 한 단계 크고 맨 위에 선다.
func _add_line(text: String, strong: bool) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", HUDKit.notice_font())
	label.add_theme_font_size_override("font_size", FONT_SIZE_STRONG if strong else FONT_SIZE)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_lines.add_child(label)
	if strong:
		_lines.move_child(label, 0)


# 강조 칩: 포인트 선을 그 색으로 바꾸고, 아래에 가는 선을 하나 더 긋는다. 글자 크기는 줄마다 정한다.
func _apply_strong(color: Color) -> void:
	_style.border_color = color
	_style.border_width_bottom = 2


# 등장(처음일 때만) -> 유지 -> 퇴장. 합쳐질 때는 다시 불려 유지 시간을 처음부터 센다.
func _play(enter: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var rest := position
	var hold := (HOLD_TIME_STRONG if _strong else HOLD_TIME) * maxf(_k, MIN_HOLD_SCALE)

	# 병렬을 기본으로 두고 단계마다 chain() 으로 끊는다. chain() 뒤에 set_parallel(true) 를 부르면
	# chain 이 풀려 퇴장이 유지와 동시에 시작된다(실제로 겪었다).
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.set_parallel(true)
	if enter:
		position = rest + Vector2(0.0, RISE_IN)
		_tween.tween_property(self, "modulate:a", 1.0, IN_TIME * _k)
		_tween.tween_property(self, "position", rest, IN_TIME * _k) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.chain().tween_interval(hold)
	else:
		modulate.a = 1.0
		_tween.tween_interval(hold)
	_tween.chain().tween_property(self, "modulate:a", 0.0, OUT_TIME * _k)
	_tween.tween_property(self, "position", rest - Vector2(0.0, RISE_OUT), OUT_TIME * _k) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(queue_free)

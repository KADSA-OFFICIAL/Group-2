extends PanelContainer
class_name BattleNotice

# 전투 상태 알림 칩 (#576) — 격파 · 행동 무효 · 라운드 · 웨이브.
#
# 예전에는 화면 한가운데에 거대한 영문 배너(RUPTURE · NULLIFIED · N CYCLE)를 띄웠다.
# 지금은 **그 일이 일어난 대상 가까이**에 작은 한글 칩 하나를 띄운다.
#
# 칩은 세 단계(`Tier`)로 나뉜다 — 모두 같은 검은 표찰이면 중요도가 갈리지 않는다.
#   STRONG    격파.      속성 아이콘 + 밝은 큰 글자 + 짙은 남색 바탕. 가장 오래 머문다.
#   MINOR     행동 무효. 작은 글자 + 옅은 바탕. 보조 알림.
#   PROGRESS  라운드·웨이브. 왼쪽 위 웨이브 알약과 **같은 판**(색·높이·둥근 끝·HUD 폰트)으로
#             알약 바로 옆에 붙는다 — 따로 강조하지 않고 진행 정보로 묶여 읽힌다.
# 장식선·테두리는 쓰지 않는다(진행 칩은 웨이브 알약의 얇은 테두리를 그대로 따른다).
# 속성색은 글자가 아니라 격파 칩의 작은 아이콘에만 쓴다.
#
#   - 글자는 한 계열(`HUDKit.notice_font`)이고 위계는 크기·밝기·여백으로 만든다. 외곽선·기울기·확대 없음.
#   - 등장 → 유지 → 퇴장은 짧은 이동과 투명도뿐이다. 길이는 아래 상수로 조정한다.
#   - **대상 하나에 칩 하나.** 같은 대상에 알림이 또 오면 새 칩을 쌓지 않고 떠 있는 칩 안에 한 줄을
#     더한다(강조 줄이 맨 위). 같은 문구가 또 오면 유지 시간만 다시 센다.
#   - 칩 폭은 적 슬롯 간격(`TurnBattleHUD.ENEMY_SLOT_STEP`)보다 좁게 잡는다 — 이웃한 적의 칩끼리 겹치지 않는다.
#
# 호출부는 `post()` 한 줄이다. 칩은 스스로 지우므로 연달아 불려도 꼬이지 않는다.
# 칩은 히트스톱·슬로모션(`Engine.time_scale`)의 영향을 받지 않는다 — 읽는 시간이 줄지 않게 한다.

enum Tier { MINOR, STRONG, PROGRESS }

## 등장 / 유지 / 퇴장 (초, 배속 적용 전). 시작값은 이슈 #576 의 규격이다.
const IN_TIME: float = 0.10
const HOLD_TIME: float = 0.60
## 강조(격파) 칩은 조금 더 오래 머문다.
const HOLD_TIME_STRONG: float = 0.75
const OUT_TIME: float = 0.15
## 등장 때 올라오는 거리, 퇴장 때 더 올라가는 거리(px).
const RISE_IN: float = 8.0
const RISE_OUT: float = 6.0

const FONT_SIZE_MINOR: int = 14
const FONT_SIZE_STRONG: int = 21
const ICON_SIZE: float = 18.0
## 배속이 빨라도 유지 시간은 이 배율 아래로 줄이지 않는다 — 3배속에서 0.3초 만에 사라지면 읽을 수 없다.
const MIN_HOLD_SCALE: float = 0.6
## 화면 가장자리 여백(px).
const SCREEN_MARGIN: float = 4.0

## 바탕: 기존 전투 UI 의 짙은 남색. 격파는 짙게, 보조 알림은 옅게.
const BACKDROP_STRONG := Color(0.07, 0.09, 0.17, 0.88)
const BACKDROP_MINOR := Color(0.07, 0.09, 0.17, 0.62)
const TEXT_COLOR := Color(0.97, 0.96, 0.92)
const TEXT_COLOR_MINOR := Color(0.86, 0.87, 0.90)
## 얇은 그림자. 배경 그림 위에서 글자가 묻히지 않을 만큼만 둔다.
const SHADOW := Color(0, 0, 0, 0.55)

## 진행 칩: 웨이브 알약과 같은 높이·글자 크기·굵기(`TurnBattleHUD.TOPBAR_H` · `SIZE_LABEL` · 굵기 0.6).
const PROGRESS_HEIGHT: float = 40.0
const PROGRESS_FONT_SIZE: int = 13
const PROGRESS_EMBOLDEN: float = 0.6

const _REGISTRY_META := &"battle_notice_registry"

var _key: String = ""
var _texts: PackedStringArray = PackedStringArray()
var _anchor: Vector2 = Vector2.ZERO
var _pivot_x: float = 0.5
var _tier: int = Tier.MINOR
var _k: float = 1.0
var _row: HBoxContainer = null
var _lines: VBoxContainer = null
var _mark: TextureRect = null
var _style: StyleBoxFlat = null
var _tween: Tween = null


# layer     — 칩을 얹을 노드(화면 고정 레이어).
# anchor    — 칩 아래 가장자리 기준점(화면 좌표).
# key       — 같은 대상끼리 묶는 이름. 같은 key 의 알림은 칩 하나에 합쳐진다.
# tier      — `Tier`. 격파는 STRONG, 행동 무효는 MINOR, 라운드·웨이브는 PROGRESS.
# color     — 속성색. STRONG 의 아이콘에만 입힌다.
# pivot_x   — anchor 가 칩 폭의 어디인가(0.5 = 가운데, 0 = 왼쪽 끝).
# k         — 배속 배율(배속 2배면 0.5).
static func post(layer: Node, anchor: Vector2, key: String, text: String, tier: int,
		color: Color = Color.WHITE, icon: Texture2D = null, pivot_x: float = 0.5,
		k: float = 1.0) -> BattleNotice:
	if layer == null or not layer.is_inside_tree():
		return null

	var registry := _registry_of(layer)
	var existing: BattleNotice = registry.get(key)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		existing._merge(text, tier, color, icon, k)
		return existing

	var notice := BattleNotice.new()
	notice._key = key
	notice._texts = PackedStringArray([text])
	notice._anchor = anchor
	notice._pivot_x = pivot_x
	notice._tier = tier
	notice._k = k
	notice._build(text, color, icon)
	layer.add_child(notice)
	notice._place()

	registry[key] = notice
	notice.tree_exiting.connect(func() -> void: _forget(layer, key, notice))
	notice._play(true)
	return notice


# 떠 있는 칩을 모두 바로 치운다(컷인이 화면을 비울 때). 치운 칩은 다시 나타나지 않는다.
static func clear_all(layer: Node) -> void:
	if layer == null or not layer.has_meta(_REGISTRY_META):
		return
	for notice in _registry_of(layer).values():
		if notice != null and is_instance_valid(notice) and not notice.is_queued_for_deletion():
			notice.queue_free()


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


# 떠 있는 칩에 알림을 합친다. 새 문구면 덧붙이고, 격파가 오면 칩을 격파 칩으로 올린다. 유지 시간은 다시 센다.
func _merge(text: String, tier: int, color: Color, icon: Texture2D, k: float) -> void:
	if not _texts.has(text):
		_texts.append(text)
		_add_line(text, tier)
	if tier == Tier.STRONG and _tier != Tier.STRONG:
		_tier = Tier.STRONG
		_apply_tier_style()
		_set_icon(icon, color)
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


func _build(text: String, color: Color, icon: Texture2D) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

	_style = StyleBoxFlat.new()
	add_theme_stylebox_override("panel", _style)
	_apply_tier_style()

	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 6)
	add_child(_row)

	_lines = VBoxContainer.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.add_theme_constant_override("separation", 0)
	_lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_lines)
	_add_line(text, _tier)
	if _tier == Tier.STRONG:
		_set_icon(icon, color)


# 단계별 바탕·여백. 진행 칩은 웨이브 알약과 같은 판이다.
func _apply_tier_style() -> void:
	match _tier:
		Tier.STRONG:
			_style.bg_color = BACKDROP_STRONG
			_style.set_corner_radius_all(6)
			_style.set_border_width_all(0)
			_set_margins(10.0, 12.0, 5.0, 5.0)
		Tier.PROGRESS:
			_style.bg_color = TurnCombat.panel_fill()
			_style.border_color = TurnCombat.panel_line()
			_style.set_border_width_all(1)
			_style.set_corner_radius_all(int(PROGRESS_HEIGHT * 0.5))
			_set_margins(12.0, 12.0, 0.0, 0.0)
			custom_minimum_size = Vector2(0.0, PROGRESS_HEIGHT)
		_:
			_style.bg_color = BACKDROP_MINOR
			_style.set_corner_radius_all(5)
			_style.set_border_width_all(0)
			_set_margins(8.0, 8.0, 2.0, 3.0)


func _set_margins(left: float, right: float, top: float, bottom: float) -> void:
	_style.content_margin_left = left
	_style.content_margin_right = right
	_style.content_margin_top = top
	_style.content_margin_bottom = bottom


# 격파 칩의 속성 아이콘(줄 왼쪽). 한 번만 단다.
func _set_icon(icon: Texture2D, color: Color) -> void:
	if icon == null or _mark != null:
		return
	_mark = TextureRect.new()
	_mark.texture = icon
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mark.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_mark.modulate = color.lightened(0.25)
	_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_mark)
	_row.move_child(_mark, 0)


# 문구 한 줄. 격파 줄은 크고 밝게 맨 위에, 보조 줄은 작고 차분하게.
func _add_line(text: String, tier: int) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match tier:
		Tier.STRONG:
			label.add_theme_font_override("font", HUDKit.notice_font())
			label.add_theme_font_size_override("font_size", FONT_SIZE_STRONG)
			label.add_theme_color_override("font_color", TEXT_COLOR)
		Tier.PROGRESS:
			# 웨이브 알약 글자와 같은 HUD 폰트·크기·색 — 진행 정보로 묶여 읽힌다.
			label.add_theme_font_override("font", HUDKit.weight_font(PROGRESS_EMBOLDEN))
			label.add_theme_font_size_override("font_size", PROGRESS_FONT_SIZE)
			label.add_theme_color_override("font_color", UITheme.CREAM)
		_:
			label.add_theme_font_override("font", HUDKit.notice_font())
			label.add_theme_font_size_override("font_size", FONT_SIZE_MINOR)
			label.add_theme_color_override("font_color", TEXT_COLOR_MINOR)
	if tier != Tier.PROGRESS:
		label.add_theme_color_override("font_shadow_color", SHADOW)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lines.add_child(label)
	if tier == Tier.STRONG:
		_lines.move_child(label, 0)


# 등장(처음일 때만) -> 유지 -> 퇴장. 합쳐질 때는 다시 불려 유지 시간을 처음부터 센다.
func _play(enter: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var rest := position
	var hold := (HOLD_TIME_STRONG if _tier == Tier.STRONG else HOLD_TIME) * maxf(_k, MIN_HOLD_SCALE)

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

extends CanvasLayer

# 출격 전환 연출 (#584) — 편성에서 출격을 누른 뒤 전장이 드러나기까지.
#
#   덮기   짙은 판이 사선(`/`)으로 화면을 가로질러 편성 화면을 덮는다.
#   카드   덮인 판 위에 "STAGE 1-2" · 스테이지 이름 · "WAVE n" · "출격!" 이 차례로 들어온다.
#   걷기   판이 같은 방향으로 계속 밀려나가며 전장이 드러난다.
#
# 화면 아무 곳이나 누르면 곧바로 걷기로 넘어간다. 걷기가 끝나기 전에는 입력이 아래 전장으로
# 새지 않는다(전체를 덮는 `Control` 이 받는다).
#
# 왜 처음에 화면을 찍어 두는가: 출격 버튼은 `request_stage()` 직후 `ScreenManager.close_all()`
# 을 부르고, 메타 화면은 0.06초 만에 사라진다. 판이 다 덮기(0.3초) 전에 편성 화면이 걷혀
# 새 전장이 먼저 비친다. 그래서 **누른 순간의 화면을 그림으로 깔고** 그 위를 판이 덮는다 —
# 아래에서 화면이 닫히고 전투가 다시 만들어져도 플레이어 눈에는 편성 화면이 덮이는 것으로 보인다.
#
# 로직을 모른다. 전투(`TurnBattle`)는 `is_holding()` 이 false 가 될 때까지 첫 턴 재생을 미룬다.
#
# 시간은 히트스톱·슬로모션(`Engine.time_scale`)과 트리 정지(메타 화면) 영향을 받지 않는다.

## 길이(초). 합이 이슈 #584 의 상한 1.5초를 넘지 않게 둔다.
const COVER_TIME: float = 0.30
const CARD_IN_TIME: float = 0.18
## 카드 줄이 하나씩 들어오는 간격.
const CARD_STAGGER: float = 0.08
const CARD_HOLD: float = 0.36
const REVEAL_TIME: float = 0.40

## 이 레이어 번호. 메타 화면(`ScreenManager.SCREEN_LAYER` = 10)보다 위여야 편성 화면을 덮는다.
const LAYER: int = 20

## 판 가장자리의 기울기(px). 판 높이 전체에서 위쪽이 이만큼 오른쪽으로 나온다 → `/` 모양.
const SLANT: float = 220.0
## 판 앞머리를 따라가는 액센트 띠 폭(px).
const EDGE_STRIPE: float = 18.0

## 색은 UITheme 팔레트에서 읽는다.
const PANEL_COLOR := UITheme.BG
const STRIPE_COLOR := UITheme.AMBER
const TEXT_COLOR := UITheme.CREAM
const SUB_COLOR := UITheme.AMBER

const SIZE_STAGE: int = 30
const SIZE_NAME: int = 56
const SIZE_WAVE: int = 24
const SIZE_GO: int = 40
## 카드 줄이 들어올 때 오른쪽에서 밀려오는 거리(px).
const CARD_SLIDE: float = 60.0

enum State { IDLE, COVERING, CARD, REVEALING }

var _state: State = State.IDLE
var _snapshot: TextureRect = null
var _blocker: Control = null
var _panel: Polygon2D = null
var _stripe: Polygon2D = null
var _card: VBoxContainer = null
var _lines: Array[Control] = []
var _tween: Tween = null
## 실행 세대. 재출격으로 다시 시작하면 옛 코루틴이 깨어나 세대를 보고 빠진다.
var _gen: int = 0


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_snapshot = TextureRect.new()
	_snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snapshot.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_snapshot)

	_panel = Polygon2D.new()
	_panel.color = PANEL_COLOR
	add_child(_panel)

	_stripe = Polygon2D.new()
	_stripe.color = STRIPE_COLOR
	add_child(_stripe)

	_card = VBoxContainer.new()
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_constant_override("separation", 6)
	add_child(_card)

	# 맨 위: 입력을 받아 건너뛰기에 쓰고, 아래로 새지 않게 막는다.
	_blocker = Control.new()
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.gui_input.connect(_on_blocker_input)
	add_child(_blocker)


# 이 환경에서 연출을 틀 수 있는가. 헤드리스(검사)에서는 화면이 없으므로 끈다 —
# 검사가 출격 직후 전투가 바로 진행된다고 가정하고 있다.
static func is_supported() -> bool:
	return DisplayServer.get_name() != "headless"


## 전투 첫 턴을 붙잡고 있는가. 걷기가 **시작되면** 놓는다 — 판이 걷히는 동안 첫 턴이 시작돼야
## 전장이 멈춘 그림처럼 보이지 않는다.
func is_holding() -> bool:
	return _state == State.COVERING or _state == State.CARD


## 출격 순간 부른다. 지금 화면을 찍어 깔고 덮기를 시작한다. 카드 내용은 `set_card()` 로 넣는다.
##
## **동기 호출이다** — 부른 직후부터 `is_holding()` 이 true 다. 전투를 다시 만들기 전에 불러야
## 새 전투의 진행 루프가 첫 턴을 붙잡힌 채 시작한다.
func begin() -> void:
	_gen += 1
	_kill_tween()
	_state = State.COVERING
	visible = true
	_fit()
	_take_snapshot()
	_clear_card()
	# 판과 띠가 통째로 화면 왼쪽 밖에 있는 자리에서 출발한다.
	_place_panel(-(_width() + 2.0 * SLANT + EDGE_STRIPE))
	_run(_gen)


## 카드 글자. `stage_number` 가 비면(챕터 밖) 그 줄을 빼고, `wave_total` 이 1 이하여도 WAVE 줄을 뺀다.
func set_card(stage_number: String, stage_name: String, wave_total: int) -> void:
	_clear_card()
	if not stage_number.is_empty():
		_add_line("STAGE " + stage_number, SIZE_STAGE, SUB_COLOR, true)
	_add_line(stage_name, SIZE_NAME, TEXT_COLOR, false)
	if wave_total > 1:
		_add_line("WAVE %d" % wave_total, SIZE_WAVE, SUB_COLOR, true)
	_add_line("출격!", SIZE_GO, TEXT_COLOR, false)
	for line in _lines:
		line.modulate.a = 0.0


# ===== 진행 =====

func _run(gen: int) -> void:
	# 1) 덮기
	_tween = _make_tween()
	_tween.tween_method(_place_panel, _panel_x(), 0.0, COVER_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _tween.finished
	if gen != _gen or _state != State.COVERING:
		return
	# 판이 다 덮었다 — 찍어 둔 그림은 더 필요 없다.
	_snapshot.texture = null

	# 2) 카드
	_state = State.CARD
	_tween = _make_tween()
	_tween.set_parallel(true)
	var i := 0
	for line in _lines:
		var home := line.position.x
		line.position.x = home + CARD_SLIDE
		var delay := CARD_STAGGER * i
		_tween.tween_property(line, "modulate:a", 1.0, CARD_IN_TIME).set_delay(delay)
		_tween.tween_property(line, "position:x", home, CARD_IN_TIME).set_delay(delay) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		i += 1
	_tween.chain().tween_interval(CARD_HOLD)
	await _tween.finished
	if gen != _gen or _state != State.CARD:
		return

	_reveal(gen)


# 3) 걷기. 건너뛰기도 여기로 온다.
func _reveal(gen: int) -> void:
	_state = State.REVEALING
	_kill_tween()
	_snapshot.texture = null
	_tween = _make_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_place_panel, _panel_x(), _width() + SLANT + EDGE_STRIPE, REVEAL_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_card, "modulate:a", 0.0, REVEAL_TIME * 0.5)
	await _tween.finished
	if gen != _gen:
		return
	_state = State.IDLE
	visible = false
	_card.modulate.a = 1.0
	_clear_card()


func _on_blocker_input(event: InputEvent) -> void:
	var pressed := (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	_blocker.accept_event()
	if _state == State.COVERING or _state == State.CARD:
		_reveal(_gen)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	if _state == State.COVERING or _state == State.CARD:
		_reveal(_gen)


# ===== 조각 =====

func _make_tween() -> Tween:
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_ignore_time_scale(true)
	return t


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _width() -> float:
	return get_viewport().get_visible_rect().size.x


func _height() -> float:
	return get_viewport().get_visible_rect().size.y


# 화면 크기에 맞춘다. 1280×720 고정 좌표를 쓰지 않는다(docs/turn-combat-design.md §14).
func _fit() -> void:
	var size := get_viewport().get_visible_rect().size
	for control: Control in [_snapshot, _blocker, _card]:
		control.position = Vector2.ZERO
		control.size = size


func _take_snapshot() -> void:
	_snapshot.texture = null
	var texture := get_viewport().get_texture()
	if texture == null:
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		return
	_snapshot.texture = ImageTexture.create_from_image(image)


# 판의 왼쪽 아래 꼭짓점이 `x` 에 오도록 놓는다. x = 0 이면 화면을 다 덮는다.
#
# 판은 화면 폭 + 기울기만큼 넓은 평행사변형이고, 앞머리(오른쪽 변)에 액센트 띠가 붙는다.
func _place_panel(x: float) -> void:
	var w := _width() + SLANT
	var h := _height()
	_panel.polygon = PackedVector2Array([
		Vector2(x - SLANT, h), Vector2(x + w, h),
		Vector2(x + w + SLANT, 0.0), Vector2(x, 0.0),
	])
	var e := x + w
	_stripe.polygon = PackedVector2Array([
		Vector2(e, h), Vector2(e + EDGE_STRIPE, h),
		Vector2(e + EDGE_STRIPE + SLANT, 0.0), Vector2(e + SLANT, 0.0),
	])
	_panel.set_meta(&"x", x)


func _panel_x() -> float:
	return float(_panel.get_meta(&"x", 0.0))


func _add_line(text: String, font_size: int, color: Color, display: bool) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display:
		HUDKit.style_display_label(label, font_size, color, 0)
	else:
		label.add_theme_font_override("font", HUDKit.notice_font())
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color)
	_card.add_child(label)
	_lines.append(label)


func _clear_card() -> void:
	for line in _lines:
		line.queue_free()
	_lines.clear()

extends CanvasLayer
class_name HUD

# 전투 화면 HUD.
#
# 표시하는 것 (docs/combat-screen-design.md §6 중 **현재 구현된 것만**):
#   - 파티 3인 카드: 이름/역할/HP/보호막, 조종 중인 1명 강조, 전환 키(1/2/3)
#   - 역할 메커니즘 상태: 표식 게이지 / 원거리 스택 / 처형 가능
#   - 역할군 시너지: 카운트와 활성 단계 (2카운트 비활성이 드러나야 한다)
#   - 고유 스킬 Q·E: 남은 쿨타임 / 시전 중 / 걸린 창
#
# 보호막은 여기 파티 카드(+150)와 머리 위 체력바(entities/ui/HealthBar.gd) 둘 다에 나온다.
# 둘이 같은 색(UITheme.SKY)을 쓰는 것은 같은 자원이기 때문이다 — 한쪽 색을 바꾸면 함께 바꾼다.
#
# 아직 표시하지 않는 것: 점령 게이지(스테이지 타입 미구현).
#
# 값의 출처:
#   파티/조종  -> PartySystem
#   시너지     -> SynergySystem
#   표식       -> StatusEffectSystem
#   스택       -> Player.get_stack_count()
#   스킬       -> Player.get_skill_cooldown_left() / is_casting() / is_chain_window_open()
#   수치       -> CombatConfig.tuning
#   색·아이콘  -> UITheme / HUDKit
# 여기서 계산하거나 색을 새로 만들지 않는다. 읽어서 그리기만 한다.

const MARK_EFFECT := &"mark"

# 아이콘 크기. HUD는 메타 화면보다 작게 쓴다.
const ICON_SIZE: int = 18
const ICON_SIZE_SMALL: int = 14

# 적 초상 썸네일. 아이콘(18)보다 커야 한다 — 초상은 그림이라 그 크기에서는
# 얼굴이 뭉개져 색 판과 구별되지 않는다.
const ENEMY_PORTRAIT_SIZE: int = 36

# 튜토리얼 판(#345). 세 줄 본문이 한 눈에 들어오는 폭이다.
const TUTORIAL_PANEL_WIDTH: int = 460

# 읽는 국면의 안내. 입력 액션(ui_accept)의 기본 바인딩을 사람 말로 쓴 것이다.
const TUTORIAL_CONFIRM_HINT := "Space / Enter — 계속"

# 여신의 스킬 발동 키(#358). project.godot 의 goddess_skill 액션 바인딩을 사람 말로 쓴 것이다.
const GODDESS_KEY_LABEL := "R"

var _party_rows: Array = []          # [{ "root": Control, "name": Label, "hp": Label, "bracket": Control }]
var _synergy_rows: Dictionary = {}   # Role -> Label
var _mark_row: Control
var _mark_label: Label
var _stack_row: Control
var _stack_label: Label
var _stack_fill: ColorRect
var _stack_track: Control

# 미나 같은 캐릭터 개성 자원(#259). 게이지를 가진 캐릭터를 잡았을 때만 보인다.
var _gauge_row: Control
var _gauge_label: Label
var _gauge_fill: ColorRect
var _gauge_track: Control
var _execute_row: Control
var _support_row: Control

# 고유 스킬 쿨타임(#263). 스킬을 저작한 캐릭터를 잡았을 때만 보인다.
var _skill_panel: PanelContainer
var _skill_q_row: Control
var _skill_q_label: Label
var _skill_e_row: Control
var _skill_e_label: Label

# 적 패널: 종류(enemy_id)별 한 줄. 줄은 종류 구성이 바뀔 때만 다시 만든다.
var _enemy_panel: PanelContainer
var _enemy_body: VBoxContainer
var _enemy_rows: Dictionary = {}     # enemy_id -> Label (수량)
var _enemy_signature: Array = []     # 현재 줄이 만들어진 종류 목록(정렬됨)
# 역할 패널. 안의 세 줄이 전부 숨으면 제목만 남은 빈 판이 되므로 통째로 숨긴다.
var _mechanics_panel: PanelContainer

# 여신의 스킬 판(#358). 고른 스킬이 있을 때만 보인다.
var _goddess_panel: PanelContainer
var _goddess_name_label: Label
var _goddess_state_label: Label

# 점령 판(#377). 거점 존이 있는 스테이지에서만 보인다.
var _capture_panel: PanelContainer
var _capture_count_label: Label
var _capture_state_label: Label

# 부대 판(#444). 웨이브가 저작된 스테이지에서만 보인다.
var _wave_panel: PanelContainer
var _wave_count_label: Label
var _wave_state_label: Label

# 튜토리얼 판(#345). TutorialSystem 이 단계를 알려줄 때만 보인다.
var _tutorial_panel: PanelContainer
var _tutorial_step_label: Label
var _tutorial_title_label: Label
var _tutorial_body_label: Label
var _tutorial_hint_label: Label


func _ready() -> void:
	name = "HUD"
	_build()

	if EventBus:
		EventBus.party_changed.connect(_on_party_changed)
		EventBus.party_control_changed.connect(_on_control_changed)
		# 승패가 나면 그 프레임에 결과 화면이 뜨고 전장이 멈춘다. 멈추기 전에 한 번
		# 갱신하지 않으면 "소탕 완료" 옆에 죽은 적이 그대로 남은 화면이 찍힌다.
		EventBus.stage_completed.connect(_on_stage_finished)
		EventBus.stage_failed.connect(_on_stage_finished)

	# 튜토리얼 판은 신호로만 갱신한다(#345) — 읽는 국면에는 전투가 멈춰
	# _process 가 돌지 않으므로 매 프레임 갱신에 얹을 수 없다.
	TutorialSystem.step_changed.connect(_on_tutorial_step_changed)
	TutorialSystem.finished.connect(_on_tutorial_finished)

	# 전장(Stage)은 main.tscn 에서 HUD 보다 먼저 _ready 를 돌아 stage_started 를 이미 쏜다.
	# 그래서 첫 단계의 step_changed 를 놓친 상태로 시작한다 — 지금 상태를 직접 읽어 그린다.
	if TutorialSystem.is_active():
		_on_tutorial_step_changed(TutorialSystem.get_current_step(),
			TutorialSystem.get_step_index(), TutorialSystem.get_step_count(),
			TutorialSystem.is_reading())

	_rebuild_party_rows()


func _process(_delta: float) -> void:
	_update_party()
	_update_mechanics()
	_update_skills()
	_update_synergy()
	_update_goddess()
	_update_capture()
	_update_wave()
	_update_enemies()


# ===== 구성 (Build) =====

func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_top", 12)
	root.add_theme_constant_override("margin_right", 12)
	root.add_theme_constant_override("margin_bottom", 12)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 좌상단: 파티 / 메커니즘, 우상단: 시너지 / 적
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(left)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(spacer)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(right)

	left.add_child(_build_party_panel())
	left.add_child(_build_mechanics_panel())
	left.add_child(_build_skill_panel())
	left.add_child(_build_goddess_panel())
	right.add_child(_build_synergy_panel())
	right.add_child(_build_capture_panel())
	# 부대 판은 점령 판 **아래**, 적 판 **위**에 둔다(#444) — 대기 안내가
	# "이 게이지가 다음 부대를 막고 있다"를 뜻하므로 점령 판 바로 옆에 있어야 읽힌다.
	right.add_child(_build_wave_panel())
	right.add_child(_build_enemy_panel())

	# 튜토리얼 판은 화면 아래 가운데에 따로 놓는다(#345). 위 두 열에 끼우면
	# 파티·시너지 판을 밀어내는데, 튜토리얼이 가리키는 것이 바로 그 판들이다.
	root.add_child(_build_tutorial_layer())


# 점령 판(#377). 설계 §6 의 "(스테이지 타입에 따라) 점령 게이지 / 거점 존 표시" 요구사항이다.
#
# 존 자체는 전장에 그려진다(CaptureZone._draw) — 존은 화면 좌표가 아니라 자리이기 때문이다.
# 여기서는 같은 값을 **숫자로** 보여 준다: 몇 곳을 확보했고, 지금 채워지는지 멈췄는지.
#
# 값의 출처는 존 노드다(그룹 조회). 여기서 진행도를 계산하지 않는다.
func _build_capture_panel() -> PanelContainer:
	var panel := HUDKit.make_panel("점령", "CAPTURE", 10, true)
	var body := HUDKit.body_of(panel)

	_capture_count_label = HUDKit.label("", 12, HUDKit.text_2())
	body.add_child(_capture_count_label)

	_capture_state_label = HUDKit.value("-", 13)
	body.add_child(_capture_state_label)

	_capture_panel = panel
	return panel


func _update_capture() -> void:
	if _capture_panel == null:
		return

	var zones := get_tree().get_nodes_in_group(CaptureZone.GROUP)
	if zones.is_empty():
		# 점령이 없는 스테이지에서는 판째로 사라진다(전투 타입에 빈 판을 남기지 않는다).
		_capture_panel.visible = false
		return
	_capture_panel.visible = true

	var captured := 0
	var contested := 0
	var occupied := 0
	# 진행률은 **가장 덜 찬 존**을 보여 준다 — 전부 확보해야 끝나므로 그것이 남은 일이다.
	var slowest := 1.0
	for zone in zones:
		if not is_instance_valid(zone):
			continue
		if zone.is_captured():
			captured += 1
			continue
		slowest = minf(slowest, zone.get_progress_ratio())
		if zone.is_contested():
			contested += 1
		elif zone.get_party_inside() > 0:
			occupied += 1

	_capture_count_label.text = "거점 %d / %d 확보" % [captured, zones.size()]

	if captured >= zones.size():
		_capture_state_label.text = "점령 완료"
		_capture_state_label.add_theme_color_override("font_color", HUDKit.up_color())
	elif contested > 0:
		_capture_state_label.text = "%d%%  적이 지키고 있다" % roundi(slowest * 100.0)
		_capture_state_label.add_theme_color_override("font_color", UITheme.HOSTILE)
	elif occupied > 0:
		_capture_state_label.text = "%d%%  확보 중" % roundi(slowest * 100.0)
		_capture_state_label.add_theme_color_override("font_color", HUDKit.accent_text())
	else:
		_capture_state_label.text = "%d%%  비어 있음" % roundi(slowest * 100.0)
		_capture_state_label.add_theme_color_override("font_color", HUDKit.text_3())


# 부대 판(#444). 몇 파 중 몇 파인지, 그리고 **다음 부대가 왜 안 오는지**를 알려 준다.
#
# 왜 필요한가: #442 로 웨이브에 점령 조건이 생겨, 1파를 치운 뒤 점을 확보해야
# 다음 부대가 오는 구간이 생겼다. 그동안 전장에 적이 없고 게이지만 차는데 화면에
# 설명이 없으면 "왜 아무것도 안 나오지"로 읽힌다.
#
# 왜 stage_wave_started 를 듣지 않는가: 전장이 HUD 보다 먼저 _ready 를 돌아 1파 신호를
# 이미 쏘므로 그것을 놓친다(위 _ready 의 튜토리얼 주석과 같은 문제다). 그래서 매 프레임
# 전장에 직접 묻는다 — 이 HUD 의 다른 판들과 같은 방식이다.
func _build_wave_panel() -> PanelContainer:
	var panel := HUDKit.make_panel("부대", "WAVE", 10, true)
	var body := HUDKit.body_of(panel)

	_wave_count_label = HUDKit.label("", 12, HUDKit.text_2())
	body.add_child(_wave_count_label)

	_wave_state_label = HUDKit.value("-", 13)
	body.add_child(_wave_state_label)

	_wave_panel = panel
	return panel


func _update_wave() -> void:
	if _wave_panel == null:
		return

	var stage_node := _find_stage()
	var total := stage_node.get_wave_total() if stage_node != null else 0
	if stage_node == null or total <= 0:
		# 웨이브를 쓰지 않는 스테이지(1-1 등)에서는 판째로 사라진다.
		# 점령 판이 존 없는 스테이지에서 사라지는 것과 같은 규약이다.
		_wave_panel.visible = false
		return
	_wave_panel.visible = true

	var index: int = stage_node.get_wave_index()
	var stage := StageSystem.get_current_stage()

	# index 가 -1 이면 아직 시작 배치(spawns)를 치우는 중이다 — 파 번호를 붙일 수 없다.
	if index < 0:
		_wave_count_label.text = "%d파 · 시작 배치" % total
	else:
		var label := ""
		if stage != null and index < stage.waves.size():
			var wave: StageWave = stage.waves[index]
			if wave != null and not wave.label.is_empty():
				label = " · " + wave.label
		_wave_count_label.text = "%d파 중 %d파%s" % [total, index + 1, label]

	var remaining := GameManager.get_all_enemies().size()

	if stage_node.is_waiting_for_capture():
		# 이 이슈의 핵심. 적이 없는 이유가 "다 끝났다"가 아니라는 것을 말해 준다.
		_wave_state_label.text = "거점을 확보해야 다음 부대가 온다"
		_wave_state_label.add_theme_color_override("font_color", UITheme.HOSTILE)
	elif remaining > 0:
		_wave_state_label.text = "남은 적 %d" % remaining
		_wave_state_label.add_theme_color_override("font_color", HUDKit.text_2())
	elif index + 1 < total:
		# 조건 없는 웨이브는 다음 프레임에 놓인다. 한 프레임짜리 상태지만,
		# 여기서 "부대 전멸"을 보여 주면 아직 남은 파가 있는데 끝난 것처럼 보인다.
		_wave_state_label.text = "다음 부대 오는 중"
		_wave_state_label.add_theme_color_override("font_color", HUDKit.accent_text())
	else:
		_wave_state_label.text = "부대 전멸"
		_wave_state_label.add_theme_color_override("font_color", HUDKit.up_color())


# 전장 노드. 이름이 동적이라 그룹으로 찾는다(Stage.GROUP).
func _find_stage() -> Stage:
	for node in get_tree().get_nodes_in_group(Stage.GROUP):
		if is_instance_valid(node) and node is Stage:
			return node
	return null


# 여신의 스킬 판(#358). 무엇을 들고 왔는지 / 아직 쓸 수 있는지 / 정지 잔여 시간.
#
# 스킬 판(Q·E)과 나눠 두는 이유: 저쪽은 **조종 중인 캐릭터**의 것이라 전환하면 내용이
# 바뀌지만, 이쪽은 **파티 하나에 하나**이고 스테이지 내내 같다.
# 고른 스킬이 없으면 판째로 숨는다.
func _build_goddess_panel() -> PanelContainer:
	var panel := HUDKit.make_panel("여신의 스킬", "GODDESS", 10, true)
	var body := HUDKit.body_of(panel)

	_goddess_name_label = HUDKit.label("", 12, HUDKit.text_2())
	body.add_child(_goddess_name_label)

	_goddess_state_label = HUDKit.value("-", 13)
	body.add_child(_goddess_state_label)

	_goddess_panel = panel
	return panel


func _update_goddess() -> void:
	if _goddess_panel == null:
		return

	var skill: GoddessSkillData = GoddessSkillSystem.get_selected()
	if skill == null:
		# 고르지 않았으면 빈 판을 남기지 않는다.
		_goddess_panel.visible = false
		return
	_goddess_panel.visible = true

	_goddess_name_label.text = "%s  [%s]" % [skill.display_name, GODDESS_KEY_LABEL]

	if GoddessSkillSystem.is_time_stopped():
		_goddess_state_label.text = "정지 %.1f초" % GoddessSkillSystem.get_time_stop_left()
		_goddess_state_label.add_theme_color_override("font_color", HUDKit.accent_text())
	elif GoddessSkillSystem.is_hasted():
		# 가속은 "얼마나 올랐나"가 핵심이라 남은 시간과 함께 지금 증가율을 보여 준다(#366).
		_goddess_state_label.text = "가속 %.1f초  공속 +%.0f%% / 이속 +%.0f%%" % [
			GoddessSkillSystem.get_haste_left(),
			GoddessSkillSystem.get_haste_attack_speed_percent() * 100.0,
			GoddessSkillSystem.get_haste_move_speed_percent() * 100.0]
		_goddess_state_label.add_theme_color_override("font_color", HUDKit.accent_text())
	elif GoddessSkillSystem.is_available():
		_goddess_state_label.text = "사용 가능"
		_goddess_state_label.add_theme_color_override("font_color", HUDKit.up_color())
	else:
		_goddess_state_label.text = "사용함"
		_goddess_state_label.add_theme_color_override("font_color", HUDKit.text_3())


# 튜토리얼 판(#345). 진행은 TutorialSystem 이 하고, 여기는 **그리기만** 한다.
#
# 매 프레임 갱신하지 않는 유일한 판이다: 단계는 드물게 바뀌고, 읽는 국면에서는 전투가
# 멈춰 있어 HUD._process 가 돌지 않는다. 그래서 신호로만 갱신한다.
func _build_tutorial_layer() -> Control:
	# 아래 가운데 정렬. 전투 화면 가운데(캐릭터가 서 있는 곳)를 가리지 않게 아래에 붙인다.
	var holder := VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)

	var panel := HUDKit.make_panel("", "", 12, true)
	panel.custom_minimum_size = Vector2(TUTORIAL_PANEL_WIDTH, 0)
	panel.visible = false
	var body := HUDKit.body_of(panel)

	# 몇 번째 단계인지. 끝이 보이지 않는 안내는 읽지 않는다.
	_tutorial_step_label = HUDKit.label("", 11, HUDKit.text_3())
	body.add_child(_tutorial_step_label)

	_tutorial_title_label = HUDKit.label("", 15, HUDKit.text_1(), 700)
	body.add_child(_tutorial_title_label)

	_tutorial_body_label = HUDKit.label("", 12, HUDKit.text_2())
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_body_label.custom_minimum_size = Vector2(TUTORIAL_PANEL_WIDTH - 32, 0)
	body.add_child(_tutorial_body_label)

	body.add_child(HUDKit.rule())

	# 지금 무엇을 하면 넘어가는지. 읽는 국면과 하는 국면에서 문구가 달라진다.
	_tutorial_hint_label = HUDKit.label("", 12, HUDKit.accent_text(), 600)
	body.add_child(_tutorial_hint_label)

	_tutorial_panel = panel
	row.add_child(panel)
	return holder


func _on_tutorial_step_changed(step: TutorialStepData, index: int, total: int, reading: bool) -> void:
	if _tutorial_panel == null or step == null:
		return

	_tutorial_step_label.text = "튜토리얼 %d/%d" % [index + 1, total]
	_tutorial_title_label.text = step.title
	_tutorial_body_label.text = step.body
	_tutorial_hint_label.text = TUTORIAL_CONFIRM_HINT if reading else _tutorial_goal_text(step)
	_tutorial_panel.visible = true


func _on_tutorial_finished(_stage_id: StringName) -> void:
	if _tutorial_panel == null:
		return
	_tutorial_panel.visible = false


# 하는 국면에서 띄우는 목표 문구.
#
# 문구를 저작본(TutorialStepData.body)에 또 적지 않는 이유: 이것은 **진행 조건의 표현**이라
# 조건과 같은 곳에서 나와야 한다. 저작본에 손으로 적으면 조건을 바꿀 때 문구가 남는다.
func _tutorial_goal_text(step: TutorialStepData) -> String:
	match step.advance:
		TutorialStepData.Advance.DASH:
			return "▶ 대시해 보세요"
		TutorialStepData.Advance.EFFECT_APPLIED:
			return "▶ 적에게 %s을 부여하세요" % _effect_name(step.effect_id)
		TutorialStepData.Advance.EFFECT_BURST:
			return "▶ %s을 끝까지 채워 터뜨리세요" % _effect_name(step.effect_id)
		TutorialStepData.Advance.EXECUTE:
			return "▶ 버퍼로 처형하세요"
		_:
			return TUTORIAL_CONFIRM_HINT


# 상태 효과의 표시 이름. 출처는 StatusEffectDatabase 다(여기서 이름을 만들지 않는다).
func _effect_name(effect_id: StringName) -> String:
	var data := StatusEffectDatabase.get_effect(effect_id)
	return data.display_name if data != null else String(effect_id)


# 고유 스킬 판(#263). Q·E 의 남은 쿨타임과 지금 걸린 상태를 보여 준다.
#
# 왜 역할 판과 나누는가: 역할 판은 **시너지가 제공하는 것**(표식·스택·처형)이라 파티 구성으로
# 켜지고 꺼진다. 스킬은 **캐릭터 개성**이라 혼자 있어도 있다(docs §3 티어2). 한 판에 섞으면
# 무엇이 편성으로 바뀌는 값인지가 화면에서 사라진다.
#
# 스킬을 저작하지 않은 캐릭터를 잡으면 두 줄이 모두 숨고 판째로 사라진다.
func _build_skill_panel() -> PanelContainer:
	var panel := HUDKit.make_panel("스킬", "SKILL", 10, true)
	var body := HUDKit.body_of(panel)

	_skill_q_row = _make_icon_row("icon_battle", "Q", "")
	_skill_q_label = _skill_q_row.get_meta("value")
	body.add_child(_skill_q_row)

	_skill_e_row = _make_icon_row("icon_battle", "E", "")
	_skill_e_label = _skill_e_row.get_meta("value")
	body.add_child(_skill_e_row)

	_skill_panel = panel
	return panel


func _build_party_panel() -> PanelContainer:
	var panel := HUDKit.make_panel("파티", "PARTY", 10, true)
	var body := HUDKit.body_of(panel)
	body.name = "PartyBody"
	return panel


func _build_mechanics_panel() -> PanelContainer:
	var panel := HUDKit.make_panel("역할", "ROLE", 10, true)
	var body := HUDKit.body_of(panel)

	_mark_row = _make_icon_row("icon_mark", "표식", "")
	_mark_label = _mark_row.get_meta("value")
	body.add_child(_mark_row)

	var stack_meter := _build_meter_row("icon_stack", "스택")
	_stack_row = stack_meter["row"]
	_stack_label = stack_meter["label"]
	_stack_track = stack_meter["track"]
	_stack_fill = stack_meter["fill"]
	body.add_child(_stack_row)

	var gauge_meter := _build_meter_row("icon_stack", "게이지")
	_gauge_row = gauge_meter["row"]
	_gauge_label = gauge_meter["label"]
	_gauge_track = gauge_meter["track"]
	_gauge_fill = gauge_meter["fill"]
	body.add_child(_gauge_row)

	_execute_row = _make_icon_row("icon_execute", "처형 가능", "")
	body.add_child(_execute_row)

	# 버퍼 3단계(#369). 제공한 힐/보호막에서 쌓인, 다음 평타에 얹힐 피해.
	# 쌓이는 것이 보여야 "지금 때리면 이만큼 더 들어간다"가 판단 재료가 된다.
	_support_row = _make_icon_row("icon_execute", "보류 피해", "")
	body.add_child(_support_row)

	_mechanics_panel = panel
	return panel


# 스택·게이지는 숫자만으로는 "차고 빠지는 것"이 안 보인다. 가는 미터를 함께 둔다.
#
# 두 줄이 같은 모양이라 만드는 코드를 하나로 둔다. 노드 참조는 딕셔너리로 돌려주고,
# 부르는 쪽이 자기 필드에 담는다(GDScript 에 출력 인자가 없다).
func _build_meter_row(icon_name: String, title_ko: String) -> Dictionary:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var top := _make_icon_row(icon_name, title_ko, "")
	row.add_child(top)

	var track := PanelContainer.new()
	track.add_theme_stylebox_override("panel", HUDKit.inset(0))
	track.custom_minimum_size = Vector2(120, 6)
	row.add_child(track)

	var fill := ColorRect.new()
	fill.color = UITheme.ACCENT  # 면을 칠하는 것이라 원본 앰버가 맞다
	fill.custom_minimum_size = Vector2(0, 6)
	track.add_child(fill)

	return {"row": row, "label": top.get_meta("value"), "track": track, "fill": fill}


# 미터 채움. 트랙 폭에 비례해 늘린다.
func _set_meter(track: Control, fill: ColorRect, ratio: float) -> void:
	var track_width: float = track.size.x
	if track_width <= 0.0:
		track_width = track.custom_minimum_size.x
	var width: float = track_width * clampf(ratio, 0.0, 1.0)
	fill.custom_minimum_size = Vector2(width, 6)
	fill.size = Vector2(width, 6)


# 아이콘 + 라벨 + 값 한 줄. 값 라벨은 meta["value"]로 꺼낸다.
func _make_icon_row(icon_name: String, text_ko: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var icon := HUDKit.make_icon(icon_name, ICON_SIZE)
	if icon != null:
		row.add_child(icon)

	row.add_child(HUDKit.label(text_ko, 12, HUDKit.text_2()))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var value := HUDKit.value(value_text, 14)
	row.add_child(value)
	row.set_meta("value", value)
	return row


func _build_synergy_panel() -> PanelContainer:
	var panel := HUDKit.make_panel("시너지", "SYNERGY", 10, true, "icon_synergy")
	var body := HUDKit.body_of(panel)

	for role in [CharacterData.Role.TANK, CharacterData.Role.RANGED_DEALER, CharacterData.Role.BUFFER]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		# 역할 패널(표식/스택/처형)은 이미 아이콘 + 이름 + 값 세 칸이다.
		# 같은 오른쪽 열에 붙는 이 패널만 글자였어서 두 패널의 줄이 어긋나 있었다.
		var icon := HUDKit.make_icon(UITheme.role_icon_name(role), ICON_SIZE)
		if icon != null:
			row.add_child(icon)

		row.add_child(HUDKit.label(CharacterData.role_to_name(role), 12, HUDKit.text_2()))

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		var value := HUDKit.value("-", 13)
		row.add_child(value)
		_synergy_rows[role] = value
		body.add_child(row)

	return panel


# 적 패널. 전장에 있는 적을 종류별로 한 줄씩 보여 준다(초상 + 이름 + 수량).
#
# 총 마릿수 숫자 하나였다. Stage1_1 처럼 두 종류가 섞여 나오면 무엇과 싸우는지
# HUD 로는 알 수 없었고, 저작된 초상(EnemyData.portrait)도 쓰이는 곳이 없었다.
func _build_enemy_panel() -> PanelContainer:
	var panel := HUDKit.make_panel("적", "ENEMY", 10, true)
	_enemy_body = HUDKit.body_of(panel)
	_enemy_panel = panel
	return panel


# 살아 있는 적을 종류별로 센다. enemy_id -> { "data": EnemyData, "count": int }
func _count_enemies() -> Dictionary:
	var counts := {}
	if GameManager == null:
		return counts

	for enemy in GameManager.get_all_enemies():
		var data: EnemyData = enemy.data if enemy != null and "data" in enemy else null
		# 데이터가 없는 적도 세기는 한다. 이름 없이 사라지면 마릿수가 틀려 보인다.
		var id: StringName = data.enemy_id if data != null else &"unknown"
		if counts.has(id):
			counts[id]["count"] += 1
		else:
			counts[id] = { "data": data, "count": 1 }
	return counts


func _update_enemies() -> void:
	if _enemy_panel == null or _enemy_body == null:
		return

	var counts := _count_enemies()

	# 적이 없으면 제목만 남은 빈 판이 전장을 가린다. 역할 패널과 같은 처리다.
	_enemy_panel.visible = not counts.is_empty()
	if counts.is_empty():
		# 다음에 적이 나타나면 줄을 다시 만든다.
		_enemy_signature = []
		return

	# 종류 구성이 그대로면 줄을 다시 만들지 않는다(매 프레임 도는 경로다).
	# 정렬한 목록으로 비교한다 — 적 노드 순서는 스폰·사망에 따라 바뀌므로
	# 그대로 비교하면 구성이 같은데도 매 프레임 다시 만들게 된다.
	var ids := counts.keys()
	ids.sort()
	if ids != _enemy_signature:
		_rebuild_enemy_rows(ids, counts)

	for id in ids:
		var label: Label = _enemy_rows.get(id)
		if label != null:
			label.text = "×%d" % int(counts[id]["count"])


# 줄 순서도 정렬한 목록을 따른다. 스폰 순서를 따르면 한 마리 죽을 때마다 순서가 튄다.
func _rebuild_enemy_rows(ids: Array, counts: Dictionary) -> void:
	for child in _enemy_body.get_children():
		_enemy_body.remove_child(child)
		child.queue_free()
	_enemy_rows.clear()
	_enemy_signature = ids.duplicate()

	for id in ids:
		var data: EnemyData = counts[id]["data"]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		# 초상이 없는 적은 tint 색 판이 들어간다(HUDKit 이 판단한다).
		row.add_child(HUDKit.enemy_portrait_block(data, Vector2(ENEMY_PORTRAIT_SIZE, ENEMY_PORTRAIT_SIZE)))

		var display_name: String = data.display_name if data != null else String(id)
		row.add_child(HUDKit.label(display_name, 12, HUDKit.text_2()))

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		var value := HUDKit.value("×0", 13)
		row.add_child(value)

		_enemy_body.add_child(row)
		_enemy_rows[id] = value


# ===== 파티 카드 (Party) =====

func _on_party_changed(_members) -> void:
	_rebuild_party_rows()


# 판이 끝났다. 멈추기 전 마지막 상태를 그린다.
func _on_stage_finished(_stage_name) -> void:
	_update_party()
	_update_enemies()

func _on_control_changed(_index: int) -> void:
	_update_party()


# 파티 편성이 바뀌면 카드를 다시 만든다.
func _rebuild_party_rows() -> void:
	var body := _find_party_body()
	if body == null:
		return

	for child in body.get_children():
		child.queue_free()
	_party_rows.clear()

	if PartySystem == null:
		return

	var members = PartySystem.get_members()
	for i in range(members.size()):
		var row := _make_party_row(i, members[i])
		body.add_child(row["root"])
		_party_rows.append(row)


func _make_party_row(index: int, character: CharacterData) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HUDKit.card_overlay(false))

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	# 전환 키 번호
	box.add_child(HUDKit.label(str(index + 1), 13, HUDKit.accent_text(), 700))

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 0)
	box.add_child(text_col)

	var name_label := HUDKit.label(character.display_name, 12, HUDKit.text_1())
	text_col.add_child(name_label)
	text_col.add_child(HUDKit.label(character.get_roles_display_name(), 10, HUDKit.text_3()))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	# 보호막은 체력과 다른 자원이라 같은 숫자에 더하면 안 된다(원거리 3단계).
	# 0이면 숨긴다 — 대부분의 판에서 이 자원은 없다.
	var shield_label := HUDKit.label("", 12, UITheme.SKY, 700)
	shield_label.visible = false
	box.add_child(shield_label)

	var hp_label := HUDKit.value("-", 13)
	box.add_child(hp_label)

	return {
		"root": panel,
		"panel": panel,
		"name": name_label,
		"hp": hp_label,
		"shield": shield_label,
		"index": index,
	}


func _update_party() -> void:
	if PartySystem == null:
		return

	for row in _party_rows:
		var index: int = row["index"]
		var node := _member_node(index)
		var controlled := PartySystem.is_controlled(index)

		# 플레이어를 카드 테두리로 강조한다(HUDKit의 선택 표시 규칙).
		(row["panel"] as PanelContainer).add_theme_stylebox_override("panel", HUDKit.card_overlay(controlled))
		(row["name"] as Label).add_theme_color_override(
			"font_color", HUDKit.text_1() if controlled else HUDKit.text_3())

		var shield_label := row["shield"] as Label
		if node == null:
			(row["hp"] as Label).text = "-"
			shield_label.visible = false
		else:
			(row["hp"] as Label).text = "%d/%d" % [node.hp, node.max_hp]

			var shield: int = node.get_shield() if node.has_method("get_shield") else 0
			shield_label.visible = shield > 0
			if shield > 0:
				shield_label.text = "+%d" % shield


# ===== 메커니즘 (Mechanics) =====

func _update_mechanics() -> void:
	var controlled := _controlled_node()

	_update_mark(controlled)
	_update_stack(controlled)
	_update_gauge(controlled)
	_update_execute(controlled)
	_update_support(controlled)

	# 세 줄이 전부 숨었으면 제목만 남은 빈 판이 전장을 가린다. 판째로 숨긴다.
	if _mechanics_panel != null:
		_mechanics_panel.visible = (
			(_mark_row != null and _mark_row.visible)
			or (_stack_row != null and _stack_row.visible)
			or (_gauge_row != null and _gauge_row.visible)
			or (_execute_row != null and _execute_row.visible)
			or (_support_row != null and _support_row.visible))



# 표식이 걸린 적 중 가장 가까운 대상의 게이지를 보여 준다.
# 적이 여러 마리일 수 있으므로 하나를 골라야 한다.
func _update_mark(controlled: Node) -> void:
	if _mark_row == null:
		return

	var target := _nearest_marked_enemy(controlled)
	if target == null:
		_mark_row.visible = false
		return

	_mark_row.visible = true
	var effect := StatusEffectDatabase.get_effect(MARK_EFFECT)
	var threshold: int = CombatConfig.tuning.mark_threshold if effect == null else effect.get_gauge_threshold()
	_mark_label.text = "%d/%d" % [StatusEffectSystem.get_gauge(target, MARK_EFFECT), threshold]


func _nearest_marked_enemy(from: Node) -> Node:
	if GameManager == null or StatusEffectSystem == null:
		return null

	var origin := (from as Node2D).global_position if from is Node2D else Vector2.ZERO
	var nearest: Node = null
	var nearest_distance := INF

	for enemy in GameManager.get_all_enemies():
		if not StatusEffectSystem.has_effect(enemy, MARK_EFFECT):
			continue
		var distance := origin.distance_to((enemy as Node2D).global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


# 스택은 플레이어가 원거리 메커니즘을 쓸 수 있을 때만 의미가 있다.
func _update_stack(controlled: Node) -> void:
	if _stack_row == null:
		return

	if controlled == null or not controlled.has_method("get_stack_count"):
		_stack_row.visible = false
		return

	if not controlled._is_role_active(CharacterData.Role.RANGED_DEALER):
		_stack_row.visible = false
		return

	_stack_row.visible = true
	var count: int = controlled.get_stack_count()
	var maximum: int = CombatConfig.tuning.stack_max
	_stack_label.text = "%d/%d" % [count, maximum]

	var ratio := 0.0 if maximum <= 0 else float(count) / float(maximum)
	_set_meter(_stack_track, _stack_fill, ratio)


# 캐릭터 개성 게이지(#259). 지금은 미나만 갖는다.
# 게이지를 쓰는 스킬이 게이지 양에 비례해 세지므로, 보이지 않으면 조작할 수 없는 자원이다.
func _update_gauge(controlled: Node) -> void:
	if _gauge_row == null:
		return

	if controlled == null or not controlled.has_method("has_skill_gauge") or not controlled.has_skill_gauge():
		_gauge_row.visible = false
		return

	_gauge_row.visible = true
	var value: int = controlled.get_skill_gauge()
	var maximum: int = controlled.get_skill_gauge_max()
	_gauge_label.text = "%d/%d" % [value, maximum]
	_set_meter(_gauge_track, _gauge_fill, controlled.get_skill_gauge_ratio())


# ===== 고유 스킬 (Unique skills) =====

# Q·E 슬롯의 상태를 한 줄씩 보여 준다(#263).
#
# 값의 출처는 전부 조종 중인 Player 노드다. 여기서 쿨타임을 세지 않는다.
func _update_skills() -> void:
	if _skill_panel == null:
		return

	var controlled := _controlled_node()
	_update_skill_slot(controlled, SkillData.InputSlot.Q, _skill_q_row, _skill_q_label)
	_update_skill_slot(controlled, SkillData.InputSlot.E, _skill_e_row, _skill_e_label)

	_skill_panel.visible = (
		(_skill_q_row != null and _skill_q_row.visible)
		or (_skill_e_row != null and _skill_e_row.visible))


# 한 슬롯의 줄. 슬롯이 비어 있으면 그 줄을 숨긴다.
#
# 표시 우선순위: 시전 중 > 걸린 창 > 쿨타임 > 준비됨.
# 지금 벌어지는 일이 남은 시간보다 먼저 보여야 한다.
func _update_skill_slot(controlled: Node, slot: int, row: Control, label: Label) -> void:
	if row == null:
		return

	var skill := _skill_in_slot(controlled, slot)
	if skill == null:
		row.visible = false
		return

	row.visible = true
	label.text = _skill_status_text(controlled, skill)


# 조종 중인 캐릭터의 이 슬롯에 걸린 스킬. 슬롯 해석의 출처는 CharacterData 다.
func _skill_in_slot(controlled: Node, slot: int) -> SkillData:
	if controlled == null:
		return null
	var character = controlled.get("data")
	if character == null:
		return null
	return character.get_skill_for_slot(slot)


func _skill_status_text(controlled: Node, skill: SkillData) -> String:
	# 시전 중: 이 스킬이 지금 캐스트되고 있으면 남은 캐스트를 보여 준다.
	# 캐스트는 공속으로 짧아지므로(#263) 여기 숫자가 강화의 결과이기도 하다.
	if controlled.is_casting() and controlled._cast_skill == skill:
		return "시전 %.1f" % controlled.get_cast_time_left()

	# 평타 체인 창이 이 스킬로 열려 있으면 남은 창을 보여 준다.
	if controlled.is_chain_window_open() and controlled._chain_skill == skill:
		return "체인 %.1f" % controlled.get_chain_time_left()

	var cooldown_left: float = controlled.get_skill_cooldown_left(skill.skill_id)
	if cooldown_left > 0.0:
		return "%.1f" % cooldown_left
	return "준비"


# 처형은 버퍼를 조종 중이고 조건을 만족한 적이 있을 때만 뜬다.
func _update_execute(controlled: Node) -> void:
	if _execute_row == null:
		return

	if controlled == null or not controlled.has_method("can_execute"):
		_execute_row.visible = false
		return

	if not controlled._is_role_active(CharacterData.Role.BUFFER):
		_execute_row.visible = false
		return

	var found := false
	for enemy in GameManager.get_all_enemies():
		if StatusEffectSystem.has_any_debuff(enemy) and controlled.can_execute(enemy):
			found = true
			break

	_execute_row.visible = found
	if found:
		(_execute_row.get_meta("value") as Label).text = "가능"


# 버퍼 3단계의 보류 피해(#369). 쌓인 것이 있을 때만 뜬다.
#
# 처형 줄과 나눠 두는 이유: 처형은 **적 쪽 조건**(디버프 + 체력)이라 때릴 대상이 있어야
# 뜨지만, 이쪽은 **내가 쌓아 둔 것**이라 적이 없어도 있다. 한 줄로 묶으면 "지금 때리면
# 이만큼 더 들어간다"가 적 상태에 가려진다.
func _update_support(controlled: Node) -> void:
	if _support_row == null:
		return

	if controlled == null or not controlled.has_method("get_buffer_pending_damage"):
		_support_row.visible = false
		return

	var pending: int = controlled.get_buffer_pending_damage()
	_support_row.visible = pending > 0
	if pending > 0:
		(_support_row.get_meta("value") as Label).text = "+%d" % pending


# ===== 시너지 (Synergy) =====

# 카운트와 활성 단계를 함께 보여 준다.
# 2카운트인데 비활성인 상태(죽은 구간)가 드러나야 하므로 둘을 나눠 표시한다.
func _update_synergy() -> void:
	if PartySystem == null or SynergySystem == null:
		return

	var members = PartySystem.get_members()
	var counts := SynergySystem.get_role_counts(members)
	var tiers := SynergySystem.get_active_tiers(members)

	for role in _synergy_rows:
		var label: Label = _synergy_rows[role]
		var count: int = counts.get(role, 0)
		var tier = tiers.get(role, SynergySystem.Tier.NONE)
		label.text = "%d · %s" % [count, SynergySystem.tier_to_name(tier)]
		# 활성이면 액센트, 비활성이면 흐리게. 2카운트 비활성이 눈에 띄어야 한다.
		label.add_theme_color_override(
			"font_color", HUDKit.accent_text() if tier != SynergySystem.Tier.NONE else HUDKit.text_3())


# ===== 조회 (Lookup) =====

func _find_party_body() -> VBoxContainer:
	for node in _all_descendants(self):
		if node is VBoxContainer and node.name == "PartyBody":
			return node
	return null


func _all_descendants(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all_descendants(child))
	return out


# 파티 인덱스에 해당하는 씬 노드. 그룹 이름의 출처는 PartySystem이다.
func _member_node(index: int) -> Node:
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if node.party_index == index:
			return node
	return null


func _controlled_node() -> Node:
	if PartySystem == null:
		return null
	return _member_node(PartySystem.get_controlled_index())

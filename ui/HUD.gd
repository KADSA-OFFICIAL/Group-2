extends CanvasLayer
class_name HUD

# 전투 화면 HUD.
#
# 표시하는 것 (docs/combat-screen-design.md §6 중 **현재 구현된 것만**):
#   - 파티 3인 카드: 이름/역할/HP, 조종 중인 1명 강조, 전환 키(1/2/3)
#   - 역할 메커니즘 상태: 표식 게이지 / 원거리 스택 / 처형 가능
#   - 역할군 시너지: 카운트와 활성 단계 (2카운트 비활성이 드러나야 한다)
#
# 아직 표시하지 않는 것: 보호막(자원 없음), 점령 게이지(스테이지 타입 미구현),
#   스킬 쿨다운(스킬 없음).
#
# 값의 출처:
#   파티/조종  -> PartySystem
#   시너지     -> SynergySystem
#   표식       -> StatusEffectSystem
#   스택       -> Player.get_stack_count()
#   수치       -> CombatConfig.tuning
#   색·아이콘  -> UITheme / HUDKit
# 여기서 계산하거나 색을 새로 만들지 않는다. 읽어서 그리기만 한다.

const MARK_EFFECT := &"mark"

# 아이콘 크기. HUD는 메타 화면보다 작게 쓴다.
const ICON_SIZE: int = 18
const ICON_SIZE_SMALL: int = 14

var _party_rows: Array = []          # [{ "root": Control, "name": Label, "hp": Label, "bracket": Control }]
var _synergy_rows: Dictionary = {}   # Role -> Label
var _mark_row: Control
var _mark_label: Label
var _stack_row: Control
var _stack_label: Label
var _stack_fill: ColorRect
var _stack_track: Control
var _execute_row: Control
var _enemy_label: Label
# 역할 패널. 안의 세 줄이 전부 숨으면 제목만 남은 빈 판이 되므로 통째로 숨긴다.
var _mechanics_panel: PanelContainer


func _ready() -> void:
	name = "HUD"
	_build()

	if EventBus:
		EventBus.party_changed.connect(_on_party_changed)
		EventBus.party_control_changed.connect(_on_control_changed)

	_rebuild_party_rows()


func _process(_delta: float) -> void:
	_update_party()
	_update_mechanics()
	_update_synergy()


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

	# 좌상단: 파티 / 메커니즘, 우상단: 시너지 / 적 수
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
	right.add_child(_build_synergy_panel())
	right.add_child(_build_enemy_panel())


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

	_stack_row = _build_stack_row()
	body.add_child(_stack_row)

	_execute_row = _make_icon_row("icon_execute", "처형 가능", "")
	body.add_child(_execute_row)

	_mechanics_panel = panel
	return panel


# 스택은 숫자만으로는 "차고 빠지는 것"이 안 보인다. 가는 게이지를 함께 둔다.
func _build_stack_row() -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var top := _make_icon_row("icon_stack", "스택", "")
	_stack_label = top.get_meta("value")
	row.add_child(top)

	_stack_track = PanelContainer.new()
	_stack_track.add_theme_stylebox_override("panel", HUDKit.inset(0))
	_stack_track.custom_minimum_size = Vector2(120, 6)
	row.add_child(_stack_track)

	_stack_fill = ColorRect.new()
	_stack_fill.color = UITheme.ACCENT  # 면을 칠하는 것이라 원본 앰버가 맞다
	_stack_fill.custom_minimum_size = Vector2(0, 6)
	_stack_track.add_child(_stack_fill)

	return row


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


func _build_enemy_panel() -> PanelContainer:
	var panel := HUDKit.make_panel("", "", 10, true)
	var body := HUDKit.body_of(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(HUDKit.label("적", 12, HUDKit.text_2()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_enemy_label = HUDKit.value("0", 13)
	row.add_child(_enemy_label)
	body.add_child(row)
	return panel


# ===== 파티 카드 (Party) =====

func _on_party_changed(_members) -> void:
	_rebuild_party_rows()

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

	var hp_label := HUDKit.value("-", 13)
	box.add_child(hp_label)

	return {
		"root": panel,
		"panel": panel,
		"name": name_label,
		"hp": hp_label,
		"index": index,
	}


func _update_party() -> void:
	if PartySystem == null:
		return

	for row in _party_rows:
		var index: int = row["index"]
		var node := _member_node(index)
		var controlled := PartySystem.is_controlled(index)

		# 조종 중인 멤버를 카드 테두리로 강조한다(HUDKit의 선택 표시 규칙).
		(row["panel"] as PanelContainer).add_theme_stylebox_override("panel", HUDKit.card_overlay(controlled))
		(row["name"] as Label).add_theme_color_override(
			"font_color", HUDKit.text_1() if controlled else HUDKit.text_3())

		if node == null:
			(row["hp"] as Label).text = "-"
		else:
			(row["hp"] as Label).text = "%d/%d" % [node.hp, node.max_hp]


# ===== 메커니즘 (Mechanics) =====

func _update_mechanics() -> void:
	var controlled := _controlled_node()

	_update_mark(controlled)
	_update_stack(controlled)
	_update_execute(controlled)

	# 세 줄이 전부 숨었으면 제목만 남은 빈 판이 전장을 가린다. 판째로 숨긴다.
	if _mechanics_panel != null:
		_mechanics_panel.visible = (
			(_mark_row != null and _mark_row.visible)
			or (_stack_row != null and _stack_row.visible)
			or (_execute_row != null and _execute_row.visible))

	if _enemy_label != null and GameManager != null:
		_enemy_label.text = str(GameManager.get_all_enemies().size())


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


# 스택은 조종 중인 멤버가 원거리 메커니즘을 쓸 수 있을 때만 의미가 있다.
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

	# 게이지 채움. 트랙 폭에 비례해 늘린다.
	var ratio := 0.0 if maximum <= 0 else clampf(float(count) / float(maximum), 0.0, 1.0)
	var track_width: float = _stack_track.size.x
	if track_width <= 0.0:
		track_width = _stack_track.custom_minimum_size.x
	_stack_fill.custom_minimum_size = Vector2(track_width * ratio, 6)
	_stack_fill.size = Vector2(track_width * ratio, 6)


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

extends Control

# 스테이지 선택 화면 (메타 UI).
#
# 책임: 저작된 스테이지를 나열하고, 고른 스테이지로 출격한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   스테이지 목록/정의 -> StageDatabase / StageData
#   승리 조건          -> StageData.get_objectives_display_name()
#                        (타입->조건 대응을 화면에서 다시 쓰지 않는다)
#   색·조각            -> UITheme / HUDKit
#
# 아직 저작된 스테이지가 없다 (data/stages 가 비어 있다).
# 그래서 목록이 비었을 때를 정상 상태로 다루고, 지금까지처럼 바로 출격할 수 있는
# 길을 남겨 둔다. 스테이지가 저작되면 목록이 자동으로 채워진다.
#
# 참고: docs/combat-screen-design.md §5, data/stages/README.md

# 승리 조건 프리미티브 -> 아이콘 이름. 조건의 출처는 StageData.Objective 이고,
# 그 조건이 어떤 그림을 쓰는지는 이 화면이 정한다(장비 슬롯 아이콘과 같은 규약).
const OBJECTIVE_ICON_NAME := {
	StageData.Objective.CLEAR: "icon_battle",
	StageData.Objective.CAPTURE: "icon_capture",
}

# 편성 화면은 경로만 둔다. 출격은 이 화면 -> 편성(출격 모드) 한 방향이라 순환은 아니지만,
# 화면끼리 preload 하지 않는 이 프로젝트의 규약을 따른다.
const FORMATION_SCREEN_PATH := "res://screens/formation/FormationScreen.tscn"

var _list_holder: VBoxContainer


func _ready() -> void:
	_build()
	_refresh()


# ===== 화면 구성 =====

func _build() -> void:
	add_child(HUDKit.make_backdrop())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(HUDKit.make_header("출격", "sortie", "icon_battle"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list_holder = VBoxContainer.new()
	_list_holder.add_theme_constant_override("separation", 10)
	_list_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_holder)



# ===== 목록 =====

func _refresh() -> void:
	if not is_instance_valid(_list_holder):
		return
	_clear(_list_holder)

	var ids := StageDatabase.get_all_ids()
	if ids.is_empty():
		_list_holder.add_child(_empty_notice())
		return

	for id in ids:
		_list_holder.add_child(_make_stage_card(id))


# 저작된 스테이지가 없을 때. 오류가 아니라 정상 상태다.
# 지금까지 출격 버튼이 하던 일(화면 닫고 게임플레이 진입)을 여기서 이어 준다.
func _empty_notice() -> Control:
	var panel := HUDKit.empty_notice(
		"저작된 스테이지가 없습니다.",
		"data/stages 에 StageData(.tres)를 저작하면 여기 나타납니다.")

	var box := panel.get_meta("body") as VBoxContainer

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(actions)

	var button := HUDKit.make_cta("현재 스테이지로 출격", "launch")
	button.pressed.connect(_on_launch_pressed)
	actions.add_child(button)
	return panel


func _make_stage_card(id: StringName) -> Control:
	var stage := StageDatabase.get_stage(id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HUDKit.card())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	if stage == null:
		info.add_child(HUDKit.label(String(id), 16, HUDKit.text_1(), 700))
		return card

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	title_row.add_child(HUDKit.label(stage.display_name, 17, HUDKit.text_1(), 700))
	# 타입 이름과 승리 조건 문구의 출처는 StageData 다.
	title_row.add_child(HUDKit.tag_chip(stage.get_type_name(), UITheme.SKY))

	info.add_child(_objective_row(stage))

	if not stage.description.is_empty():
		var desc := HUDKit.label(stage.description, 12, HUDKit.text_3())
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)

	var button := HUDKit.make_cta("출격", "go")
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_stage_launch_pressed.bind(id))
	row.add_child(button)
	return card


# 승리 조건 한 줄. 조건마다 아이콘 + 이름 칩을 둔다.
#
# 글자 한 줄("승리 조건: 소탕 + 점령")이었다. 카드가 늘어나면 이 줄은 설명문과
# 같은 높이·같은 색이라 눈에 걸리지 않는다. 조건은 카드를 고르는 기준이므로
# 아이콘으로 먼저 읽히게 한다. 이름 문구의 출처는 그대로 StageData 다.
func _objective_row(stage: StageData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	row.add_child(HUDKit.label("승리 조건", 13, HUDKit.text_3()))

	for objective in stage.get_objectives():
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", HUDKit.inset(4))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)

		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		chip.add_child(box)

		var icon := HUDKit.make_icon(OBJECTIVE_ICON_NAME.get(objective, ""), 18)
		if icon != null:
			box.add_child(icon)

		box.add_child(HUDKit.label(StageData.objective_to_name(objective), 13, HUDKit.text_2(), 600))

	return row


# ===== 조작 =====

# 고른 스테이지로 출격한다 — **파티를 먼저 고른다**(#243).
#
# 여기서 스테이지를 시작하지 않는 이유: 파티 선택 화면에서 뒤로 돌아올 수 있어야 하고,
# 그때 이미 전투가 시작되어 있으면 안 된다. 실제 시작은 편성 화면이 확정할 때 한다.
#
# 어떤 스테이지를 플레이 중인지는 StageSystem 이 안다. 이 화면은 id 만 넘기고,
# 전장을 그 배치로 다시 만드는 일은 Stage 노드가 한다(화면은 전장을 모른다).
#
# 승리 조건 판정(소탕 완료 / 점령 게이지)은 아직 없다. 지금은 그 스테이지의
# 배치로 전투가 시작되는 데까지다.
func _on_stage_launch_pressed(id: StringName) -> void:
	_open_party_select(id)


# 저작된 스테이지가 없을 때의 출격. 현재 전장을 그대로 드러낸다.
# 이때도 파티는 고르게 한다 — 고를 스테이지가 없을 뿐 파티는 고를 수 있다.
func _on_launch_pressed() -> void:
	_open_party_select(&"")


# 파티 선택 화면을 출격 모드로 띄운다.
#
# 새 화면을 만들지 않고 편성 화면(FormationScreen)을 재사용한다 — 로스터·파티·시너지를
# 읽는 UI 를 두 벌 두면 한쪽만 고쳐지는 일이 생긴다(CLAUDE.md 기초 시스템).
func _open_party_select(stage_id: StringName) -> void:
	var scene := load(FORMATION_SCREEN_PATH) as PackedScene
	if scene == null:
		push_warning("StageSelectScreen: 편성 화면을 불러올 수 없습니다: " + FORMATION_SCREEN_PATH)
		# 파티를 고를 수 없더라도 출격 자체는 막지 않는다(기존 편성으로 나간다).
		if not String(stage_id).is_empty():
			StageSystem.request_stage(stage_id)
		ScreenManager.close_all()
		return

	var screen := ScreenManager.push(scene)
	if screen == null:
		return
	screen.set_sortie(stage_id)


# ===== 공용 조각 =====

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

extends Control

# 우편 화면 (메타 UI).
#
# 책임: 우편 목록을 보여주고 수령을 MailSystem 에 위임한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   우편 목록·수령 -> MailSystem (get_all / claim / claim_all)
#   장비 이름      -> EquipmentDatabase
#   재화           -> CurrencySystem (지급은 MailSystem 이 한다)
#   색·조각        -> UITheme / HUDKit
#
# 첨부를 화면에서 지급하지 않는다. claim() 으로 시킬 뿐이다.

var _list_holder: VBoxContainer
var _claim_all_button: Button


func _ready() -> void:
	_build()
	_refresh()

	# 다른 경로로 우편이 들어오거나 수령돼도 표시가 따라오게 한다.
	EventBus.mail_added.connect(func(_id): _refresh())
	EventBus.mail_claimed.connect(func(_id): _refresh())


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

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	head.add_child(HUDKit.make_header("우편", "mail", "icon_mail"))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)

	# "모두 받기" 는 이 화면의 주 동작이므로 CTA 로 둔다.
	_claim_all_button = HUDKit.make_cta("모두 받기", "claim all")
	_claim_all_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_claim_all_button.pressed.connect(_on_claim_all_pressed)
	head.add_child(_claim_all_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list_holder = VBoxContainer.new()
	_list_holder.add_theme_constant_override("separation", 10)
	_list_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_holder)

	HUDKit.play_enter([head, scroll])


# ===== 갱신 =====

func _refresh() -> void:
	if not is_instance_valid(_list_holder):
		return
	_clear(_list_holder)

	var mails := MailSystem.get_all()
	if mails.is_empty():
		_list_holder.add_child(HUDKit.empty_notice(
			"받은 우편이 없습니다.",
			"보상·이벤트가 우편으로 들어오면 여기 쌓입니다."))
	else:
		# 받지 않은 우편을 위로 올린다. 할 일이 먼저 보이는 편이 낫다.
		var unclaimed: Array[Dictionary] = []
		var claimed: Array[Dictionary] = []
		for mail in mails:
			if bool(mail["claimed"]):
				claimed.append(mail)
			else:
				unclaimed.append(mail)
		for mail in unclaimed:
			_list_holder.add_child(_make_mail_card(mail))
		for mail in claimed:
			_list_holder.add_child(_make_mail_card(mail))

	_refresh_claim_all()


func _refresh_claim_all() -> void:
	if not is_instance_valid(_claim_all_button):
		return
	_claim_all_button.disabled = not MailSystem.has_unclaimed()


func _make_mail_card(mail: Dictionary) -> Control:
	var claimed := bool(mail["claimed"])

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HUDKit.card())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 수령한 우편은 한 톤 죽여 남은 것과 구분한다.
	# 카드 면 색을 바꾸지 않고 전체를 흐리게 하는 이유: 새 킷의 카드는 흰 면 하나뿐이라
	# "한 톤 어두운 카드" 라는 변형이 없다. 밝은 톤에서는 그 변형이 잘 보이지도 않는다.
	if claimed:
		card.modulate = Color(1, 1, 1, 0.62)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	# 미수령 표시는 점 하나. 메인화면 우편 버튼과 같은 표시를 쓴다.
	if not claimed:
		title_row.add_child(HUDKit.new_dot(10))
	title_row.add_child(HUDKit.label(String(mail["title"]), 16, HUDKit.text_1(), 700))
	if claimed:
		title_row.add_child(HUDKit.tag_chip("수령 완료", UITheme.STONE_DARK))

	var body := String(mail["body"])
	if not body.is_empty():
		var body_label := HUDKit.label(body, 13, HUDKit.text_2())
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(body_label)

	var attachment := _attachment_row(mail)
	if attachment != null:
		info.add_child(attachment)

	var button := HUDKit.make_ghost("받기", 110) if claimed else HUDKit.make_cta("받기", "claim")
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = claimed
	button.pressed.connect(_on_claim_pressed.bind(int(mail["id"])))
	row.add_child(button)
	return card


# 첨부 표시. 첨부가 없으면 null 을 돌려 줄을 만들지 않는다(빈 줄은 난잡하다).
func _attachment_row(mail: Dictionary) -> Control:
	var currencies: Dictionary = mail.get("currencies", {})
	var equipment: Dictionary = mail.get("equipment", {})
	if currencies.is_empty() and equipment.is_empty():
		return null

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	for currency_type in currencies:
		row.add_child(HUDKit.currency_chip(
			String(currency_type), "x%s" % HUDKit.comma(int(currencies[currency_type]))))

	for raw in equipment:
		# 장비 표시 이름의 출처는 EquipmentDatabase 다.
		var item := EquipmentDatabase.get_equipment(StringName(raw))
		var label := item.display_name if item != null else String(raw)
		row.add_child(HUDKit.tag_chip("%s x%d" % [label, int(equipment[raw])], UITheme.SKY))

	return row


# ===== 조작 =====

func _on_claim_pressed(mail_id: int) -> void:
	MailSystem.claim(mail_id)


func _on_claim_all_pressed() -> void:
	MailSystem.claim_all()


# ===== 공용 조각 =====

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

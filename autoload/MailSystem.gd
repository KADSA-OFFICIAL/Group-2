extends Node

# 우편함의 단일 출처 (autoload).
#
# 책임: 받은 우편 목록을 보유하고, 첨부를 수령해 실제 지급까지 시킨다.
#
# 우편 **내용을 여기서 만들지 않는다.** 우편은 런타임에 들어온다:
#   보상 지급, 이벤트, 공지 등이 add_mail() 로 넣는다.
#   그래서 .tres 로 저작하는 데이터베이스가 없고, 시작 시 우편함은 비어 있다.
#   (스테이지·상점과 다른 점이다. 그쪽은 저작 데이터이고 이쪽은 발생 데이터다.)
#
# 단일 출처 원칙 (여기서 다시 정의하지 않는다):
#   재화 지급 -> CurrencySystem.add_currency()
#   장비 지급 -> EquipmentSystem.grant()
#   장비 정의 -> EquipmentDatabase
#
# 저장 대상이다. 우편은 받은 뒤 게임을 꺼도 남아 있어야 한다.

# 저장 스키마에서 우편함이 들어가는 키.
const SAVE_KEY := "mail"

# 우편 하나의 구조 (Dictionary):
#   id          int              고유 번호. 이 시스템이 발급한다.
#   title       String           제목
#   body        String           본문
#   currencies  Dictionary       재화 첨부. 재화 id -> 수량
#   equipment   Dictionary       장비 첨부. equipment_id(String) -> 개수
#   claimed     bool             첨부를 수령했는가
#
# 첨부가 없는 우편(공지 등)도 유효하다. 그때 수령은 "읽음 처리"와 같다.

# 우편 목록. 먼저 들어온 것이 앞이다.
var _mails: Array[Dictionary] = []

# 다음에 발급할 우편 번호. 저장/복원 대상이다(재시작 후 번호가 겹치면 안 된다).
var _next_id: int = 1


func _ready() -> void:
	name = "MailSystem"
	# 저장 스키마의 우편 부분은 이 시스템이 소유한다(SaveSystem 은 내부를 모른다).
	SaveSystem.register_provider(SAVE_KEY, self)


# ===== 발송 (Inbound) =====

# 우편을 넣는다. 발급한 우편 번호를 반환한다(실패 시 -1).
#
# 첨부는 넣는 쪽이 준다. 여기서 보상 내용을 만들지 않는다.
func add_mail(title: String, body: String = "", currencies: Dictionary = {}, equipment: Dictionary = {}) -> int:
	if title.is_empty():
		push_warning("MailSystem: 제목이 없는 우편은 넣지 않습니다.")
		return -1

	var mail := {
		"id": _next_id,
		"title": title,
		"body": body,
		"currencies": currencies.duplicate(),
		"equipment": equipment.duplicate(),
		"claimed": false,
	}
	_next_id += 1
	_mails.append(mail)

	EventBus.mail_added.emit(mail["id"])
	return mail["id"]


# ===== 조회 (Query) =====

# 우편 목록 사본. 외부에서 내부 배열을 변형하지 못하게 한다.
func get_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mail in _mails:
		out.append(mail.duplicate(true))
	return out


func get_count() -> int:
	return _mails.size()


# 아직 수령하지 않은 우편 수. 메인화면 배지가 이 값을 읽는다.
func get_unclaimed_count() -> int:
	var n := 0
	for mail in _mails:
		if not bool(mail["claimed"]):
			n += 1
	return n


func has_unclaimed() -> bool:
	return get_unclaimed_count() > 0


# ===== 수령 (Claim) =====

# 우편 하나의 첨부를 수령한다. 이미 수령했으면 아무것도 하지 않는다.
func claim(mail_id: int) -> bool:
	var mail := _find(mail_id)
	if mail.is_empty():
		push_warning("MailSystem: 알 수 없는 우편 번호: " + str(mail_id))
		return false
	if bool(mail["claimed"]):
		return false

	_grant_attachments(mail)
	mail["claimed"] = true
	EventBus.mail_claimed.emit(mail_id)
	return true


# 수령하지 않은 우편을 모두 수령한다. 수령한 개수를 반환한다.
func claim_all() -> int:
	var n := 0
	# 목록을 복사하지 않고 순회해도 안전하다(claim 은 목록 크기를 바꾸지 않는다).
	for mail in _mails:
		if not bool(mail["claimed"]):
			_grant_attachments(mail)
			mail["claimed"] = true
			EventBus.mail_claimed.emit(int(mail["id"]))
			n += 1
	return n


# 첨부를 실제로 지급한다. 지급 주체는 각 시스템이다.
func _grant_attachments(mail: Dictionary) -> void:
	var currencies: Dictionary = mail.get("currencies", {})
	for currency_type in currencies:
		var amount := int(currencies[currency_type])
		if amount > 0:
			CurrencySystem.add_currency(String(currency_type), amount)

	var equipment: Dictionary = mail.get("equipment", {})
	for raw in equipment:
		var count := int(equipment[raw])
		if count > 0:
			EquipmentSystem.grant(StringName(raw), count)


func _find(mail_id: int) -> Dictionary:
	for mail in _mails:
		if int(mail["id"]) == mail_id:
			return mail
	return {}


# ===== 저장/복원 (Save / Load) =====
# SaveSystem 은 이 두 함수만 호출한다.

func to_save_dict() -> Dictionary:
	var out: Array = []
	for mail in _mails:
		out.append(mail.duplicate(true))
	return {
		"next_id": _next_id,
		"mails": out,
	}


func from_save_dict(data: Dictionary) -> void:
	_mails.clear()
	for raw in data.get("mails", []):
		if not (raw is Dictionary):
			continue
		# 누락된 키는 기본값으로 채운다(구 세이브 호환).
		_mails.append({
			"id": int(raw.get("id", 0)),
			"title": String(raw.get("title", "")),
			"body": String(raw.get("body", "")),
			# JSON 에는 정수 타입이 없어 수량이 float 로 돌아온다(500 -> 500.0).
			# 첨부 수량은 개수이므로 정수로 되돌려 놓는다.
			"currencies": _to_int_counts(raw.get("currencies", {})),
			"equipment": _to_int_counts(raw.get("equipment", {})),
			"claimed": bool(raw.get("claimed", false)),
		})

	# 번호가 겹치지 않도록, 저장값과 실제 최대 번호 중 큰 쪽 다음부터 발급한다.
	# (세이브가 손상돼 next_id 가 작게 들어와도 기존 우편과 충돌하지 않게 한다.)
	var max_id := 0
	for mail in _mails:
		max_id = maxi(max_id, int(mail["id"]))
	_next_id = maxi(int(data.get("next_id", 1)), max_id + 1)


# "키 -> 수량" 딕셔너리의 수량을 정수로 맞춘다.
func _to_int_counts(source) -> Dictionary:
	var out := {}
	if not (source is Dictionary):
		return out
	for key in source:
		out[key] = int(source[key])
	return out

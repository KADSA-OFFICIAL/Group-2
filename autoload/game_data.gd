## res://autoload/game_data.gd
## Autoload 이름: GameData
## 플레이어/재화/전투력의 단일 원천(source of truth).
## UI 는 여기 값을 읽고 시그널을 구독만 한다. UI 가 값을 들고 있지 않는다.

extends Node

signal stamina_changed(current: int, maximum: int)
signal currency_changed(kind: String, amount: int)

# ── 플레이어 ──
var player_name: String = "별고래"
var level: int = 73
var is_max_level: bool = true
var exp_current: int = 6200
var exp_to_next: int = 10000

# ── 재화 ──
var stamina: int = 93
var stamina_max: int = 206
var gold: int = 130_605_248
var gems: int = 51_118
var faction_token: int = 1_250
var sweep_tickets: int = 40

# ── 전투 ──
var combat_power: int = 48_200

func spend_stamina(amount: int) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	stamina_changed.emit(stamina, stamina_max)
	return true

func add_currency(kind: String, amount: int) -> void:
	match kind:
		"gold": gold += amount
		"gems": gems += amount
		"faction_token": faction_token += amount
		"sweep_tickets": sweep_tickets += amount
		_:
			push_warning("unknown currency: %s" % kind)
			return
	currency_changed.emit(kind, amount)

func stamina_text() -> String:
	return "%d / %d" % [stamina, stamina_max]

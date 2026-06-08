## res://autoload/game_data.gd
## Autoload 이름: GameData
## 플레이어/재화/전투력의 단일 원천(source of truth).
## UI 는 여기 값을 읽고 시그널을 구독만 한다. UI 가 값을 들고 있지 않는다.

extends Node

# ── 플레이어 ──
var player_name: String = "별고래"
var level: int = 73
var is_max_level: bool = true
var exp_current: int = 6200
var exp_to_next: int = 10000

# ── 전투 ──
var combat_power: int = 48_200

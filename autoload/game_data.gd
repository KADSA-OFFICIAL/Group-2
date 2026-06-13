## res://autoload/game_data.gd
## Autoload 이름: GameData
## 플레이어/재화/전투력의 단일 원천(source of truth).
## UI 는 여기 값을 읽고 시그널을 구독만 한다.

extends Node

signal stamina_changed(current: int, maximum: int)
signal currency_changed(kind: String, amount: int)
signal roster_changed

# ── 플레이어 ──
var player_name: String = "별고래"
var level: int = 73
var is_max_level: bool = true
var exp_current: int = 6200
var exp_to_next: int = 10000
var title: String = "t1"
var avatar: String = "🦊"
var cleared: int = 8

# ── 재화 ──
var stamina: int = 93
var stamina_max: int = 206
var gold: int = 130_605_248
var gems: int = 51_118
var faction_token: int = 1_250
var sweep_tickets: int = 40

# ── 전투 ──
var combat_power: int = 48_200

# ── 스탯 ──
var stats: Dictionary = {
	"clears": 0, "pulls": 0, "levelups": 0, "crafts": 0, "promos": 0
}

# ── 재료 ──
var mats: Dictionary = {"book": 12, "ore": 8, "dust": 40, "book2": 0}

# ── 클레임/구매 상태 ──
var mission_claims: Dictionary = {}
var shop_buys: Dictionary = {}
var guild_buys: Dictionary = {}
var guild_checked: bool = false
var event_coin: int = 0
var event_claims: Dictionary = {}
var event_buys: Dictionary = {}
var pass_claims: Dictionary = {}
var pass_premium: bool = false
var quest_claims: Dictionary = {}

# ── 출석 ──
var attend: Dictionary = {"day": 0, "done_today": false}

# ── 제조 큐 ──
var craft_queue: Array = []

# ── 설정 ──
var settings: Dictionary = {
	"bgm": false, "bgm_vol": 0.5, "sfx": true, "sfx_vol": 0.5,
	"quality": "중", "shake": true, "dmg": true
}

# ── 전투 컨텍스트 ──
var battle: Dictionary = {
	"code": "33-9", "n": 9, "reco": 52400, "hard": false, "team": [], "team_power": 0
}

# ── 로스터 ──
var roster: Array[Dictionary] = [
	{id="luna", n="루나",  r=3, lv=62, pw=11200, role="공격", weapon="bolt",   c1="#ff9ad1", c2="#d23f8c", shards=0},
	{id="sera", n="세라",  r=3, lv=60, pw=10800, role="지원", weapon="spread", c1="#7fe9ff", c2="#2aa9d8", shards=0},
	{id="kai",  n="카이",  r=3, lv=58, pw=10500, role="공격", weapon="rapid",  c1="#ffc77f", c2="#e8902e", shards=0},
	{id="mira", n="미라",  r=2, lv=57, pw=10200, role="방어", weapon="melee",  c1="#b6a8ff", c2="#7a4fd1", shards=0},
	{id="arin", n="아린",  r=2, lv=55, pw=9900,  role="공격", weapon="pierce", c1="#9affc0", c2="#3fbf74", shards=0},
	{id="nova", n="노바",  r=2, lv=53, pw=9600,  role="지원", weapon="nova",   c1="#ff9a9a", c2="#d24f4f", shards=0},
	{id="rico", n="리코",  r=2, lv=50, pw=9200,  role="공격", weapon="bolt",   c1="#c9a8ff", c2="#9a4fd1", shards=0},
	{id="yuna", n="유나",  r=1, lv=48, pw=8800,  role="방어", weapon="melee",  c1="#a8d8ff", c2="#4f8fd1", shards=0},
	{id="pen",  n="펜",    r=1, lv=45, pw=8400,  role="공격", weapon="rapid",  c1="#ffd89a", c2="#d1a04f", shards=0},
	{id="del",  n="델",    r=1, lv=43, pw=8000,  role="지원", weapon="spread", c1="#d8ff9a", c2="#9ad14f", shards=0},
	{id="homu", n="호무",  r=1, lv=40, pw=7600,  role="방어", weapon="melee",  c1="#ffb0c8", c2="#d14f7a", shards=0},
	{id="kira", n="키라",  r=1, lv=38, pw=7000,  role="공격", weapon="pierce", c1="#b0ffe8", c2="#4fd1b0", shards=0},
]

# ── 가챠 풀 (로스터 + 미보유 캐릭터) ──
var pool: Array[Dictionary] = [
	{id="luna",  n="루나",  r=3, role="공격", weapon="bolt",   c1="#ff9ad1", c2="#d23f8c"},
	{id="sera",  n="세라",  r=3, role="지원", weapon="spread", c1="#7fe9ff", c2="#2aa9d8"},
	{id="kai",   n="카이",  r=3, role="공격", weapon="rapid",  c1="#ffc77f", c2="#e8902e"},
	{id="mira",  n="미라",  r=2, role="방어", weapon="melee",  c1="#b6a8ff", c2="#7a4fd1"},
	{id="arin",  n="아린",  r=2, role="공격", weapon="pierce", c1="#9affc0", c2="#3fbf74"},
	{id="nova",  n="노바",  r=2, role="지원", weapon="nova",   c1="#ff9a9a", c2="#d24f4f"},
	{id="rico",  n="리코",  r=2, role="공격", weapon="bolt",   c1="#c9a8ff", c2="#9a4fd1"},
	{id="yuna",  n="유나",  r=1, role="방어", weapon="melee",  c1="#a8d8ff", c2="#4f8fd1"},
	{id="pen",   n="펜",    r=1, role="공격", weapon="rapid",  c1="#ffd89a", c2="#d1a04f"},
	{id="del",   n="델",    r=1, role="지원", weapon="spread", c1="#d8ff9a", c2="#9ad14f"},
	{id="homu",  n="호무",  r=1, role="방어", weapon="melee",  c1="#ffb0c8", c2="#d14f7a"},
	{id="kira",  n="키라",  r=1, role="공격", weapon="pierce", c1="#b0ffe8", c2="#4fd1b0"},
	{id="lumen", n="루멘",  r=3, role="공격", weapon="pierce", c1="#fff3b0", c2="#e8a52e"},
	{id="eve",   n="이브",  r=3, role="지원", weapon="spread", c1="#c9f7ff", c2="#41a0e6"},
	{id="theo",  n="테오",  r=3, role="방어", weapon="melee",  c1="#ffd0a8", c2="#d1764f"},
	{id="lala",  n="라라",  r=2, role="공격", weapon="rapid",  c1="#ffc4e8", c2="#d14fa0"},
	{id="mumu",  n="무무",  r=2, role="지원", weapon="nova",   c1="#c4ffd8", c2="#4fd17a"},
	{id="cyan",  n="시안",  r=2, role="방어", weapon="melee",  c1="#c4e0ff", c2="#4f7ad1"},
	{id="coco",  n="코코",  r=1, role="공격", weapon="bolt",   c1="#ffe0c4", c2="#d1944f"},
	{id="pipi",  n="피피",  r=1, role="지원", weapon="spread", c1="#e0c4ff", c2="#944fd1"},
]

# ── 메일 ──
var mails: Array[Dictionary] = [
	{id="m1", tt="오픈 기념 선물",       from="운영팀", days=13, rw=[{k="gold",  a=1000000}],              claimed=false},
	{id="m2", tt="정기 점검 보상",       from="운영팀", days=6,  rw=[{k="gems",  a=300}],                  claimed=false},
	{id="m3", tt="출석 이벤트 보상",     from="이벤트", days=20, rw=[{k="gems",  a=100}],                  claimed=false},
	{id="m4", tt="신규 픽업 기념 모집권", from="이벤트", days=13, rw=[{k="gems",  a=160}],                  claimed=false},
	{id="m5", tt="버그 수정 보상",       from="운영팀", days=4,  rw=[{k="gems",  a=150}, {k="gold", a=200000}], claimed=false},
	{id="m6", tt="친구 초대 보상",       from="이벤트", days=27, rw=[{k="gems",  a=50}],                   claimed=false},
	{id="m7", tt="기력 응원 선물",       from="운영팀", days=2,  rw=[{k="stamina", a=60}],                 claimed=false},
]

# ── 타이틀 목록 ──
const TITLES = [
	{id="t1", nm="별빛 수호자"},
	{id="t2", nm="마정석 수집가"},
	{id="t3", nm="폭풍의 심장"},
	{id="t4", nm="고요한 관측자"},
	{id="t5", nm="수집가"},
]


func spend_stamina(amount: int) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	stamina_changed.emit(stamina, stamina_max)
	return true


func add_currency(kind: String, amount: int) -> void:
	match kind:
		"gold":     gold += amount
		"gems":     gems += amount
		"faction_token": faction_token += amount
		"sweep_tickets": sweep_tickets += amount
		"stamina":  stamina = mini(stamina + amount, stamina_max); stamina_changed.emit(stamina, stamina_max)
		"event_coin": event_coin += amount
		_:
			push_warning("unknown currency: %s" % kind)
			return
	if kind != "stamina":
		currency_changed.emit(kind, amount)


func stamina_text() -> String:
	return "%d / %d" % [stamina, stamina_max]


func total_power() -> int:
	var s := 0
	for c in roster:
		s += int(c.get("pw", 0))
	return s


func get_char(char_id: String) -> Dictionary:
	for c in roster:
		if c.get("id", "") == char_id:
			return c
	return {}


func owns_char(char_id: String) -> bool:
	for c in roster:
		if c.get("id", "") == char_id:
			return true
	return false


func star_label(r: int) -> String:
	return "★".repeat(r) + "☆".repeat(maxi(0, 3 - r))


func role_icon(role: String) -> String:
	match role:
		"공격": return "⚔"
		"방어": return "🛡"
		"지원": return "💫"
	return "?"

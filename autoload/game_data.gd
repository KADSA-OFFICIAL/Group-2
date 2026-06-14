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
var combat_power: int:
	get: return total_power()

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

# ── 리셋 추적 (에폭 기준 일/주 번호) ──
var last_reset_day: int = -1
var last_reset_week: int = -1

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

# ── 아바타 목록 ──
const AVATARS := ["🦊", "🐱", "🐰", "🐺", "🦉", "🐯", "🐧", "🦄"]

# ── 타이틀 목록 (HTML TITLES 그대로) ──
const TITLES = [
	{id="t1",  ic="🌱", nm="새내기 사냥꾼",   cond="기본 제공"},
	{id="t2",  ic="🗡️", nm="첫 사냥의 추억",  cond="전투 1회 승리"},
	{id="t3",  ic="🌒", nm="균열을 걷는 자",  cond="33-9 클리어"},
	{id="t4",  ic="👑", nm="새벽의 정복자",   cond="챕터 보스 33-10 격파"},
	{id="t5",  ic="📚", nm="수집가",         cond="캐릭터 15명 보유"},
	{id="t6",  ic="✨", nm="운명의 큰손",     cond="모집 10회"},
	{id="t7",  ic="🔥", nm="단련의 달인",     cond="레벨업 20회"},
	{id="t8",  ic="🌟", nm="별의 인도자",     cond="승급 1회"},
	{id="t9",  ic="🛡️", nm="교단의 기둥",    cond="교단 출석 1회"},
	{id="t10", ic="📅", nm="성실의 표본",     cond="출석 7일 달성"},
	{id="t11", ic="🧭", nm="길라잡이 졸업생", cond="길라잡이 임무 10개 완료"},
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


func is_title_unlocked(tid: String) -> bool:
	match tid:
		"t1":  return true
		"t2":  return stats.get("clears", 0) >= 1
		"t3":  return cleared >= 9
		"t4":  return cleared >= 10
		"t5":  return roster.size() >= 15
		"t6":  return stats.get("pulls", 0) >= 10
		"t7":  return stats.get("levelups", 0) >= 20
		"t8":  return stats.get("promos", 0) >= 1
		"t9":  return guild_checked
		"t10": return attend.get("day", 0) >= 7
		"t11": return quest_claims.size() >= 10
	return false


func title_label() -> String:
	for t in TITLES:
		if t.id == title:
			return t.nm
	return "—"


func guide_current() -> String:
	# Returns the name of the first unclaimed quest step, or "" if all done.
	const QUEST_IDS := ["q1", "q2", "q3", "q4", "q5", "q6", "q7", "q8", "q9", "q10"]
	const QUEST_NMS := ["첫 출석", "우편 정리", "첫 모집", "단련 시작", "첫 사냥",
		"공방 가동", "교단 인사", "균열 돌파", "첫 승급", "새벽의 군주 토벌"]
	for i in QUEST_IDS.size():
		if not quest_claims.has(QUEST_IDS[i]):
			return QUEST_NMS[i]
	return ""


# ════════════════════════════════════════════════════════
#  저장 / 불러오기 (진행 영속화)
# ════════════════════════════════════════════════════════
const SAVE_PATH := "user://prototype_save.json"
var _loaded := false


func _ready() -> void:
	load_state()
	_apply_resets()
	# 변경 시 자동 저장
	currency_changed.connect(func(_k, _a): save_state())
	roster_changed.connect(func(): save_state())
	# 주기적 자동 저장 (시그널 없이 dict 만 바뀌는 경우 대비)
	var t := Timer.new()
	t.wait_time = 20.0
	t.autostart = true
	t.timeout.connect(save_state)
	add_child(t)


func _notification(what: int) -> void:
	# 창 닫기·앱 일시정지·종료 시 저장
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_EXIT_TREE:
		save_state()


func save_state() -> void:
	if not _loaded:
		# 아직 불러오기 전이면 저장 안 함 (기본값으로 덮어쓰기 방지)
		return
	var d := {
		"player_name": player_name, "level": level, "is_max_level": is_max_level,
		"exp_current": exp_current, "exp_to_next": exp_to_next,
		"title": title, "avatar": avatar, "cleared": cleared,
		"stamina": stamina, "stamina_max": stamina_max,
		"gold": gold, "gems": gems, "faction_token": faction_token, "sweep_tickets": sweep_tickets,
		"stats": stats, "mats": mats,
		"mission_claims": mission_claims, "shop_buys": shop_buys, "guild_buys": guild_buys,
		"guild_checked": guild_checked, "event_coin": event_coin,
		"event_claims": event_claims, "event_buys": event_buys,
		"pass_claims": pass_claims, "pass_premium": pass_premium, "quest_claims": quest_claims,
		"attend": attend, "settings": settings,
		"roster": roster, "mails": mails,
		"last_reset_day": last_reset_day, "last_reset_week": last_reset_week,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("save_state: 파일 열기 실패 — %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(d))
	f.close()


func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_loaded = true
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		_loaded = true
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_loaded = true
		return
	var d: Dictionary = parsed

	player_name = str(d.get("player_name", player_name))
	level = int(d.get("level", level))
	is_max_level = bool(d.get("is_max_level", is_max_level))
	exp_current = int(d.get("exp_current", exp_current))
	exp_to_next = int(d.get("exp_to_next", exp_to_next))
	title = str(d.get("title", title))
	avatar = str(d.get("avatar", avatar))
	cleared = int(d.get("cleared", cleared))
	stamina = int(d.get("stamina", stamina))
	stamina_max = int(d.get("stamina_max", stamina_max))
	gold = int(d.get("gold", gold))
	gems = int(d.get("gems", gems))
	faction_token = int(d.get("faction_token", faction_token))
	sweep_tickets = int(d.get("sweep_tickets", sweep_tickets))
	guild_checked = bool(d.get("guild_checked", guild_checked))
	event_coin = int(d.get("event_coin", event_coin))
	pass_premium = bool(d.get("pass_premium", pass_premium))
	last_reset_day = int(d.get("last_reset_day", last_reset_day))
	last_reset_week = int(d.get("last_reset_week", last_reset_week))

	stats = _int_dict(d.get("stats", stats), stats)
	mats = _int_dict(d.get("mats", mats), mats)
	if d.has("mission_claims"): mission_claims = _to_dict(d["mission_claims"])
	if d.has("shop_buys"): shop_buys = _int_dict(d["shop_buys"], {})
	if d.has("guild_buys"): guild_buys = _int_dict(d["guild_buys"], {})
	if d.has("event_claims"): event_claims = _to_dict(d["event_claims"])
	if d.has("event_buys"): event_buys = _int_dict(d["event_buys"], {})
	if d.has("pass_claims"): pass_claims = _to_dict(d["pass_claims"])
	if d.has("quest_claims"): quest_claims = _to_dict(d["quest_claims"])
	if d.has("attend"): attend = _to_dict(d["attend"])
	if d.has("settings"): settings = _to_dict(d["settings"])
	if d.has("roster"): roster = _load_roster(d["roster"])
	if d.has("mails"): mails = _load_mails(d["mails"])

	_loaded = true


func reset_save() -> void:
	# 설정 화면의 데이터 초기화용
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ── 일일/주간 리셋 ──────────────────────────────────────
func _apply_resets() -> void:
	var unix: int = int(Time.get_unix_time_from_system())
	var day_num: int = unix / 86400          # 에폭 이후 일 수
	var week_num: int = day_num / 7
	var changed := false

	if last_reset_day != day_num:
		# 일일 미션·상점/이벤트 구매 제한·오늘 출석 초기화
		for k in ["d1", "d2", "d3", "d4", "d5"]:
			mission_claims.erase(k)
		shop_buys.clear()
		event_buys.clear()
		attend["done_today"] = false
		last_reset_day = day_num
		changed = true

	if last_reset_week != week_num:
		# 주간 미션·교단 상점 구매 제한 초기화
		for k in ["w1", "w2", "w3"]:
			mission_claims.erase(k)
		guild_buys.clear()
		last_reset_week = week_num
		changed = true

	if changed and _loaded:
		save_state()


# ── 직렬화 헬퍼 ─────────────────────────────────────────
func _to_dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _int_dict(v: Variant, fallback: Dictionary) -> Dictionary:
	# 숫자 값을 int 로 정규화 (JSON 은 float 로 파싱될 수 있음)
	if typeof(v) != TYPE_DICTIONARY:
		return fallback.duplicate()
	var out := {}
	for k in v:
		var val: Variant = v[k]
		if typeof(val) == TYPE_FLOAT:
			out[k] = int(val)
		else:
			out[k] = val
	return out


func _load_roster(arr: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(arr) != TYPE_ARRAY:
		return roster
	for e in arr:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var c: Dictionary = {}
		for k in e:
			c[k] = e[k]
		for nk in ["r", "lv", "pw", "shards"]:
			if c.has(nk):
				c[nk] = int(c[nk])
		out.append(c)
	return out if not out.is_empty() else roster


func _load_mails(arr: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(arr) != TYPE_ARRAY:
		return mails
	for e in arr:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = {}
		for k in e:
			m[k] = e[k]
		if m.has("days"):
			m["days"] = int(m["days"])
		if m.has("claimed"):
			m["claimed"] = bool(m["claimed"])
		# 보상 배열 내 수치 int 정규화
		if m.has("rw") and typeof(m["rw"]) == TYPE_ARRAY:
			var rws: Array = []
			for rw in m["rw"]:
				if typeof(rw) == TYPE_DICTIONARY:
					var r: Dictionary = {}
					for k in rw:
						r[k] = rw[k]
					if r.has("a"):
						r["a"] = int(r["a"])
					rws.append(r)
			m["rw"] = rws
		out.append(m)
	return out if not out.is_empty() else mails

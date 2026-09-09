extends RefCounted
class_name PresentationQueue

# 연출 큐 — **로직과 연출의 완전 분리** (#450).
#
# 로직은 즉시 계산을 끝내고, 연출은 이 큐에 쌓아 순차 재생한다.
#
#   [히트스톱 4f] [흔들림 5px 0.15s] [데미지숫자 1240 crit] [SFX slash_ice]
#
# **왜 이렇게 하는가**: 배속 기능이 공짜로 구현된다. 재생 속도만 나누면 2배속·3배속이
# 되고, 0으로 두면 연출이 사라져 헤드리스 테스트와 "연출 감소 모드"가 같은 경로를 쓴다.
# 로직 안에 `await`가 섞여 있으면 배속을 넣을 때 전투 코드를 전부 고쳐야 한다.
#
# 이 클래스는 **큐만 관리한다.** 실제 재생은 `ui/turn/TurnBattleHUD`와 전투 화면이
# 이벤트를 받아 한다 — 큐가 노드를 알면 헤드리스에서 쓸 수 없다.
#
# 참고: docs/turn-combat-design.md §연출

# ===== 이벤트 종류 (Event) =====
enum Event {
	SKILL_CAST,      # 스킬 시전 (시전자 · 스킬)
	HIT,             # 타격 (DamageContext)
	HEAL,            # 회복
	LOCK_CLEARED,    # 자물쇠 해제 (상승 음계용 인덱스 포함)
	NULLIFIED,       # 적 행동 무산
	BREAK,           # 약점 격파 — 9단계 연출
	OVERBREAK,       # 초격파
	STATUS_APPLIED,  # 상태이상 부착
	STATUS_EXPIRED,
	MOVED,           # 랭크 이동 (밀치기 · 끌기 · 자리바꿈)
	TIMELINE_SHIFT,  # 타임라인 칩 이동 (앞당김 · 지연)
	ULTIMATE_CUTIN,  # 오의 컷인
	RESOURCE_CHANGED,# 공명 · 오의 게이지 · 열기
	TURN_START,
	TURN_END,
	CYCLE_START,
	DEATH,
	BATTLE_END,
	LOG,             # 전투 로그 한 줄
}

# ===== 타격 피드백 규격표 (설계서 §4.10.5) =====
#
# 히트스톱 프레임 · 흔들림 진폭(px) · 흔들림 지속(초) · 슬로모션(초, 배속) ·
# 플래시 강도 · 색수차 · 넉백(px) · 파티클 수.
#
# **이 표를 코드에 두는 이유**: 연출의 "느낌"은 수치의 조합이고, 조합이 흩어지면
# 일반공격이 오의보다 무거워지는 사고가 난다. 한 표에서만 읽는다.
const FEEDBACK := {
	"basic": {
		"hitstop_frames": 2, "shake_px": 2.0, "shake_time": 0.08,
		"slowmo_time": 0.0, "slowmo_scale": 1.0, "flash": 0.0,
		"chromatic": 0.0, "knockback_px": 4.0, "particles": 8,
	},
	"skill": {
		"hitstop_frames": 4, "shake_px": 5.0, "shake_time": 0.15,
		"slowmo_time": 0.0, "slowmo_scale": 1.0, "flash": 0.10,
		"chromatic": 0.3, "knockback_px": 10.0, "particles": 25,
	},
	"ultimate": {
		"hitstop_frames": 8, "shake_px": 12.0, "shake_time": 0.30,
		"slowmo_time": 0.10, "slowmo_scale": 0.3, "flash": 0.30,
		"chromatic": 0.6, "knockback_px": 24.0, "particles": 80,
	},
	"lock": {
		"hitstop_frames": 3, "shake_px": 3.0, "shake_time": 0.10,
		"slowmo_time": 0.0, "slowmo_scale": 1.0, "flash": 0.15,
		"chromatic": 0.0, "knockback_px": 0.0, "particles": 15,
	},
	"break": {
		"hitstop_frames": 12, "shake_px": 20.0, "shake_time": 0.45,
		"slowmo_time": 0.25, "slowmo_scale": 0.15, "flash": 0.70,
		"chromatic": 1.0, "knockback_px": 32.0, "particles": 150,
	},
}

# ===== 데미지 숫자 규격표 (설계서 §4.10.6) =====
const NUMBER_STYLE := {
	"normal": {"color": Color("FFFFFF"), "scale": 1.0, "label": ""},
	"crit": {"color": Color("FFD54F"), "scale": 1.6, "label": "CRITICAL"},
	"weakness": {"color": Color("FFFFFF"), "scale": 1.2, "label": ""},   # 색은 원소색으로 덮는다
	"break": {"color": Color("FF4757"), "scale": 2.0, "label": "BREAK"},
	"dot": {"color": Color("FFFFFF"), "scale": 0.8, "label": ""},        # 색은 상태이상색
	"heal": {"color": Color("66D9A6"), "scale": 1.0, "label": ""},
}

## 쌓인 이벤트. `[{"event": Event, "data": Dictionary}, ...]`
var events: Array[Dictionary] = []

## 연출을 켤 것인가. 헤드리스 테스트와 연출 감소 모드에서 끈다.
var enabled: bool = true

## 배속. 재생 시간을 이 값으로 나눈다. 1.0 / 2.0 / 3.0.
var speed: float = 1.0


func _init(presentation_enabled: bool = true, presentation_speed: float = 1.0) -> void:
	enabled = presentation_enabled
	speed = maxf(presentation_speed, 0.01)


# ===== 쌓기 (Push) =====

func push(event: Event, data: Dictionary = {}) -> void:
	if not enabled:
		return
	events.append({"event": event, "data": data})


func push_log(line: String) -> void:
	push(Event.LOG, {"line": line})


func push_hit(ctx: DamageContext, feedback_key: String = "skill") -> void:
	push(Event.HIT, {
		"context": ctx,
		"feedback": feedback_for(feedback_key),
		"number": number_style_for(ctx),
		"text": str(ctx.final_damage()),
	})


func push_break(unit: TurnUnit, element: int, ctx: DamageContext) -> void:
	push(Event.BREAK, {
		"unit": unit,
		"element": element,
		"color": TurnCombat.element_color(element),
		"glyph": TurnCombat.element_glyph(element),
		"status": TurnCombat.element_break_status(element),
		"context": ctx,
		"feedback": feedback_for("break"),
		"steps": break_steps(element),
	})


func push_lock_cleared(unit: TurnUnit, lock: TurnLock, index: int, total: int) -> void:
	push(Event.LOCK_CLEARED, {
		"unit": unit,
		"lock": lock,
		"index": index,
		"total": total,
		"feedback": feedback_for("lock"),
		# 해제음을 **상승 음계**로 설계한다: 1개 = 도, 2개 = 미, 3개 = 솔, 전부 = 화음 폭발.
		# 연속 해제가 음악이 되게 하려는 것이다(설계서 §4.10.9).
		"pitch": lock_pitch(index, total),
	})


# 자물쇠 해제음의 음정 배율. 장3화음(도-미-솔)을 따라 올라가고, 전부 열면 한 옥타브 위.
static func lock_pitch(index: int, total: int) -> float:
	if index >= total:
		return 2.0
	const CHORD := [1.0, 1.26, 1.5, 1.68]  # 도 · 미 · 솔 · 시b
	return CHORD[mini(maxi(index - 1, 0), CHORD.size() - 1)]


func push_timeline_shift(unit: TurnUnit, delta_av: float) -> void:
	push(Event.TIMELINE_SHIFT, {
		"unit": unit,
		"delta_av": delta_av,
		# 앞당김/지연 시 칩이 물리적으로 슬라이드 이동한다. 이 애니메이션이 없으면
		# 플레이어는 자기 행동의 결과를 체감하지 못한다(설계서 §11.2 (A)).
		"duration": 0.35,
	})


# ===== 조회 (Lookups) =====

func feedback_for(key: String) -> Dictionary:
	return FEEDBACK.get(key, FEEDBACK["skill"])


# 행동 종류에 맞는 피드백 키.
static func feedback_key_for_action(kind: int) -> String:
	match kind:
		TurnCombat.ActionKind.BASIC:
			return "basic"
		TurnCombat.ActionKind.ULTIMATE:
			return "ultimate"
		_:
			return "skill"


# 이 타격의 데미지 숫자 스타일.
#
# 우선순위: 격파 > 치명타 > 약점 > 지속 > 일반. 격파 숫자가 치명타 스타일에 묻히면
# 격파의 존재감이 사라진다.
func number_style_for(ctx: DamageContext) -> Dictionary:
	var style: Dictionary = {}

	if ctx.is_break_damage or ctx.is_overbreak:
		style = NUMBER_STYLE["break"].duplicate()
		style["color"] = TurnCombat.element_color(ctx.element)
		style["outline"] = Color.WHITE
		return style

	if ctx.is_crit:
		style = NUMBER_STYLE["crit"].duplicate()
		return style

	if ctx.is_dot:
		style = NUMBER_STYLE["dot"].duplicate()
		style["color"] = TurnCombat.element_color(ctx.element)
		return style

	if ctx.hits_weakness:
		style = NUMBER_STYLE["weakness"].duplicate()
		style["color"] = TurnCombat.element_color(ctx.element)
		return style

	return NUMBER_STYLE["normal"].duplicate()


# ===== 약점 격파 9단계 (설계서 §4.10.7) =====
#
# **이 9단계가 게임의 첫인상을 결정한다.** 프로토타입 단계에서 다른 무엇보다 먼저
# 이것을 완성하고 감각을 검증하라고 설계서가 못 박은 부분이다.
#
# 각 단계를 데이터로 돌려주는 이유: 재생기(UI)가 순서를 자기 코드에 박으면 단계를
# 하나 늘릴 때 재생기를 고쳐야 하고, 헤드리스에서 "9단계가 다 있는가"를 검사할 수 없다.
static func break_steps(element: int) -> Array[Dictionary]:
	var color := TurnCombat.element_color(element)
	return [
		{"step": 1, "name": "감지", "duration": 0.0,
			"note": "인성치 0 도달"},
		{"step": 2, "name": "히트스톱", "duration": 12.0 / 60.0,
			"note": "전 게임 정지 12프레임"},
		{"step": 3, "name": "인성치 파열", "duration": 0.20,
			"note": "바가 방사형으로 파열, 유리 파편 스프라이트 폭발"},
		{"step": 4, "name": "슬로모션", "duration": 0.25, "time_scale": 0.15,
			"note": "0.25초 동안 0.15배속"},
		{"step": 5, "name": "화면 플래시", "duration": 0.30, "color": color,
			"note": "원소 색 70% → 0%"},
		{"step": 6, "name": "원소 이펙트", "duration": 0.45, "color": color,
			"note": element_break_effect(element)},
		{"step": 7, "name": "BREAK 타이포", "duration": 0.40, "color": color,
			"note": "화면을 가로지르는 타이포그래피"},
		{"step": 8, "name": "비틀거림", "duration": 0.35,
			"note": "적 스프라이트 비틀거림 + 붉은 실루엣 명멸"},
		{"step": 9, "name": "격파 데미지", "duration": 0.50, "color": color,
			"note": "대형 숫자 + 상태이상 아이콘 부착 + 전용 SFX"},
	]


# 원소별 전용 대형 이펙트 (설계서 §4.10.7 6단계).
static func element_break_effect(element: int) -> String:
	match element:
		TurnCombat.Element.CRYO:
			return "적을 감싸는 결정 성장 → 균열 → 파쇄"
		TurnCombat.Element.PYRO:
			return "내부에서 터져나오는 폭염 + 잔불 파티클"
		TurnCombat.Element.CORROSION:
			return "중력 왜곡 셰이더 + 보라 안개 수축"
		TurnCombat.Element.VOLT:
			return "화면 전체 번개 분기 + 잔상 스트로브"
		TurnCombat.Element.LUMEN:
			return "방사형 광선 + 렌즈 플레어"
		TurnCombat.Element.GALE:
			return "진공 균열선 + 다중 참격 궤적"
		_:  # IMPACT
			return "방사형 충격파 링 + 지면 균열"


# ===== 오의 컷인 8단계 (설계서 §4.10.4) =====
#
# 3D 카메라 컷씬의 2D 대체안이다. **타이포그래피가 핵심이다** — 글자 자체가 연출이 되면
# 3D 카메라가 없어도 충분히 강렬하다(페르소나 5 · 리버스: 1999가 증명).
static func ultimate_cutin_steps(unit: TurnUnit, skill: SkillData) -> Array[Dictionary]:
	var color := TurnCombat.element_color(unit.element)
	return [
		{"at": 0.00, "name": "암전", "duration": 0.08,
			"note": "화면 전체 순간 암전 + 저음 임팩트 SFX"},
		{"at": 0.08, "name": "스피드라인", "duration": 0.12, "color": color,
			"note": "대각선 스피드라인이 화면을 쓸고 지나감"},
		{"at": 0.20, "name": "일러스트 인", "duration": 0.25,
			"note": "캐릭터 전신이 우측에서 슬라이드 인 (실루엣 → 컬러)"},
		{"at": 0.45, "name": "타이포그래피", "duration": 0.25, "color": color,
			"text": "%s / %s" % [unit.display_name, skill.display_name],
			"note": "한 글자씩 0.02초 간격, 살짝 회전 (kinetic typography)"},
		{"at": 0.70, "name": "보이스", "duration": 0.30,
			"note": "캐릭터 보이스 재생"},
		{"at": 1.00, "name": "복귀", "duration": 0.10,
			"note": "일러스트 이탈 + 전투 화면 복귀, 카메라 줌인"},
		{"at": 1.10, "name": "오의 모션", "duration": 1.50,
			"note": "스켈레탈 애니메이션 + 대형 이펙트"},
		{"at": 2.60, "name": "마무리", "duration": 0.40,
			"note": "히트스톱 8프레임 → 화면 흔들림 → 데미지 표시"},
	]


# ===== 카메라 프로파일 (설계서 §4.10.8) =====
const CAMERA := {
	"idle": {"zoom": 1.0, "dutch": 0.0, "pan": 0.0},
	"ally_skill": {"zoom": 1.15, "dutch": 0.0, "pan": 0.3},
	"single": {"zoom": 1.4, "dutch": 0.0, "pan": 0.2},
	"aoe": {"zoom": 0.85, "dutch": 0.0, "pan": 0.0},
	"ultimate": {"zoom": 1.6, "dutch": -5.0, "pan": 0.2},
	"break": {"zoom": 1.8, "dutch": 0.0, "pan": 0.0},
	"ally_death": {"zoom": 0.9, "dutch": 0.0, "pan": 0.0, "saturation": 0.5},
}

static func camera_for(key: String) -> Dictionary:
	return CAMERA.get(key, CAMERA["idle"])


# ===== 재생 (Playback) =====

# 다음 이벤트를 꺼낸다. 없으면 빈 딕셔너리.
func pop() -> Dictionary:
	if events.is_empty():
		return {}
	return events.pop_front()


func is_empty() -> bool:
	return events.is_empty()


func clear() -> void:
	events.clear()


# 배속이 적용된 지속시간. 재생기가 `await` 시간을 정할 때 쓴다.
func scaled(duration: float) -> float:
	return duration / speed


# 이 큐가 담고 있는 연출의 총 재생 시간(배속 적용). 진행 바 표시에 쓴다.
func total_duration() -> float:
	var total := 0.0
	for entry in events:
		var data: Dictionary = entry["data"]
		if data.has("duration"):
			total += float(data["duration"])
		elif data.has("feedback"):
			var feedback: Dictionary = data["feedback"]
			total += float(feedback.get("shake_time", 0.0)) \
				+ float(feedback.get("slowmo_time", 0.0)) \
				+ float(feedback.get("hitstop_frames", 0)) / 60.0
	return scaled(total)

extends Node

# 전투 튜닝 상수의 단일 출처(single source of truth).
# 재화의 CurrencySystem.DEFAULT_CURRENCIES와 같은 역할로, 전투 수치를 한 곳에 모은다.
# 다른 전투 로직(패링/표식/스택/점령 등)은 이 상수를 참조하며, 값을 복제하지 않는다.
#
# 상태 표기:
#   [확정] docs/combat-screen-design.md 에서 합의된 값. 임의로 바꾸지 말 것.
#   [임시값] 아직 확정되지 않은 플레이스홀더. 밸런싱 시 조정 대상.
#
# 주의(단일 출처): 캐릭터별 스텟(공격력/방어력/HP 등)은 PlayerStats가 소유한다.
#   여기에는 그 값을 복제하지 않고, "전투 메커니즘 공통 규칙" 수치만 둔다.
#
# 참고: docs/combat-screen-design.md, SYSTEM_CONVENTIONS.md

# ===== 브루저 · 패링 (Parry) =====
# 적 공격을 막고 반격하는 타이밍 창.
const PARRY_WINDOW: float = 0.45              # [확정] 패링 판정 시간(초)
const PARRY_INVULN_DURATION: float = 0.30     # [임시값] 패링 성공 시 무적 지속(초)
const PARRY_COUNTER_MULTIPLIER: float = 1.5   # [임시값] 반격 피해 배수(평타 대비)

# ===== 원딜 · 스택 (Ranged Stack) =====
# 평타를 칠수록 쌓여 공속·이속을 올리고, 놓으면 "서서히 감소"한다.
const STACK_MAX: int = 10                              # [임시값] 최대 스택 수
const STACK_GAIN_PER_HIT: int = 1                      # [임시값] 평타 1회당 스택 증가
const STACK_ATTACK_SPEED_PER_STACK: float = 0.05      # [임시값] 스택 1당 공속 +5%
const STACK_MOVE_SPEED_PER_STACK: float = 0.02        # [임시값] 스택 1당 이속 +2%
# 감소 규칙: 조종 중엔 느리게, 미조종(AI) 중엔 더 빠르게. (docs §4.1 확정 방향)
const STACK_DECAY_PER_SEC_CONTROLLED: float = 1.0     # [임시값] 조종 중 초당 감소
const STACK_DECAY_PER_SEC_UNCONTROLLED: float = 2.5   # [임시값] 미조종 중 초당 감소

# ===== 버퍼 · 표식 (Mark) =====
# 스킬로 표식 세팅 → 파티 누구든 평타로 채움 → 임계치 도달 시 기절(CC).
const MARK_THRESHOLD: int = 5                 # [확정] 표식이 터지는 임계치
const MARK_GAIN_PER_HIT: int = 1              # [임시값] 평타 1회당 표식 충전
const MARK_STUN_DURATION: float = 2.0         # [임시값] 표식 폭발 시 기절 지속(초)

# ===== 승리 조건 · 점령 (Capture) =====
# 스테이지 타입(전투/점령/점령+전투)에서 "점령" 프리미티브가 쓰는 값.
const CAPTURE_HOLD_SECONDS: float = 10.0      # [임시값] 거점 존 확보에 필요한 시간(초)

# ===== 공통 전투 기본값 (Global Combat Defaults) =====
# 캐릭터별 값이 아니라 전투 공통 기본치. 개별 스텟은 PlayerStats가 소유한다.
const BASE_ATTACK_COOLDOWN: float = 0.5       # [임시값] 평타 기본 쿨다운(초, 스택 공속 적용 전)
const BASE_MOVE_SPEED: float = 200.0          # [임시값] 이동 기본 속도(px/s, 스택 이속 적용 전)


# 디버그/검증용: 모든 상수를 Dictionary로 반환한다.
func get_summary() -> Dictionary:
	return {
		"PARRY_WINDOW": PARRY_WINDOW,
		"PARRY_INVULN_DURATION": PARRY_INVULN_DURATION,
		"PARRY_COUNTER_MULTIPLIER": PARRY_COUNTER_MULTIPLIER,
		"STACK_MAX": STACK_MAX,
		"STACK_GAIN_PER_HIT": STACK_GAIN_PER_HIT,
		"STACK_ATTACK_SPEED_PER_STACK": STACK_ATTACK_SPEED_PER_STACK,
		"STACK_MOVE_SPEED_PER_STACK": STACK_MOVE_SPEED_PER_STACK,
		"STACK_DECAY_PER_SEC_CONTROLLED": STACK_DECAY_PER_SEC_CONTROLLED,
		"STACK_DECAY_PER_SEC_UNCONTROLLED": STACK_DECAY_PER_SEC_UNCONTROLLED,
		"MARK_THRESHOLD": MARK_THRESHOLD,
		"MARK_GAIN_PER_HIT": MARK_GAIN_PER_HIT,
		"MARK_STUN_DURATION": MARK_STUN_DURATION,
		"CAPTURE_HOLD_SECONDS": CAPTURE_HOLD_SECONDS,
		"BASE_ATTACK_COOLDOWN": BASE_ATTACK_COOLDOWN,
		"BASE_MOVE_SPEED": BASE_MOVE_SPEED,
	}


func _ready() -> void:
	name = "CombatConfig"

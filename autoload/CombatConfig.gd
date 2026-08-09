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

# [폐기] 브루저 · 패링(PARRY_*) 상수는 제거되었다.
# 역할이 브루저 -> 탱커로 바뀌며 패링 기본기 자체가 폐기되었고, 표식이 버퍼에서 탱커로 이동했다.
# 폐기된 메커니즘의 수치를 남겨두면 그것을 보고 구현할 위험이 있어 삭제한다.
# (docs/combat-screen-design.md §2 참조)

# ===== 원거리딜러 · 스택 (Ranged Stack) =====
# 평타를 칠수록 쌓여 공속·이속을 올리고, 놓으면 "서서히 감소"한다.
const STACK_MAX: int = 10                              # [임시값] 최대 스택 수
const STACK_GAIN_PER_HIT: int = 1                      # [임시값] 평타 1회당 스택 증가
const STACK_ATTACK_SPEED_PER_STACK: float = 0.05      # [임시값] 스택 1당 공속 +5%
const STACK_MOVE_SPEED_PER_STACK: float = 0.02        # [임시값] 스택 1당 이속 +2%
# 감소 규칙: 조종 중엔 느리게, 미조종(AI) 중엔 더 빠르게. (docs §4.1 확정 방향)
const STACK_DECAY_PER_SEC_CONTROLLED: float = 1.0     # [임시값] 조종 중 초당 감소
const STACK_DECAY_PER_SEC_UNCONTROLLED: float = 2.5   # [임시값] 미조종 중 초당 감소

# ===== 탱커 · 표식 (Mark) =====
# 탱커의 스킬과 평타가 표식을 생성 → **파티 전체**의 평타가 채움 → 임계치 도달 시 기절(CC).
# (표식은 버퍼에서 탱커로 이동했고, 스킬뿐 아니라 평타로도 생성된다.)
const MARK_THRESHOLD: int = 5                 # [확정] 표식이 터지는 임계치
const MARK_GAIN_PER_HIT: int = 1              # [임시값] 평타 1회당 표식 충전
const MARK_STUN_DURATION: float = 2.0         # [임시값] 표식 폭발 시 기절 지속(초)

# ===== 버퍼 · 처형 (Execute) =====
# 디버프가 걸린 적을 **버퍼가 직접** 공격할 때, 적 체력이 임계치 이하면 처형한다.
# 디버프 판정의 출처는 StatusEffectData.is_debuff이며 여기서 디버프를 재정의하지 않는다.
const EXECUTE_HP_PERCENT: float = 0.2         # [임시값] 처형 가능한 체력 비율(최대 체력 대비)

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
		"STACK_MAX": STACK_MAX,
		"STACK_GAIN_PER_HIT": STACK_GAIN_PER_HIT,
		"STACK_ATTACK_SPEED_PER_STACK": STACK_ATTACK_SPEED_PER_STACK,
		"STACK_MOVE_SPEED_PER_STACK": STACK_MOVE_SPEED_PER_STACK,
		"STACK_DECAY_PER_SEC_CONTROLLED": STACK_DECAY_PER_SEC_CONTROLLED,
		"STACK_DECAY_PER_SEC_UNCONTROLLED": STACK_DECAY_PER_SEC_UNCONTROLLED,
		"MARK_THRESHOLD": MARK_THRESHOLD,
		"MARK_GAIN_PER_HIT": MARK_GAIN_PER_HIT,
		"MARK_STUN_DURATION": MARK_STUN_DURATION,
		"EXECUTE_HP_PERCENT": EXECUTE_HP_PERCENT,
		"CAPTURE_HOLD_SECONDS": CAPTURE_HOLD_SECONDS,
		"BASE_ATTACK_COOLDOWN": BASE_ATTACK_COOLDOWN,
		"BASE_MOVE_SPEED": BASE_MOVE_SPEED,
	}


func _ready() -> void:
	name = "CombatConfig"

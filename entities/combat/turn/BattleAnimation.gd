extends RefCounted
class_name BattleAnimation

# 턴제 전투 프레임 시트의 **규약** (#487).
#
# 애니메이션 이름과 재생 규칙이 여기 한 곳에만 있다. 아군(`CharacterData`)과
# 적(`EnemyData`)이 같은 규약을 쓰고, 전투 화면·조립 도구·검증이 전부 이것을 참조한다.
# `WalkAnimation`(실시간 화면의 4방향 이동)과 같은 자리의 물건이며, **다른 에셋**이다.
#
# ## 왜 4종뿐인가
#
# 재생 경로가 있는 것만 둔다. 전투 화면의 연출 이벤트와 1:1 로 짝지어진다.
#
# | 연출 이벤트 | 애니메이션 | 재생 |
# |---|---|---|
# | (대기) | `idle` | 루프 |
# | `SKILL_CAST` | `attack` | 1회 후 idle |
# | `HIT` | `hit` | 1회 후 idle |
# | `DEATH` | `death` | 1회 후 **마지막 프레임 유지** |
#
# `pixel-art-prompts.md` 가 적어 둔 교훈이다: *"재생 코드가 없는 애니메이션은 요구하지
# 않았다. 프롬프트에 넣으면 창고에 쌓인다."* 승리 포즈·이동·버프 반응은 이 화면에
# 재생 경로가 없으므로 저작하지 않는다.

## 대기. 호흡과 미세한 무게중심 이동. **유일한 루프 애니메이션이다.**
const IDLE: StringName = &"idle"
## 공격. 시전 연출(`SKILL_CAST`)에서 1회 재생한다.
const ATTACK: StringName = &"attack"
## 피격. 맞는 순간(`HIT`) 1회 재생한다.
const HIT: StringName = &"hit"
## 사망. 마지막 프레임에서 멈춘다 — 루프로 두면 시체가 계속 쓰러진다.
const DEATH: StringName = &"death"

const ALL: Array[StringName] = [IDLE, ATTACK, HIT, DEATH]

## `idle` 만 있어도 시트로 인정한다. 나머지는 없으면 그 동작에서 트윈만 남는다.
const REQUIRED: Array[StringName] = [IDLE]

# 동작별 권장 프레임 수. 조립 도구와 검증이 이 값을 쓴다.
#
# 짧게 잡은 이유: 화면 표시 높이가 84px 이라 프레임을 늘려도 차이가 보이지 않고,
# **같은 캐릭터를 여러 컷으로 일관되게 뽑는 것이 이 프로젝트에서 이미 실패한 적이 있다**
# (`pixel-art-prompts.md`). 컷이 적을수록 흔들림이 적다.
const FRAME_COUNT := {
	IDLE: 4,
	ATTACK: 4,
	HIT: 2,
	DEATH: 4,
}

# 동작별 재생 속도(fps). 배속은 전투 화면이 `speed_scale` 로 따로 곱한다.
#
# `hit` 이 빠른 이유: 타격 규격표의 히트스톱이 2~12프레임이라, 피격 모션이 그보다 길면
# 히트스톱이 끝난 뒤에도 움츠린 자세가 남아 다음 타격과 겹친다.
const FPS := {
	IDLE: 6.0,
	ATTACK: 14.0,
	HIT: 16.0,
	DEATH: 8.0,
}

## 시트가 루프해야 하는 동작. 여기 없으면 1회 재생이다.
const LOOPING: Array[StringName] = [IDLE]


# 이 시트의 셀 크기. 첫 프레임의 텍스처 크기를 쓴다.
#
# 전투 화면이 칸(아군 56×84 / 적 62×78)에 맞춰 줄일 때 필요하다. 시트마다 원본 해상도가
# 다를 수 있으므로 하드코딩하지 않는다.
static func cell_size(frames: SpriteFrames) -> Vector2:
	if frames == null:
		return Vector2.ZERO
	for name in ALL:
		if not frames.has_animation(name):
			continue
		if frames.get_frame_count(name) <= 0:
			continue
		var texture := frames.get_frame_texture(name, 0)
		if texture != null:
			return texture.get_size()
	return Vector2.ZERO


# 저작되지 않은 동작 목록. 검증과 도구가 쓴다.
#
# `WalkAnimation.missing_animations()` 와 같은 규약이다 — 시트를 갈아끼워도 스크립트를
# 고칠 필요가 없게 하는 쪽이 이 프로젝트의 방식이다.
static func missing_animations(frames: SpriteFrames) -> Array[String]:
	var missing: Array[String] = []
	if frames == null:
		for name in ALL:
			missing.append(String(name))
		return missing
	for name in ALL:
		if not frames.has_animation(name) or frames.get_frame_count(name) <= 0:
			missing.append(String(name))
	return missing


# 이 시트를 전투 화면이 쓸 수 있는가. `idle` 하나면 충분하다.
static func is_usable(frames: SpriteFrames) -> bool:
	if frames == null:
		return false
	for name in REQUIRED:
		if not frames.has_animation(name) or frames.get_frame_count(name) <= 0:
			return false
	return true

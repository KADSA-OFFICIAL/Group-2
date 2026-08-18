extends RefCounted
class_name WalkAnimation

# 4방향 워크 시트 규약의 단일 출처.
#
# 애니메이션 이름과 "속도 벡터 -> 어떤 방향 애니메이션인가" 판정을 여기 한 곳에 둔다.
# Player와 EnemyBase가 각자 문자열과 판정식을 들고 있으면 한쪽만 바뀔 때
# 런타임 에러 없이 조용히 어긋난다(한쪽은 옆모습, 한쪽은 정면을 재생하는 식).
#
# 시트 저작 규약과 정규화 방법: assets/sprites/enemies/README.md
# 원본 시트를 이 규약에 맞추는 도구: tools/normalize_walk_sheet.gd

# 방향별 애니메이션 이름. 순서는 화면 방향 기준 하/좌/상/우이며,
# Godot의 +y가 아래인 좌표계에 맞춘 것이다.
# 아래 인덱스 상수로 접근한다(순서에 의존하는 코드를 흩뜨리지 않기 위해).
const ANIMATIONS: Array[StringName] = [&"walk_down", &"walk_left", &"walk_up", &"walk_right"]

const DOWN := 0
const LEFT := 1
const UP := 2
const RIGHT := 3

# 이 속도보다 느리면 "멈춤"으로 본다.
# move_and_slide()가 벽에 붙었을 때 아주 작은 잔여 속도를 남기는데,
# 0과 정확히 비교하면 제자리에서 발만 구르게 된다.
const STOP_SPEED := 1.0


# 이동 방향 -> 재생할 애니메이션 이름.
# 4방향 시트이므로 성분이 큰 축을 주 방향으로 삼는다.
# 대각선(|x| == |y|)에서는 좌우를 택한다: 쿼터뷰에서 옆모습이 더 잘 읽히고,
# 경계에서 상하/좌우가 번갈아 튀는 것도 막는다.
static func animation_for(direction: Vector2) -> StringName:
	if absf(direction.x) >= absf(direction.y):
		return ANIMATIONS[RIGHT] if direction.x > 0.0 else ANIMATIONS[LEFT]
	return ANIMATIONS[DOWN] if direction.y > 0.0 else ANIMATIONS[UP]


# 이 속도로 걷고 있다고 볼 수 있는가.
static func is_walking(velocity: Vector2) -> bool:
	return velocity.length() >= STOP_SPEED


# SpriteFrames가 네 방향을 모두 가지고 있는지 점검한다.
# 빠진 이름 목록을 반환한다(모두 있으면 빈 배열).
# CharacterData / EnemyData의 validate()가 이걸 쓴다.
static func missing_animations(frames: SpriteFrames) -> Array[String]:
	var missing: Array[String] = []
	if frames == null:
		return missing
	for anim in ANIMATIONS:
		if not frames.has_animation(anim):
			missing.append(String(anim))
	return missing

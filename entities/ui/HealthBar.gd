extends Node2D
class_name HealthBar

# 캐릭터·적 머리 위에 뜨는 체력 바 (docs §6 [확정] "각자 체력", "보호막 표시").
#
# 값의 소유는 이 노드가 아니다. 부모의 hp / max_hp / get_shield() 를 **읽어서 표시만** 한다
# (§6: "HUD 코드도 값의 소유·계산은 기초 시스템에 두고 그 값을 읽어서 표시만 한다").
# 그래서 어떤 노드든 hp / max_hp 를 가지면 이 바를 붙일 수 있다.
# 보호막은 있으면 그리고, 없으면(적) 없는 대로 그린다 — 있어야만 붙는 것이 아니다.
#
# 씬 파일을 두지 않고 코드로 붙이는 이유: Player 와 EnemyBase 두 곳에서 만들면
# 새 캐릭터·새 적을 추가할 때 씬을 고치지 않아도 자동으로 붙는다.
# (적 씬이 셋이고 앞으로 더 늘어난다.)

## 적의 바인가. 테두리가 빨강이 되고 더 굵어진다 — 난전에서 아군과 즉시 구분되어야 한다.
@export var hostile: bool = false

## 바 크기(px). 스프라이트 위에 얹히므로 작게 둔다.
@export var bar_size: Vector2 = Vector2(44, 6)

## 스프라이트 머리에서 이만큼 더 위에 띄운다.
@export var gap: float = 8.0

# 마지막으로 그린 값. 바뀔 때만 다시 그린다(매 프레임 redraw 를 피한다).
var _hp: int = -1
var _max_hp: int = -1
var _shield: int = 0


func _ready() -> void:
	# 스프라이트보다 위에 그린다. 아니면 캐릭터 몸에 가려진다.
	z_index = 100
	position.y = _resolve_top_y() - gap
	_sync()


# 전투가 도는 틱과 같은 곳에서 읽는다. 피해·회복은 _physics_process 경로에서 일어나므로
# 여기서 읽으면 바가 한 프레임 늦지 않는다.
func _physics_process(_delta: float) -> void:
	_sync()


# 부모의 체력과 보호막을 읽어 온다. 값이 바뀌었을 때만 다시 그린다.
func _sync() -> void:
	var host := get_parent()
	if host == null:
		return

	# get() 으로 읽어 hp / max_hp 가 없는 노드에도 안전하다(없으면 null).
	var raw_hp = host.get("hp")
	var raw_max = host.get("max_hp")
	if raw_hp == null or raw_max == null:
		return

	var new_hp := int(raw_hp)
	var new_max := int(raw_max)
	var new_shield := _read_shield(host)
	if new_hp == _hp and new_max == _max_hp and new_shield == _shield:
		return

	_hp = new_hp
	_max_hp = new_max
	_shield = new_shield
	queue_redraw()


# 부모의 보호막. 값의 소유는 부모다 — 여기서 세지 않는다.
#
# has_method 로 물어보는 이유: 보호막은 Player 만 가진 자원이다. 적(EnemyBase)에는 없고,
# 앞으로도 없을 수 있다. hp 를 get() 으로 읽는 것과 같은 이유로, 없는 노드에서도
# 이 바가 그대로 동작해야 한다(HUD 파티 카드도 같은 방식으로 묻는다).
func _read_shield(host: Node) -> int:
	if not host.has_method("get_shield"):
		return 0
	return maxi(int(host.get_shield()), 0)


# 바를 올릴 높이. **실제로 보이는** 스프라이트의 위쪽 끝을 부모 좌표계로 계산한다.
#
# 캐릭터마다 키가 다르다: 도형 플레이스홀더는 64px x sprite_scale 이고,
# 워크 시트 캐릭터는 셀 448px x 0.25 에 offset 까지 걸려 있다.
# 고정값을 쓰면 한쪽은 얼굴을 가리고 다른 쪽은 허공에 뜬다.
func _resolve_top_y() -> float:
	var host := get_parent()
	if host == null:
		return -60.0

	var anim := host.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim != null and anim.visible and anim.sprite_frames != null:
		var frames := anim.sprite_frames
		var anim_name := anim.animation
		if frames.has_animation(anim_name) and frames.get_frame_count(anim_name) > 0:
			var tex := frames.get_frame_texture(anim_name, 0)
			if tex != null:
				# 프레임은 offset 을 중심으로 그려진다. 위쪽 끝 = 중심 - 높이/2.
				return (anim.offset.y - tex.get_height() * 0.5) * anim.scale.y

	var sprite := host.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and sprite.visible and sprite.texture != null:
		return (sprite.offset.y - sprite.texture.get_height() * 0.5) * sprite.scale.y

	# 보이는 스프라이트를 찾지 못했다. 캡슐(높이 30) 위쪽보다 조금 더 위로 둔다.
	return -60.0


func _draw() -> void:
	if _max_hp <= 0:
		return

	# 원점이 바의 **아래 가운데**다. position.y 가 머리 위를 가리키므로 위로 자란다.
	var rect := Rect2(-bar_size.x * 0.5, -bar_size.y, bar_size.x, bar_size.y)

	draw_rect(rect, UITheme.BG)

	var ratio := clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	if ratio > 0.0:
		draw_rect(Rect2(rect.position, Vector2(bar_size.x * ratio, bar_size.y)), UITheme.POSITIVE)

	_draw_shield(rect)

	# 적은 빨간 테두리 + 더 굵게. 색의 출처는 UITheme 다(여기서 색을 만들지 않는다).
	#
	# 테두리를 바 **바깥쪽**에 그린다. draw_rect 의 선은 경계에 걸쳐 그려지므로 그냥 두면
	# 두께의 절반이 안쪽을 먹는다. 6px 바에 2px 테두리를 그리면 채움이 2px만 남아
	# 적 바가 빨간 덩어리로 읽혔다. grow() 로 밖으로 밀어 채움을 온전히 남긴다.
	var border_width := 2.0 if hostile else 1.0
	draw_rect(rect.grow(border_width * 0.5), get_border_color(), false, border_width)


# 보호막을 체력 **위에 겹쳐** 그린다 (docs §6 [확정] "체력바 위에 겹쳐 표시").
#
# 바 **위쪽 띠**에만 그리는 이유: 전체 높이로 덮으면 보호막이 체력보다 클 때 체력 채움이
# 통째로 가려진다. 체력 300·보호막 900 과 체력 900·보호막 900 이 화면에서 같아지는데,
# 난전에서 죽는 것은 체력이라 그쪽이 가려지면 안 된다. 띠로 나누면 두 자원이 항상 함께 읽힌다.
#
# 오른쪽에 이어 붙이지 않는 이유는 따로 있다: 그러면 바 하나에 서로 다른 자원 둘이 한 줄로
# 이어져 "체력이 늘었다"로 읽힌다. 보호막은 체력이 아니다.
#
# 색은 UITheme.SKY 다. HUD 파티 카드의 "+150" 표시가 쓰는 색과 같아야 같은 자원으로
# 읽힌다(ui/HUD.gd `_make_party_row`). 여기서 색을 새로 만들지 않는다.
func _draw_shield(rect: Rect2) -> void:
	if _shield <= 0:
		return

	# 보호막에는 총량 한도가 없다(#261). 최대 체력보다 클 수 있으므로 바 폭에서 자른다 —
	# 자르지 않으면 바가 스프라이트 밖까지 뻗어 난전에서 화면을 덮는다.
	# 띠가 끝까지 차면 "최대 체력 이상"이라는 뜻이고, 그 위로는 더 드러나지 않는다.
	var ratio := clampf(float(_shield) / float(_max_hp), 0.0, 1.0)
	if ratio <= 0.0:
		return

	# 띠 높이는 바의 절반이되 최소 1px 은 남긴다 — 6px 바에서도 사라지지 않아야 한다.
	var band := maxf(floorf(bar_size.y * 0.5), 1.0)
	draw_rect(Rect2(rect.position, Vector2(bar_size.x * ratio, band)), UITheme.SKY)


# 테두리 색. 검증·디버그에서도 같은 값을 보게 함수로 둔다.
func get_border_color() -> Color:
	return UITheme.HOSTILE if hostile else UITheme.OUTLINE


# 지금 그려진 보호막. 검증·디버그용(테두리 색과 같은 이유로 함수로 둔다).
func get_shield_value() -> int:
	return _shield

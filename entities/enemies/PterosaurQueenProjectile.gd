extends Projectile
class_name PterosaurQueenProjectile

# 여왕 전용 탄은 판정/비행은 Projectile 그대로 쓰고 그림만 교체한다(#384).

const NORMAL_FRAMES := preload("res://assets/sprites/vfx/pterosaur_queen_projectile_frames.tres")
const CHARGED_FRAMES := preload("res://assets/sprites/vfx/pterosaur_queen_projectile_charged_frames.tres")

@onready var visual: AnimatedSprite2D = $AnimatedSprite2D


func setup(direction: Vector2, speed: float, p_damage: int, p_source: Node,
		p_max_distance: float, p_hit_radius: float = 12.0,
		p_effect_id: StringName = &"", p_color: Color = Color.WHITE,
		p_hits_enemies: bool = false, p_aoe_radius: float = 0.0) -> void:
	super(direction, speed, p_damage, p_source, p_max_distance, p_hit_radius,
		p_effect_id, p_color, p_hits_enemies, p_aoe_radius)
	visual.sprite_frames = CHARGED_FRAMES if p_effect_id != &"" else NORMAL_FRAMES
	visual.animation = &"spin"
	visual.rotation = direction.angle()
	visual.play()


# Projectile의 원형 플레이스홀더를 숨긴다. 실제 판정 반경은 부모 클래스에 그대로 남는다.
func _draw() -> void:
	pass

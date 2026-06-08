extends Node
class_name FeedbackSystemBase

func play_damage_feedback(_position: Vector2, _damage: int):
	# Visual feedback like screen shake or particles
	pass

func play_parry_feedback(_position: Vector2):
	# Visual feedback for successful parry
	pass

func play_hit_feedback(_target_position: Vector2):
	# Visual feedback for hit
	pass

func screen_shake(_duration: float = 0.1, _intensity: float = 5.0):
	# Screen shake effect
	pass

func play_sound(_sound_path: String):
	# Play audio feedback
	pass

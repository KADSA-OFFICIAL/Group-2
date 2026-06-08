extends Node

# Combat signals
@warning_ignore("unused_signal")
signal enemy_died(enemy)
@warning_ignore("unused_signal")
signal player_died
@warning_ignore("unused_signal")
signal damage_taken(target, damage, position)
@warning_ignore("unused_signal")
signal healing_applied(target, amount)

# Movement signals
@warning_ignore("unused_signal")
signal dash_performed(position)
@warning_ignore("unused_signal")
signal player_moved(position)

# Parry signals
@warning_ignore("unused_signal")
signal parry_success(position)
@warning_ignore("unused_signal")
signal parry_failed
@warning_ignore("unused_signal")
signal parry_window_opened
@warning_ignore("unused_signal")
signal parry_window_closed

# Attack signals
@warning_ignore("unused_signal")
signal attack_performed(attacker, position)
@warning_ignore("unused_signal")
signal attack_hit(target, damage)

# Status effect signals
@warning_ignore("unused_signal")
signal status_effect_applied(target, effect_type, duration)
@warning_ignore("unused_signal")
signal status_effect_removed(target, effect_type)

# Game state signals
@warning_ignore("unused_signal")
signal game_paused
@warning_ignore("unused_signal")
signal game_resumed
@warning_ignore("unused_signal")
signal stage_started(stage_name)
@warning_ignore("unused_signal")
signal stage_completed(stage_name)

# Currency signals
@warning_ignore("unused_signal")
signal currency_changed(currency_type: String, amount: int, new_balance: int)
@warning_ignore("unused_signal")
signal currency_added(currency_type: String, amount: int, new_balance: int)
@warning_ignore("unused_signal")
signal currency_subtracted(currency_type: String, amount: int, new_balance: int)

# AI signals
@warning_ignore("unused_signal")
signal enemy_spotted(enemy, target)
@warning_ignore("unused_signal")
signal enemy_lost_target(enemy)
@warning_ignore("unused_signal")
signal ai_state_changed(enemy, state)

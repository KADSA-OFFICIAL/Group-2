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

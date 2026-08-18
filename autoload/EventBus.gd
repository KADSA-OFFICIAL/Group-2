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
signal stage_completed(stage_name)   # 승리 — 스테이지의 승리 조건을 채웠다
@warning_ignore("unused_signal")
signal stage_failed(stage_name)      # 패배 — 파티가 전멸했다

# Currency signals
@warning_ignore("unused_signal")
signal currency_changed(currency_type: String, amount: int, new_balance: int)
@warning_ignore("unused_signal")
signal currency_added(currency_type: String, amount: int, new_balance: int)
@warning_ignore("unused_signal")
signal currency_subtracted(currency_type: String, amount: int, new_balance: int)

# Status effect signals
@warning_ignore("unused_signal")
signal status_effect_applied(target, effect_id: StringName)
@warning_ignore("unused_signal")
signal status_effect_removed(target, effect_id: StringName)
@warning_ignore("unused_signal")
signal status_effect_burst(target, effect_id: StringName)   # GAUGE가 임계치에서 터짐

# Party signals
@warning_ignore("unused_signal")
signal party_changed(members)              # 파티 편성이 바뀜 (Array[CharacterData])
@warning_ignore("unused_signal")
signal party_control_changed(index: int)   # 조종 대상이 바뀜 (-1 = 없음)

# Equipment signals
@warning_ignore("unused_signal")
signal equipment_crafted(equipment_id: StringName)
@warning_ignore("unused_signal")
signal equipment_equipped(character_id: StringName, equipment_id: StringName, slot: int)
@warning_ignore("unused_signal")
signal equipment_unequipped(character_id: StringName, slot: int)

# 장비가 인벤토리에 들어옴 (제작 외의 경로 — 상점 구매, 우편 수령 등).
# 제작은 equipment_crafted 를 따로 쏘므로 둘을 구분해 들을 수 있다.
signal equipment_granted(equipment_id: StringName, count: int)

# ===== 우편 (Mail) =====
signal mail_added(mail_id: int)
signal mail_claimed(mail_id: int)

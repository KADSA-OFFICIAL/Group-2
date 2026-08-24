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
@warning_ignore("unused_signal")
# 플레이어(직접 조작하는 캐릭터)가 적을 공격했다. 아군 AI 의 전투 진입 신호다(#257).
# target 이 null 이면 광역 공격이라 노린 적이 하나로 정해지지 않는다는 뜻이다 —
# 그때 아군 AI 는 자기에게 가장 가까운 적을 스스로 고른다.
signal player_attacked(attacker, target)

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

# ----- 스킬 (Skill) -----
# 플레이어가 고유 스킬 키(Q·E)를 눌러 발동했다. 효과 구현·이펙트·HUD 가 이 신호를 듣는다.
signal skill_used(user, skill_id: StringName)

# 고유 스킬이 준 보호막이 터졌다(깨짐·만료·재입력). position 에서 반경 안의 적에게 power 피해.
signal skill_shield_burst(target, skill_id: StringName, position: Vector2, power: int)

extends Node

# Combat signals
@warning_ignore("unused_signal")
signal enemy_died(enemy)
@warning_ignore("unused_signal")
signal player_died
@warning_ignore("unused_signal")
signal damage_taken(target, damage, position)
@warning_ignore("unused_signal")
# amount 는 **실제로 오른 체력**이다(요청량이 아니다, #399). 만피에서 회복하면
# 아예 나가지 않는다 — 화면에 "+500"이 뜨는데 체력이 그대로면 거짓말이 된다.
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
# 웨이브가 놓였다(#375). index 는 0 부터, total 은 그 스테이지의 웨이브 수다.
# wave 는 StageWave — 받는 쪽이 label/is_boss 를 읽는다. 시그널 인자를 늘리지 않으려고
# 리소스를 통째로 넘긴다(연출이 늘 때마다 시그널을 고치면 받는 쪽이 전부 깨진다).
@warning_ignore("unused_signal")
signal stage_wave_started(stage_name, index: int, total: int, wave: StageWave)

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

# ----- 튜토리얼이 듣는 행동 신호 (#345) -----
#
# 왜 신호로 알리는가: 튜토리얼은 "플레이어가 실제로 그 행동을 했을 때" 다음 단계로
# 넘어간다(TutorialStepData.Advance). 대시는 상태를 폴링해도 잡을 수 있지만
# 처형은 그 순간 대상이 사라지므로 폴링으로는 잡을 수 없다. 두 사실을 같은 방식으로
# 흘려 두면 조건 판정이 한 종류가 된다.
#
# 튜토리얼 전용 신호는 아니다 — "이 일이 일어났다"는 사실이므로 통계·연출·업적도 쓸 수 있다.

# 캐릭터가 대시했다(충전이 소모된 성공한 대시만).
@warning_ignore("unused_signal")
signal player_dashed(who)

# 처형이 성사됐다. enemy 는 이 직후 죽으므로 **이 신호 안에서만** 유효하다.
@warning_ignore("unused_signal")
signal enemy_executed(enemy, by)

# ----- 여신의 스킬 (#358) -----

# 여신의 스킬이 발동했다(스테이지당 1회). 연출·HUD·통계가 듣는다.
@warning_ignore("unused_signal")
signal goddess_skill_used(skill_id: StringName)

# 시간 정지가 시작/종료됐다. seconds_left 는 시작 시 전체 지속시간, 종료 시 0 이다.
@warning_ignore("unused_signal")
signal time_stop_changed(active: bool, seconds_left: float)

# 시간 가속(#366)의 상태가 바뀌었다. ratio 는 최대치 대비 지금 비율(0~1)이다.
# 매 프레임 나온다 — 화면이 진행을 그릴 수 있어야 하고, 값이 계속 변한다.
@warning_ignore("unused_signal")
signal goddess_haste_changed(active: bool, seconds_left: float, ratio: float)

# ----- 점령 (#377) -----

# 거점 존이 확보됐다(진행도가 확보 시간에 닿은 순간 한 번). 승패 판정은 전장이 하고,
# 이 신호는 연출·소리·통계가 듣는다.
@warning_ignore("unused_signal")
signal capture_zone_captured(zone)

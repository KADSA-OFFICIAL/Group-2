extends CharacterBody2D
class_name EnemyBase

# 적 정의 바탕: EnemyData가 적의 유일한 정의 출처다(EnemyDatabase로 조회).
# 설정되면 이 정의의 스텟/외형을 사용한다.
# 비어 있으면 아래 stats를 그대로 쓰므로 기존 씬은 그대로 동작한다(하위 호환).
@export var data: EnemyData = null

# 스텟 바탕: PlayerStats를 적의 HP/방어력 출처로 재사용한다.
# (faith/intelligence는 적에게 미사용, 기본값 유지)
# 씬에서 .tres로 교체 주입할 수 있도록 export 한다.
@export var stats: PlayerStats = PlayerStats.new()

var hp: int = 0
var max_hp: int = 0
var is_alive: bool = true

# ===== AI 상태 (AI State) =====
# 행동 파라미터의 출처는 EnemyData다("AI 행동" 그룹). 여기서 수치를 새로 만들지 않는다.
# data가 없으면 AI가 동작하지 않는다. 씬에만 저작된 적은 지금 하나도 없지만,
# data 를 빼먹은 씬이 조용히 움직이는 대신 정지하도록 이 방어는 남긴다.
# 의도적으로 멈춰 있어야 하는 적은 data.ai_enabled = false 로 저작한다.

# 투사체 최대 비행 거리 = 사거리 x 이 배수. 딱 사거리(x1.0)로 두면 대상이 한 발짝
# 물러난 순간 탄이 코앞에서 사라진다.
#
# 2.0 인 이유: 1.4(서아 기준 350px)로는 탄이 너무 일찍 사라졌다. 발사는 사거리
# 250px 안에서만 일어나므로, x2.0 이면 최대 거리에서 쏜 탄도 대상 위치를 250px
# 지나쳐 날아간다 — 대상이 물러나며 싸워도 탄이 따라붙는다.
#
# 상한의 기준은 탐지 범위다. 서아는 500px < 탐지 600px 이므로, 탄이 "추격을 놓는
# 거리" 밖까지 날아가지는 않는다. 이 배수를 더 올릴 때는 그 관계를 함께 본다.
const PROJECTILE_RANGE_MARGIN: float = 2.0

# 평타 쿨다운 잔여 시간(초).
var _attack_cooldown_left: float = 0.0

# 강화 평타 충전: 명중시킨 일반 평타 수. data.charged_attack_threshold에 도달하면
# 다음 평타가 강화된다(추가 피해 + 상태이상). threshold=0이면 비활성.
var _charge_count: int = 0

# 현재 추적 대상. 죽거나 탐지 범위를 벗어나면 다시 고른다.
# Node2D로 타입을 잡아 global_position 접근이 정적으로 안전하게 한다.
var _target: Node2D = null

# 이 개체가 소유하는 런타임 스텟. 정의(EnemyData)의 스텟 사본이다.
#
# 왜 사본인가: .tres는 경로 기준으로 캐시되므로, 같은 종류의 적을 여러 마리 스폰하면
# EnemyData와 그 안의 PlayerStats가 **하나로 공유된다**(적 씬이 data를 ExtResource로
# 참조하므로 인스턴스마다 같은 리소스를 가리킨다).
# 지금은 스텟을 읽기만 해서 무해하지만, StatusEffectData가 PlayerStats의 버프 채널을
# 대상으로 삼기 때문에 한 마리에 건 디버프가 같은 종류 전체에 걸린다.
# 정의(.tres)는 읽기 전용 데이터로 남기고, 전투 중 변하는 값은 개체가 소유한다.
var _runtime_stats: PlayerStats = null

# ===== 외형 (Appearance) =====

# 워크 애니메이션을 그리는 노드. 씬에 AnimatedSprite2D가 있고 data.walk_frames가
# 채워져 있을 때만 잡힌다. null이면 이 스크립트는 외형에 전혀 손대지 않으므로
# 워크 시트가 없는 적은 Sprite2D 정지 이미지(또는 도형 플레이스홀더)로 남는다.
var _anim_sprite: AnimatedSprite2D = null

# 멈춤 판정 임계값과 방향 판정은 WalkAnimation이 소유한다(플레이어와 같은 규약).

# 유효한 스텟 출처를 반환한다.
# data가 설정되어 있으면 그 정의의 스텟이 사본의 바탕이 된다(적 정의가 단일 출처).
# 스텟 계산은 언제나 PlayerStats가 소유하므로 여기서 수치를 다시 만들지 않는다.
func get_stats() -> PlayerStats:
	if _runtime_stats == null:
		_runtime_stats = _make_runtime_stats()
	return _runtime_stats

# 정의(또는 씬에 주입된 stats)에서 이 개체만의 스텟 사본을 만든다.
# 처음 get_stats()가 불릴 때 한 번만 만들어지므로, 씬이 export로 주입한 값이 반영된 뒤다.
# duplicate(true): 이후 PlayerStats에 하위 리소스가 추가되어도 같이 복제되게 한다.
func _make_runtime_stats() -> PlayerStats:
	var source: PlayerStats = data.get_stats() if data != null else stats
	if source == null:
		return PlayerStats.new()
	return source.duplicate(true)

func _ready():
	GameManager.register_enemy(self)
	_apply_data()
	max_hp = get_stats().get_max_hp()
	hp = max_hp

	# 머리 위 체력 바. 적이므로 테두리가 빨강이다(#249).
	# _apply_data() 뒤에 붙인다 — 바가 보이는 스프라이트에서 높이를 계산하기 때문이다.
	var bar := HealthBar.new()
	bar.name = "HealthBar"
	bar.hostile = true
	add_child(bar)

# EnemyData가 설정된 경우에만 정의의 외형을 반영한다.
# data가 없으면 씬에 저작된 값을 건드리지 않는다.
#
# 노드 name은 건드리지 않는다: name은 씬 트리 식별자이고 display_name은 UI 표시용이다.
# (Godot이 name을 유일화하므로 둘을 섞으면 표시 이름이 깨진다.)
# 표시 이름이 필요한 UI는 data.display_name을 직접 읽는다.
func _apply_data() -> void:
	if data == null:
		return

	var sprite := get_node_or_null("Sprite2D")
	if sprite is Sprite2D:
		if data.sprite_texture != null:
			sprite.texture = data.sprite_texture
		sprite.self_modulate = data.tint
		sprite.scale = data.sprite_scale

	# 워크 시트가 있으면 AnimatedSprite2D가 외형을 맡고 도형 플레이스홀더는 숨는다.
	# 둘 중 하나만 보이게 해서 실제 아트 위에 도형이 겹쳐 보이지 않게 한다.
	#
	# tint를 입히지 않는 이유: tint는 흰색 도형을 칠하려고 둔 값이라
	# 색이 있는 실제 아트에 곱하면 색이 죽는다(EnemyData.tint 주석 참고).
	var anim := get_node_or_null("AnimatedSprite2D")
	if anim is AnimatedSprite2D and data.walk_frames != null:
		_anim_sprite = anim
		_anim_sprite.sprite_frames = data.walk_frames
		_anim_sprite.scale = data.walk_sprite_scale
		_anim_sprite.offset = data.walk_sprite_offset
		# 첫 프레임은 정면 정지 포즈로 둔다. animation을 지정하지 않으면 기본값 &"default"를
		# 찾다가 없어서 경고가 난다.
		_anim_sprite.animation = WalkAnimation.ANIMATIONS[WalkAnimation.DOWN]
		_anim_sprite.frame = 0
		_anim_sprite.visible = true
		if sprite is Sprite2D:
			sprite.visible = false

func _exit_tree():
	GameManager.unregister_enemy(self)


# ===== AI (추적 / 공격) =====

# AI가 지금 동작해야 하는가.
# data가 없는 적(씬에만 저작된 기존 적)과 ai_enabled=false인 적은 정지한다.
func is_ai_active() -> bool:
	return is_alive and data != null and data.ai_enabled


func _physics_process(delta: float) -> void:
	if _attack_cooldown_left > 0.0:
		_attack_cooldown_left -= delta

	_process_ai()

	# AI가 꺼져 있어도(velocity가 계속 0) 호출한다. 그래야 정지 포즈로 고정된다.
	_update_walk_animation()


# 추적/공격 AI 한 틱. velocity를 정하고 필요하면 실제로 이동시킨다.
# 외형 갱신과 분리해 둔 이유: 아래 조기 반환들이 애니메이션 갱신까지 건너뛰면
# 적이 멈춘 뒤에도 걷는 모션이 남기 때문이다.
func _process_ai() -> void:
	if not is_ai_active():
		return

	# 기절 등 CONTROL 효과가 이동을 막으면 추적하지 않는다.
	# (탱커 표식이 터져 기절시켰을 때 적이 실제로 멈춰야 한다.)
	if StatusEffectSystem.blocks_movement(self):
		velocity = Vector2.ZERO
		return

	_target = _resolve_target()
	if _target == null:
		velocity = Vector2.ZERO
		return

	# 사거리 안이면 멈춰서 때리고, 밖이면 직선으로 접근한다.
	# 길찾기(장애물 회피)는 이 단계의 범위가 아니다.
	if global_position.distance_to(_target.global_position) <= data.attack_range:
		velocity = Vector2.ZERO
		try_attack()
	else:
		velocity = global_position.direction_to(_target.global_position) * get_move_speed()

	move_and_slide()


# ===== 워크 애니메이션 (Walk animation) =====

# 지금 속도에 맞는 방향 애니메이션을 재생한다. 멈춰 있으면 정지 포즈로 고정한다.
# 시트가 없는 적은 _anim_sprite가 null이라 아무 일도 하지 않는다.
func _update_walk_animation() -> void:
	if _anim_sprite == null:
		return

	if not WalkAnimation.is_walking(velocity):
		# 멈추면 재생을 세우고 정지 포즈(0번 프레임)로 고정한다.
		# animation은 그대로 두어 마지막으로 향했던 방향을 유지한다
		# — 멈출 때마다 정면으로 홱 돌아보면 어색하기 때문이다.
		if _anim_sprite.is_playing():
			_anim_sprite.stop()
			_anim_sprite.frame = 0
		return

	var anim := WalkAnimation.animation_for(velocity)
	if _anim_sprite.animation != anim or not _anim_sprite.is_playing():
		_anim_sprite.play(anim)


# 추적 대상을 결정한다.
# 지금 대상이 아직 유효하면 유지하고(대상이 매 프레임 바뀌어 떠는 것을 막는다),
# 아니면 가장 가까운 파티 멤버를 새로 고른다.
#
# 도발(#328)이 걸려 있으면 그 무엇보다 먼저다 — 지금 붙어 싸우던 대상도, 거리도 무시하고
# 도발한 쪽으로 간다. 그것이 도발의 정의다.
func _resolve_target() -> Node2D:
	var taunter := _taunt_target()
	if taunter != null:
		return taunter
	if _is_valid_target(_target):
		return _target
	return _find_nearest_party_member()


# 도발이 강제하는 대상. 없으면 null.
#
# _is_valid_target() 을 쓰지 않는다: 그 함수는 **탐지 범위 안**인지도 보는데, 도발은
# 범위를 무시하는 것이 요점이다. 탐지 범위 안에서만 듣는 도발은 이미 오고 있던 적에게는
# 아무 일도 하지 않는 것과 같다.
#
# 살아 있는지는 그대로 본다 — 죽은 대상을 향해 계속 걸어가면 적이 멈추지 않는다.
# 그 경우 null 을 돌려주므로 지금까지의 대상 선정으로 돌아간다.
func _taunt_target() -> Node2D:
	var source := StatusEffectSystem.get_taunt_source(self)
	if source == null or not is_instance_valid(source):
		return null
	var member := source as Node2D
	if member == null:
		return null
	var alive = member.get("is_alive")
	if alive != null and not bool(alive):
		return null
	return member


# 추적 대상으로 쓸 수 있는 노드인가.
# 살아 있고 탐지 범위 안에 있어야 한다. 범위를 벗어나면 놓으므로 무한 추격이 되지 않는다.
#
# **파라미터에 타입을 붙이지 않는다**(#245). _target 은 파티원 노드를 들고 있는데
# 그 파티원이 죽으면 queue_free 로 해제된다. Node 로 타입을 박으면 해제된 객체가
# 인자 타입 검사에서 걸려 아래 is_instance_valid() 가드에 **도달하지 못하고** 에러가 난다
# ("argument 1 (previously freed) is not a subclass of the expected argument class").
# 가드가 있는데도 에러가 나던 원인이 이것이다.
func _is_valid_target(node) -> bool:
	# 탐지 범위의 출처가 data이므로 data가 없으면 대상 판정 자체가 성립하지 않는다.
	if data == null:
		return false
	if node == null or not is_instance_valid(node):
		return false
	var target := node as Node2D
	if target == null:
		return false
	# 파티 멤버는 is_alive를 가진다. 죽은 대상은 추적하지 않는다.
	# get()으로 읽어 is_alive가 없는 노드도 안전하게 처리한다(없으면 null).
	var alive = target.get("is_alive")
	if alive != null and not bool(alive):
		return false
	return global_position.distance_to(target.global_position) <= data.detection_range


# 탐지 범위 안에서 가장 가까운 살아 있는 파티 멤버를 반환한다. 없으면 null.
#
# 그룹으로 조회하는 이유: GameManager는 적 등록/조회만 담당하고 파티 멤버 노드
# 레지스트리가 없다. (PartySystem은 CharacterData 편성만 알고 씬 노드는 모른다.)
# 그룹 이름은 PartySystem.MEMBER_GROUP이 단일 출처이며 여기서 문자열을 다시 적지 않는다.
func _find_nearest_party_member() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF

	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if not _is_valid_target(node):
			continue
		var member := node as Node2D
		var distance := global_position.distance_to(member.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = member

	return nearest


# 실제 이동속도 = 기본 속도(CombatConfig) x 적 고유 배수(EnemyData) x 버프 이속 배수(PlayerStats).
# 버프 채널을 곱에 포함해 두면 이후 이속 디버프가 적에게도 그대로 적용된다.
func get_move_speed() -> float:
	var unit: float = 1.0 if data == null else data.move_speed_multiplier
	return CombatConfig.tuning.base_move_speed * unit * get_stats().get_move_speed_multiplier()


# 실제 평타 쿨다운 = 기본 쿨다운(CombatConfig) / (적 고유 공속 배수 x 버프 공속 배수).
func get_attack_cooldown() -> float:
	var unit: float = 1.0 if data == null else data.attack_speed_multiplier
	var multiplier := unit * get_stats().get_attack_speed_multiplier()
	if multiplier <= 0.0:
		return CombatConfig.tuning.base_attack_cooldown
	return CombatConfig.tuning.base_attack_cooldown / multiplier


func can_attack() -> bool:
	# 기절 등 CONTROL 효과가 평타를 막으면 공격할 수 없다.
	return is_alive and _attack_cooldown_left <= 0.0 and not StatusEffectSystem.blocks_attack(self)


# 현재 대상에게 평타를 넣는다. 쿨다운 중이면 아무것도 하지 않는다.
# 피해량은 PlayerStats.get_physical_attack()이 출처이고,
# 방어력 적용은 대상의 take_damage()(-> PlayerStats.apply_defense())가 한다.
# 여기서 피해를 다시 계산하지 않는다.
func try_attack() -> bool:
	if not can_attack():
		return false
	if not _is_valid_target(_target):
		return false
	if not _target.has_method("take_damage"):
		return false

	_attack_cooldown_left = get_attack_cooldown()

	# 강화 평타 판정: threshold까지 충전됐으면 이번 평타가 강화된다.
	var threshold: int = data.charged_attack_threshold if data != null else 0
	var is_charged: bool = threshold > 0 and _charge_count >= threshold

	var damage: int = get_stats().get_physical_attack()
	if is_charged:
		damage = int(round(damage * data.charged_attack_damage_multiplier))

	var effect_id: StringName = data.charged_attack_effect if (is_charged and data != null) else &""

	# 원거리 적은 탄을 날린다. 근접 적(projectile_scene 이 비어 있음)은 즉시 피해다.
	if data != null and data.projectile_scene != null:
		_fire_projectile(damage, effect_id)
	else:
		_target.take_damage(damage, self)
		# 대상이 그 사이 죽었으면 효과를 걸지 않는다.
		if effect_id != &"" and is_instance_valid(_target) and _target.get("is_alive") != false:
			StatusEffectSystem.apply(_target, effect_id, self)

	if is_charged:
		_charge_count = 0
	else:
		_charge_count += 1

	return true


# 대상 방향으로 투사체를 스폰한다 (#214).
#
# 발사 시점의 방향으로만 날아간다(유도 없음) — 그래서 대상이 비키면 빗나간다.
# 피해량은 여기서 정해 실어 보내고, 방어 적용은 명중 시 대상의 take_damage 가 한다.
#
# 부모를 이 적이 아니라 **적의 부모(방)** 로 두는 이유: 적이 죽어도 이미 쏜 탄은
# 계속 날아가야 하고, 방을 버릴 때(Stage1_1.load_room) 탄도 함께 정리되어야 한다.
func _fire_projectile(damage: int, effect_id: StringName) -> void:
	var host := get_parent()
	if host == null:
		return

	var projectile = data.projectile_scene.instantiate()
	host.add_child(projectile)
	projectile.global_position = global_position

	# 최대 비행 거리는 사거리에 여유를 준다. 딱 사거리로 두면 대상이 한 발짝
	# 물러난 순간 탄이 코앞에서 사라진다.
	var reach: float = data.attack_range * PROJECTILE_RANGE_MARGIN
	projectile.setup(
		global_position.direction_to(_target.global_position),
		data.projectile_speed, damage, self, reach,
		data.projectile_hit_radius, effect_id, data.tint)

# 실제로 들어간 피해(방어 적용 후)를 반환한다.
# 피흡처럼 "준 피해에 비례하는" 효과가 그 값을 알아야 한다 — 공격력으로 계산하면
# 방어력 높은 적을 때릴 때 실제보다 크게 회복된다.
#
# ignore_defense: 방어력을 적용하지 않는다(#328). 기본은 false 다 — 방어 공식을 우회하는 것은
# 예외이며, 지금 이 통로를 쓰는 것은 "대가로 내는 자기 피해"(StatusEffectData.tick_ignores_defense)
# 하나뿐이다. 적에게 이 값이 true 로 들어오는 경우는 아직 없지만, 시그니처는 Player 와 맞춰 둔다
# — 상태 효과 틱은 대상이 적인지 파티원인지 가리지 않고 같은 코드로 부른다.
func take_damage(amount: int, source = null, ignore_defense: bool = false) -> int:
	if not is_alive:
		return 0

	# 방어력 적용. 피해 공식은 PlayerStats.apply_defense()가 단일 출처다.
	# (여기서 다시 계산하지 않는다 — 이전에는 Player와 중복 구현되어 있었다.)
	# 계산된 피해와 **실제로 깎인 체력**은 다르다. 남은 체력보다 큰 피해는 넘치는 만큼 버려진다.
	# 반환값의 계약이 "실제로 들어간 피해"이므로 여기서 자른다.
	#
	# 자르지 않으면 "준 피해에 비례하는" 효과가 전부 부풀어 오른다. 처형이 대표적이다 —
	# 처형은 방어력에 막히지 않으려고 max_hp x 100 을 넣는데, 체력 240 남은 적을 처형하면
	# dealt 가 24만으로 잡혀 흡혈 50 퍼센트가 12만을 회복시킨다(만피 회복).
	var raw: int = amount if ignore_defense else get_stats().apply_defense(amount)
	var dealt: int = mini(raw, hp)
	hp -= dealt

	if EventBus:
		EventBus.damage_taken.emit(self, dealt, global_position)

	# 피해를 **준 쪽**에 실제로 들어간 양을 알린다(#276).
	#
	# 왜 여기인가: "준 모든 피해를 흡혈한다"는 평타·스킬·광역을 가리지 않는다. 그 전부를
	# 훑으려면 피해를 내는 자리마다 같은 코드를 붙여야 하는데, 피해가 **들어오는** 곳은
	# 여기 하나다. 한 곳에서 알리면 새 피해 경로가 생겨도 자동으로 포함된다.
	#
	# 평타 한정 피흡(원거리 3단계)은 여기로 오지 않는다 — 그쪽은 "평타로 준 피해"가 계약이라
	# Player._resolve_attack_hit() 이 계속 갖는다. 두 채널은 별개다.
	if source != null and is_instance_valid(source) and source.has_method("on_damage_dealt"):
		source.on_damage_dealt(dealt)

	if hp <= 0:
		die()
	return dealt

func die():
	is_alive = false
	if EventBus:
		EventBus.enemy_died.emit(self)
	queue_free()
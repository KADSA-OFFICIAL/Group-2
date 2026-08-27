# data/enemies

적(`EnemyData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`EnemyDatabase`(autoload)가 시작 시 이 폴더의 모든 `.tres`를 로드해
`enemy_id`로 조회를 제공한다.

- 정의 스키마: [`entities/enemies/EnemyData.gd`](../../entities/enemies/EnemyData.gd)

## 재사용 원칙 (단일 출처)

- **스텟**은 기존 [`PlayerStats`](../../entities/player/PlayerStats.gd)를 재사용한다.
  적 전용 스텟 체계를 새로 만들지 않는다. `EnemyBase`도 이미 `PlayerStats`를 쓴다.
- **스킬**은 기존 [`SkillData`](../../entities/character/SkillData.gd)를 재사용한다.
- 덕분에 `PlayerStats`를 대상으로 하는 시스템(버프/디버프, 피해 계산 등)이 적에게도 그대로 적용된다.

## 캐릭터(`data/characters`)와 분리하는 이유

로스터는 설계상 **정확히 9명**이고 `CharacterDatabase.get_all_ids()` / `get_count()`가
그 로스터 조회로 쓰인다. 적을 같은 레지스트리에 넣으면 이 조회가 오염되므로
디렉터리와 레지스트리를 분리한다.

또한 `EnemyData`에는 `role`(브루저/원거리/버퍼)과 장비 슬롯이 **없다**.
둘 다 파티 편성·역할 구성 시너지·제작 전용 의미이므로 적에게는 부적합하다.

## 씬 연결

`EnemyBase`의 `data` 필드에 `.tres`를 지정하면 그 정의의 스텟/외형이 적용된다.
비워 두면 씬에 저작된 기존 값을 그대로 쓴다(하위 호환).

## 외형: 도형 플레이스홀더 vs 워크 시트

적 하나의 외형 경로는 둘 중 하나다. `EnemyBase._apply_data()`가 데이터만 보고 고른다.

| 경로 | 조건 | 그리는 노드 |
|---|---|---|
| 도형 플레이스홀더(정지) | `walk_frames`가 비어 있음 | `Sprite2D` |
| 4방향 워크 애니메이션 | `walk_frames` 지정 + 씬에 `AnimatedSprite2D` 있음 | `AnimatedSprite2D` |

워크 시트를 쓰면 `Sprite2D`(도형)는 숨겨지고, 이동 방향에 맞는 워크 사이클이 재생된다.
멈추면 그 방향의 정지 포즈로 고정된다. 시트 규약과 `walk_sprite_scale` / `walk_sprite_offset`
맞추는 법은 [`assets/sprites/enemies/README.md`](../../assets/sprites/enemies/README.md)에 있다.

실제 적 수치/밸런스는 팀이 저작한다.

## 보스가 쓰는 행동 (#376)

`EnemyData` 에 있는 아래 필드는 **저작하지 않으면 꺼져 있다**(기본값 0/false). 그래서 기존
적 정의는 이 기능들이 생기기 전과 똑같이 동작한다.

| 그룹 | 필드 | 무엇 |
|---|---|---|
| 광역 평타 | `basic_attack_aoe_radius` | 평타가 **대상 자리** 주변에도 들어간다. 0 이면 단일 대상 |
| 대시 | `dash_speed` · `dash_duration` · `dash_cooldown` · `dash_trigger_distance` · `dash_hit_radius` · `dash_damage_multiplier` | 평타 사거리 밖이면 돌진하고 경로 위 파티원을 때린다. `dash_speed` 0 이면 대시하지 않는다 |
| 특별 스킬 | `phase_skill_hp_step` · `phase_skills` | 최대 체력의 step 만큼 깎일 때마다 스킬을 하나씩 돌려 가며 쓴다 |

광역 평타의 중심이 **시전자가 아니라 대상 자리**인 이유: 사거리 안의 한 명을 노려 내리치는
동작이라 판정의 중심은 때리는 자리다. 시전자 중심으로 잡으면 사거리 밖 뒤쪽 파티원까지 맞는다.

### 특별 스킬의 안무는 적 스크립트가 갖는다

`phase_skills` 의 `SkillData` 는 **수치의 출처**(준비 시간·판정 크기·피해 비율)이고,
"2초 준비 후 돌진" 같은 진행은 그 적의 스크립트가 갖는다
(`entities/enemies/MammothBoss.gd`). 안무까지 데이터로 일반화하면 쓰는 적이 하나뿐인
필드가 열 개 늘어난다.

적 스킬 `.tres` 는 [`data/enemies/skills`](skills/) 에 저작한다 — `data/skills` 는
**캐릭터별 고유 6종** 전용이다.

### 최대 체력 비례 피해는 회피 창과 함께 온다

`SkillData.target_max_hp_damage_percent` 는 대상이 깎여 있든 아니든 같은 값을 넣는다 —
**맞으면 죽을 수 있다.** 이 무게를 쓰는 스킬에는 반드시 준비자세나 착지 예고 같은 회피 창을
함께 둔다(`entities/combat/BossTelegraph.gd`). 예고로 그리는 크기는 판정 크기와 **같아야**
한다(docs/vfx-guide.md §1.2).

## 지금 있는 적

| id | 무엇 |
|---|---|
| `seoa` | 원거리 표준 적(tier 1 기준) |
| `velociraptor_beastfolk` / `_2` | 물몸·고이속 근접. 스탯이 같고 외형만 다르다 |
| `mammoth_beastfolk` | 고체력 근접 브루저. 4타째 강화 평타로 기절 |
| `mammoth_boss` | 첫 보스. 매머드 리소스를 키워 쓰고 광역 평타·3타 기절·대시·특별 스킬 2종 |

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

실제 적 수치/밸런스는 팀이 저작한다.

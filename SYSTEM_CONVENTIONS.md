# 시스템 구축 규칙 (System Conventions)

이 문서는 **새 시스템을 추가할 때 기존 시스템을 무시하거나 덮어쓰지 않도록** 하는 규칙을 정한다.
새 기능/시스템을 만들기 전에 이 문서와 [CLAUDE.md](CLAUDE.md)(issue-first 워크플로우)를 먼저 읽는다.

> 배경: PR #35에서 기존 `CurrencySystem`(#28 단일 출처)·`player_hp` 저장·`CharacterDatabase` autoload가
> 원복/누락되는 충돌이 있었다. 같은 문제를 반복하지 않기 위한 규칙이다.

---

## 1. 기존 코어 시스템 레지스트리

새 시스템을 만들기 전에 **아래가 이미 존재하는지 확인**하고, 있으면 재사용/참조한다. (덮어쓰지 않는다)

| 시스템 | 위치 | 역할 | 단일 출처 |
|---|---|---|---|
| EventBus | `autoload/EventBus.gd` | 시스템 간 시그널 허브 | 이벤트/시그널 |
| GameManager | `autoload/GameManager.gd` | 적 등록/조회 등 런타임 관리 | 활성 적 목록 |
| SaveSystem | `autoload/SaveSystem.gd` | 저장/불러오기 | 저장 스키마 |
| CurrencySystem | `autoload/CurrencySystem.gd` | 재화 관리 | `DEFAULT_CURRENCIES` 상수 |
| CharacterDatabase | `autoload/CharacterDatabase.gd` | 캐릭터 데이터 조회 레지스트리 | `data/characters/*.tres` |
| EquipmentDatabase | `autoload/EquipmentDatabase.gd` | 장비 데이터 조회 레지스트리 | `data/equipment/*.tres` |
| EquipmentSystem | `autoload/EquipmentSystem.gd` | 장비 제작(재화 차감)·보유·착탈 | 보유 인벤토리 |
| PlayerStats | `entities/player/PlayerStats.gd` | 기초/파생 스텟 계산 (Resource) | 캐릭터/적 스텟 |
| CharacterData | `entities/character/CharacterData.gd` | 캐릭터 정의(이름/스텟/스킬/외형/장비) (Resource) | 캐릭터 정의 |
| SkillData | `entities/character/SkillData.gd` | 스킬 데이터 정의 (Resource) | 스킬 정의 |
| EquipmentData | `entities/equipment/EquipmentData.gd` | 장비 정의(슬롯/스텟보너스/제작비용) (Resource) | 장비 정의 |
| MusicSystem | `autoload/MusicSystem.gd` | 배경음악 재생(한 번에 한 곡, 페이드) | 재생 중인 트랙 |
| TutorialSystem | `autoload/TutorialSystem.gd` | 전투 튜토리얼 진행(단계 판정·정지·완료 저장) | 진행 상태 / `data/tutorial/*.tres` |
| TutorialSequenceData | `entities/tutorial/TutorialSequenceData.gd` | 스테이지 하나의 튜토리얼 단계 묶음 (Resource) | 튜토리얼 단계 정의 |
| GoddessSkillSystem | `autoload/GoddessSkillSystem.gd` | 여신의 스킬 — 선택·스테이지당 1회·시전(시간 정지/부활) | 선택 상태 / `data/goddess_skills/*.tres` |
| GoddessSkillData | `entities/goddess/GoddessSkillData.gd` | 여신의 스킬 정의 (Resource) | 여신 스킬 정의 |

> 새 autoload/시스템을 추가하면 **이 표에 한 줄 추가**한다.

---

## 2. 단일 출처(Single Source of Truth) 원칙

각 도메인 데이터는 **한 곳에서만** 정의하고, 다른 시스템은 그것을 **참조**한다. 복제·병렬 정의 금지.

- **재화**: 재화 목록은 `CurrencySystem.DEFAULT_CURRENCIES` 상수가 유일한 출처다.
  `_ready()`/`reset_currencies()`/`SaveSystem`의 기본 저장값이 모두 이 상수를 참조한다.
  새 재화는 이 상수에 추가한다. 재화 딕셔너리를 다른 파일에 다시 인라인하지 않는다.
- **스텟**: 캐릭터/적의 HP·공격력·방어력 등은 `PlayerStats`에서 파생한다.
  같은 값을 저장 스키마 등에 중복 저장하지 않는다. (예: `player_hp`를 별도로 저장하지 않음)
- **캐릭터**: 캐릭터 정의는 `CharacterData`(+ `data/characters/*.tres`)가 출처이고,
  조회는 `CharacterDatabase`를 통한다.
- 여러 시스템이 같은 데이터를 필요로 하면, 새 필드를 복제하지 말고 **출처를 참조하거나 EventBus로 통신**한다.

---

## 3. Autoload 규칙

`project.godot`의 `[autoload]`는 여러 시스템이 공유하는 영역이다. **병합(append)만 하고, 기존 항목을 지우거나 통째로 재작성하지 않는다.**

- 새 autoload는 기존 목록 **아래에 한 줄 추가**한다.
- 기존 autoload(`EventBus`/`GameManager`/`SaveSystem`/`CurrencySystem`/`CharacterDatabase` 등)를 **삭제하지 않는다.**
- `run/main_scene`을 바꿔야 하면 PR 본문에 명시하고 팀과 합의한다.
- **로드 순서(의존성)**가 있으므로, 다른 시스템에 의존하는 autoload는 의존 대상 **뒤에** 둔다.
- 머지 충돌 해결:
  - 서로 **다른** 시스템의 autoload는 모두 보존한다 (한쪽 목록을 통째로 버리지 않는다).
  - **같은 이름이 충돌하거나 두 항목이 같은 책임을 중복**하면(예: 두 autoload가 모두 재화를 소유), 둘 다 등록해 각자 굴리지 말고 **§2에 따라 출처 하나를 정한 뒤, 나머지는 그 출처를 참조/위임하도록 바꾸거나 중복 부분을 제거**한다. 이 결정은 이슈/PR에서 합의한다.
  - 병합 후 **중복 이름·로드 순서**를 점검한다.

---

## 4. 새 시스템 추가 체크리스트

내가 새 시스템을 만들 때 순서대로 확인한다.

1. **이슈 먼저** — [CLAUDE.md](CLAUDE.md)의 issue-first 규칙에 따라 이슈를 만든다.
2. **레지스트리 확인** — §1 표에서 유사/중복 시스템이 이미 있는지 본다. 있으면 확장/참조한다.
3. **출처 재사용** — 재화는 `CurrencySystem`, 스텟은 `PlayerStats`, 캐릭터는 `CharacterData`를 통한다. 새 출처를 만들지 않는다.
4. **비파괴적 추가** — 기존 파일/씬/autoload를 덮어쓰지 말고 위에 얹는다. Resource 필드는 안전한 기본값과 함께 추가해 기존 `.tres` 호환을 유지한다.
5. **통신은 EventBus** — 시스템 간 결합은 직접 참조보다 시그널을 우선한다.
6. **레지스트리 갱신** — 새 autoload/코어 시스템을 만들면 §1 표에 등록한다.
7. **검증 기록** — Godot 헤드리스 등으로 검증하고 PR 본문에 남긴다.

---

## 5. 통합/머지 시 회귀 방지

- **`-s ours` 등으로 기존 히스토리를 덮는 통합을 지양**한다. 기존 커밋 내용을 조용히 되돌릴 수 있다.
- 큰 통합 브랜치는 머지 전에 핵심 파일 회귀 여부를 확인한다:
  ```
  git diff main <branch> -- autoload/CurrencySystem.gd autoload/SaveSystem.gd \
    autoload/CharacterDatabase.gd entities/player/PlayerStats.gd project.godot
  ```
- GitHub이 "MERGEABLE"이라 표시해도 diff를 직접 확인한다. (충돌 없음 ≠ 회귀 없음)
- 재화/스텟/autoload에 변화가 있으면 PR 본문 **Residual risks**에 명시한다.
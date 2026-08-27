# data/equipment

장비 아이템(`EquipmentData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`EquipmentDatabase`(autoload)가 시작 시 이 폴더의 모든 `.tres`를 로드해
`equipment_id`로 조회를 제공한다.

- 정의 스키마: [`entities/equipment/EquipmentData.gd`](../../entities/equipment/EquipmentData.gd)
- 슬롯: 무기(WEAPON) / 투구(HELMET) / 갑옷(CHEST) / 레깅스(LEGGINGS) / 거울(MIRROR)
- 티어(재료): 방어구 = 스톤→철→후다만티움, 거울 = 청동(tin+copper)→후다만티움. 같은 라인 내 티어마다 스탯 약 ×1.6 (#157)
- `craft_cost`의 키는 `CurrencySystem.DEFAULT_CURRENCIES`의 재화 id를 참조한다.

실제 아이템 수치/제작 비용은 게임 밸런스 영역이므로 팀이 저작한다.

## description 과 summary — 읽는 사람이 다르다 (#360)

두 필드가 있고 **섞어 쓰지 않는다.** 스킬(#353)이 먼저 쓴 규약을 그대로 따른다.

| 필드 | 읽는 사람 | 내용 |
|---|---|---|
| `description` | 개발자 | **왜 이 수치·이 구성인가.** 이슈 번호·`[임시값]` 표시가 들어간다 |
| `summary` | 플레이어 | **무엇인가.** 화면이 이것만 그린다 |

`description` 을 화면에 그대로 냈더니 플레이어가 이슈 번호와 `[임시값]` 을 읽었다.
그렇다고 `description` 을 다듬으면 **설계 근거가 사라진다.**

### `summary` 저작 규약

- 이슈 번호·마크다운·`[임시값]`·필드명을 쓰지 않는다.
- **수치를 글로 다시 적지 않는다.** 화면이 필드에서 읽어 따로 그린다 —
  글에 또 적으면 데이터를 고칠 때 둘이 갈라진다.
- 수치로 드러나지 않는 것만 적는다.
- 비어 있으면 화면이 **아무것도 그리지 않는다.** 개발 노트가 새는 것보다 낫다.

`tests/data/VerifyPlayerFacingText.tscn` 이 이 규약을 검사한다 — 저작된 `summary` 에
개발 노트 표시가 없는지, 그리고 **화면이 실제로 `summary` 를 읽는지**까지 본다.
필드만 만들고 화면을 안 고치면 아무것도 달라지지 않기 때문이다.

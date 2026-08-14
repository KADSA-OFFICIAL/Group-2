# data/shop

상점 판매 항목(`ShopEntryData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`ShopDatabase`(autoload)가 시작 시 이 폴더의 모든 `.tres`를 로드해
`entry_id`로 조회를 제공한다.

- 정의 스키마: [`entities/shop/ShopEntryData.gd`](../../entities/shop/ShopEntryData.gd)

**아직 저작된 판매 항목이 없다.** 이 폴더가 비어 있어도 오류 없이 로드되고,
상점 화면은 "판매 중인 물건이 없습니다"를 보여준다.

## 무엇을 저작하는가

| 필드 | 내용 |
|---|---|
| `entry_id` | 고유 식별자 (예: `shop_stone_axe`) |
| `equipment_id` | 파는 장비. 정의의 출처는 `EquipmentDatabase` |
| `count` | 한 번 구매 시 지급 개수 |
| `price` | 재화 id → 수량. 비우면 무료 |

`price` 에 기본값을 두지 않았다. **가격은 기획이 정한다.**
임의의 수치를 넣으면 나중에 밸런스를 잡을 때 그 값이 근거처럼 남는다.

## 제조(`data/equipment`)와 다른 점

제조는 `EquipmentData.craft_cost`(재료로 만든다)를 쓰고,
상점은 여기 `price`(대가를 주고 산다)를 쓴다.
두 값이 같아야 할 이유가 없으므로 가격을 따로 둔다.

## 아직 필드가 없는 것

재고 한도, 구매 횟수 제한, 기간 한정, 할인율, 통화별 상점 분리는 두지 않았다.
설계에 정해진 바가 없다. 정해지면 `@export` 필드를 **기본값과 함께** 추가한다.

# data/equipment

장비 아이템(`EquipmentData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`EquipmentDatabase`(autoload)가 시작 시 이 폴더의 모든 `.tres`를 로드해
`equipment_id`로 조회를 제공한다.

- 정의 스키마: [`entities/equipment/EquipmentData.gd`](../../entities/equipment/EquipmentData.gd)
- 슬롯: 무기(WEAPON) / 투구(HELMET) / 갑옷(CHEST) / 레깅스(LEGGINGS) / 거울(MIRROR)
- 티어(재료): 방어구 = 스톤→철→후다만티움, 거울 = 청동(tin+copper)→후다만티움. 같은 라인 내 티어마다 스탯 약 ×1.6 (#157)
- `craft_cost`의 키는 `CurrencySystem.DEFAULT_CURRENCIES`의 재화 id를 참조한다.

실제 아이템 수치/제작 비용은 게임 밸런스 영역이므로 팀이 저작한다.

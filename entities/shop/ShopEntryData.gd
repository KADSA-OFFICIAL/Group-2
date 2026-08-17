extends Resource
class_name ShopEntryData

# 상점 판매 항목의 단일 정의 출처 (data definition).
#
# 무엇을 얼마에 파는가 한 줄이 곧 이 리소스 하나다.
# 실제 판매 목록은 data/shop/*.tres 로 저작하고 ShopDatabase 가 로드한다.
#
# EquipmentData / StageData 와 같은 규약을 따른다:
#   식별 필드 + @export, validate(), 전용 레지스트리로 조회.
#
# 제조(EquipmentSystem.craft)와 다른 점:
#   제조는 EquipmentData.craft_cost 를 쓴다(재료로 만든다).
#   상점은 여기 price 를 쓴다(대가를 주고 산다).
#   두 값이 같아야 할 이유가 없으므로 가격을 따로 둔다.

# ===== 식별 (Identity) =====
@export var entry_id: StringName = &""   # 고유 식별자 (예: &"shop_stone_axe")

# ===== 무엇을 파는가 =====
# 파는 장비의 id. 정의의 출처는 EquipmentDatabase 다(여기서 장비를 재정의하지 않는다).
# 표시 이름·아이콘·스텟 보너스는 모두 그쪽에서 읽는다.
@export var equipment_id: StringName = &""

# 한 번 구매할 때 지급하는 개수.
@export var count: int = 1

# ===== 얼마에 파는가 =====
# 재화 id(String) -> 필요 수량(int).
# 키는 CurrencySystem.DEFAULT_CURRENCIES 의 재화 id 를 참조한다(단일 출처).
# 비어 있으면 무료로 취급한다.
#
# **가격은 기획이 저작한다.** 여기에 기본값을 넣지 않는 이유가 그것이다.
@export var price: Dictionary = {}

# ----- 여기에 없는 것 -----
# 재고 한도, 구매 횟수 제한, 기간 한정, 할인율, 통화별 상점 분리는 두지 않았다.
# 설계에 정해진 바가 없다. 정해지면 @export 필드를 기본값과 함께 추가한다
# (기본값이 있으면 기존 .tres 는 누락 필드를 기본값으로 로드한다).


# 데이터 무결성 점검. 문제 메시지 배열을 반환한다.
# EquipmentData.validate() 와 같은 규약.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(entry_id).is_empty():
		problems.append("entry_id가 비어 있습니다.")
	if String(equipment_id).is_empty():
		problems.append("equipment_id가 비어 있습니다.")
	if count <= 0:
		problems.append("count는 1 이상이어야 합니다.")
	for key in price:
		if typeof(price[key]) != TYPE_INT or int(price[key]) < 0:
			problems.append("price['%s']는 0 이상의 정수여야 합니다." % str(key))
	return problems

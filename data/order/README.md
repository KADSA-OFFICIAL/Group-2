# data/order

본거지 뜰에 놓이는 **건물**을 저작하는 곳이다. 스키마는 [`entities/order/OrderBuildingData.gd`](../../entities/order/OrderBuildingData.gd), 화면은 [`screens/order/order_yard.gd`](../../screens/order/order_yard.gd) 다.

## 건물이 하는 일

건물은 **기능으로 들어가는 문**이다. `screen_path` 에 적힌 화면이 열린다. 비워 두면 눌리지 않는 장식이 된다.

제조·상점의 규칙은 각 시스템이 소유한다. 여기에는 "무엇처럼 보이고, 어디에 서 있고, 어디로 가는가"만 둔다.

## 자리 잡는 법

- `spot` 은 **더 이상 건물이 서는 자리를 정하지 않는다**(#319). 뜰이 한 번에 한 채만 세우게 되면서 자리는 `order_yard.gd` 의 `FEATURE_SPOT` 상수가 정한다.
  지금 `spot` 이 하는 일은 **목록 순서**뿐이다 — `OrderSystem` 이 `spot.y` 오름차순으로 정렬하고, 그 순서가 곧 아래 탭과 좌우 화살표의 순서가 된다. `spot.y` 를 바꾸면 건물이 움직이는 게 아니라 탭 차례가 바뀐다.
- `width_ratio` 는 **건물 사이의 상대 크기**다(#319). 뜰 가로 대비 절대 폭이 아니다 — 실제 폭은 `FEATURE_WIDTH x (width_ratio / FEATURE_WIDTH_BASE)` 이고, `FEATURE_WIDTH_BASE`(0.21)가 1.0배 기준이다. 성소(0.24)는 기준보다 조금 크게, 창고(0.18)는 조금 작게 선다.
  높이는 그림 비율이 정하되, 지붕이 뜰 위로 넘치면 **가로세로를 함께 줄여** 맞춘다(`FEATURE_MAX_HEIGHT`).
- `spot.y` 가 작을수록 목록에서 **앞 차례**다. (한 채만 보이므로 앞뒤 겹침은 이제 없다.)

## 양식 (silhouette)

`art` 가 없을 때 **어떤 모양의 건물로 그릴지**를 정한다(#316). `HUT`(기본 맞배집) ·
`FORGE`(옆이 트인 작업장) · `SHRINE`(선돌과 상인방) · `STALL`(차양 친 좌판) ·
`GRANARY`(고상식 곳간).

화면이 `building_id` 로 분기하지 않는 이유가 여기 있다 — 건물을 하나 더할 때마다
화면 코드를 고쳐야 하기 때문이다. "무엇처럼 보이는가"는 이 리소스의 책임이다.

지정하지 않으면 `HUT` 이다. `art` 가 들어오면 양식은 쓰이지 않는다.

## 그림이 없을 때

`art` 가 비어 있으면 아이콘 + 이름표 플레이스홀더가 대신 선다(`icon_name`, `tint`). 그림이 들어오면 `art` 만 채우면 되고 화면 코드는 고치지 않는다.

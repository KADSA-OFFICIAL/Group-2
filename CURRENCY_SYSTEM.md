# 재화 시스템 (Currency System)

## 개요

게임의 기본 재화 시스템입니다. 플레이어는 여러 종류의 재화(Gold, Diamond 등)를 획득하고 소비할 수 있으며, 게임 종료 시에도 데이터가 저장됩니다.

## 주요 기능

- **다중 재화 타입 지원**: Gold, Diamond 등 확장 가능한 구조
- **재화 관리 API**: 추가(`add_currency`), 제거(`subtract_currency`), 조회(`get_balance`)
- **신호 시스템**: 재화 변경 시 signal 발생으로 UI 자동 업데이트
- **영구 저장**: 게임 저장 시 재화 데이터 포함
- **HUD 표시**: 화면에 실시간 재화 표시

## 사용 방법

### 1. 재화 추가
```gdscript
CurrencySystem.add_currency("gold", 100)
CurrencySystem.add_currency("diamond", 10)
```

### 2. 재화 제거
```gdscript
if CurrencySystem.subtract_currency("gold", 50):
	print("성공적으로 50 gold 소비")
else:
	print("gold 부족")
```

### 3. 재화 확인
```gdscript
var gold = CurrencySystem.get_balance("gold")
var all = CurrencySystem.get_all_currencies()  # {"gold": 100, "diamond": 10}
```

### 4. 충분한지 확인
```gdscript
if CurrencySystem.has_enough("gold", 50):
	# 50 gold 이상 보유
	pass
```

### 5. Signal 연결
```gdscript
CurrencySystem.currency_changed.connect(func(type, amount, balance):
	print("%s %d 변경됨. 현재잔액: %d" % [type, amount, balance])
)
```

## 파일 구조

- `autoload/CurrencySystem.gd` - 핵심 재화 시스템
- `ui/HUD.gd` - HUD 재화 표시 (업데이트됨)
- `autoload/SaveSystem.gd` - 저장/로드 통합 (업데이트됨)
- `autoload/EventBus.gd` - 재화 signal 추가 (업데이트됨)
- `autoload/GameManager.gd` - 게임 시작 시 로드 (업데이트됨)

## 저장 데이터 형식

게임 저장 파일에는 다음과 같이 저장됩니다:

```json
{
  "player_hp": 100,
  "player_position": {"x": 0, "y": 0},
  "stage": "Stage1_1",
  "playtime": 0.0,
  "currencies": {
    "gold": 100,
    "diamond": 50
  }
}
```

## 확장 방법

새로운 재화 타입을 추가하려면:

1. `CurrencySystem._ready()`의 `currencies` dictionary에 추가
2. `SaveSystem.get_default_save()`의 currencies에 추가
3. HUD에서 필요한 만큼 표시

## 테스트 씬

`scenes/CurrencyTestScene.gd`에 테스트용 버튼들이 포함되어 있습니다.

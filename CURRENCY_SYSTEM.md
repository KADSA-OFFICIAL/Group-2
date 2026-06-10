# 재화 시스템 (Currency System)

## 개요

게임의 기본 재화 시스템입니다. 플레이어는 장비 제작 재료(돌, 주석, 구리, 철광석, 석탄), 기본 통화(골드), 특수 재화(신앙석)를 획득하고 소비할 수 있으며, 게임 종료 시에도 데이터가 저장됩니다.

## 주요 기능

- **다중 재화 타입 지원**: 5가지 장비 제작 재료 + 기본 통화 + 특수 재화
- **재화 관리 API**: 추가(`add_currency`), 제거(`subtract_currency`), 조회(`get_balance`)
- **신호 시스템**: 재화 변경 시 signal 발생으로 UI 자동 업데이트
- **영구 저장**: 게임 저장 시 모든 재화 데이터 포함
- **HUD 표시**: 화면에 실시간으로 모든 재화 표시

## 지원하는 재화 타입

### 장비 제작 재료
| 영문명 | 한국명 | 설명 |
|--------|---------|------|
| stone | 돌 | 장비 제작 재료 |
| tin | 주석 | 장비 제작 재료 |
| copper | 구리 | 장비 제작 재료 |
| iron_ore | 철광석 | 장비 제작 재료 |
| coal | 석탄 | 장비 제작 재료 |

### 통화 및 특수 재화
| 영문명 | 한국명 | 설명 |
|--------|---------|------|
| gold | 골드 | 기본 통화 |
| faith_stone | 신앙석 | 신앙 관련 시스템 필요 |

## 사용 방법

### 1. 재화 추가
```gdscript
CurrencySystem.add_currency("stone", 100)
CurrencySystem.add_currency("gold", 50)
CurrencySystem.add_currency("faith_stone", 5)
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
var all = CurrencySystem.get_all_currencies()  # 모든 재화 반환
```

### 4. 충분한지 확인
```gdscript
if CurrencySystem.has_enough("stone", 50):
	# 50개 이상의 돌 보유
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
- `ui/HUD.gd` - HUD 재화 표시
- `autoload/SaveSystem.gd` - 저장/로드 통합
- `autoload/EventBus.gd` - 재화 signal
- `autoload/GameManager.gd` - 게임 시작 시 로드

## 저장 데이터 형식

게임 저장 파일에는 다음과 같이 저장됩니다:

```json
{
  "player_hp": 100,
  "player_position": {"x": 0, "y": 0},
  "stage": "Stage1_1",
  "playtime": 0.0,
  "currencies": {
    "stone": 100,
    "tin": 30,
    "copper": 25,
    "iron_ore": 15,
    "coal": 20,
    "gold": 100,
    "faith_stone": 5
  }
}
```

## 확장 방법

새로운 재화 타입을 추가하려면:

1. `CurrencySystem._ready()`의 `currencies` dictionary에 추가
2. `CurrencySystem.reset_currencies()`에 추가
3. `SaveSystem.get_default_save()`의 currencies에 추가
4. HUD의 `update_currency_display()`에 표시 추가

## 테스트 씬

`scenes/CurrencyTestScene.gd`에 테스트용 버튼들이 포함되어 있습니다.

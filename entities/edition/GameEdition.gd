class_name GameEdition
extends RefCounted

# 릴리스 판(일반판 / 검열판) 구분과 검열판 그림 경로 규칙의 단일 출처 (#586).
#
# 검열판(전체이용가)은 코드가 같고 **그림 일부만** 다르다. 검열판 그림은 `assets_censored/` 아래에
# `assets/` 와 같은 상대 경로·같은 파일 이름으로 둔다.
#   assets/sprites/characters/portraits/mina.png
#   assets_censored/sprites/characters/portraits/mina.png   <- 검열판에서 이것을 쓴다
# 짝이 없는 파일은 검열판에서도 원본을 쓴다 — 그림이 한 장씩 들어와도 된다.
#
# 판이 정해지는 곳:
#   - 내보낸 빌드: 내보내기 프리셋의 커스텀 기능 태그 `censored`.
#     내보낼 때 addons/edition_export 가 짝이 있는 원본을 검열판 그림으로 **바꿔 넣는다**
#     (원본 데이터가 검열판 pck 에 들어가지 않는다).
#   - 에디터·헤드리스: 실행 인수 `-- --censored` 로 미리 본다.
#
# 화면은 원화 경로를 직접 고르지 않고 PortraitSystem / UITheme 를 거친다. 둘이 여기에 묻는다.
# 사양·절차: docs/release-editions.md, 원화 프롬프트: docs/censored-art-prompts.md

const FEATURE := "censored"
const CMDLINE_FLAG := "--censored"

const ART_ROOT := "res://assets/"
const CENSORED_ROOT := "res://assets_censored/"

# null = 아직 판정 안 함. 테스트가 force_censored() 로 덮는다.
static var _censored: Variant = null


static func is_censored() -> bool:
	if _censored == null:
		_censored = OS.has_feature(FEATURE) or CMDLINE_FLAG in OS.get_cmdline_user_args()
	return _censored


# 테스트용. null 을 주면 다시 실행 환경으로 판정한다.
static func force_censored(value: Variant) -> void:
	_censored = value


# 원본 경로의 검열판 짝 경로. 파일이 있는지는 보지 않는다. `assets/` 밖이면 빈 문자열.
static func censored_path(path: String) -> String:
	if not path.begins_with(ART_ROOT):
		return ""
	return CENSORED_ROOT + path.trim_prefix(ART_ROOT)


static func has_censored(path: String) -> bool:
	var alt := censored_path(path)
	return not alt.is_empty() and ResourceLoader.exists(alt)


# 지금 판에서 실제로 읽을 경로. 일반판이거나 짝이 없으면 그대로 돌려준다.
static func resolve(path: String) -> String:
	if not is_censored() or not has_censored(path):
		return path
	return censored_path(path)


# 이미 불러온 텍스처(예: CharacterData.portrait)를 지금 판의 그림으로 바꾼다.
static func texture(source: Texture2D) -> Texture2D:
	if source == null or not is_censored():
		return source
	var path := resolve(source.resource_path)
	if path == source.resource_path:
		return source
	var replacement := load(path) as Texture2D
	return replacement if replacement != null else source

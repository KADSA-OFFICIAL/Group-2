@tool
extends EditorExportPlugin

# 검열판 내보내기 (#586).
#
# 프리셋의 커스텀 기능 태그에 `censored` 가 있으면, `assets/` 아래 파일 중 `assets_censored/` 에
# 같은 경로의 짝이 있는 것을 **그 짝의 내용으로 바꿔** 내보낸다. 원본 경로는 그대로라
# CharacterData.portrait 처럼 원본을 직접 참조하는 곳도 검열판 그림을 받는다.
# 원본 텍스처 데이터는 검열판 pck 에 들어가지 않는다.
#
# 일반판은 아무것도 바꾸지 않는다. assets_censored/ 를 일반판에서 빼려면 프리셋의 제외 필터를 쓴다
# (docs/release-editions.md).

var _censored := false
# 검열판 파일 지문. 내보내기 캐시는 원본 파일이 바뀔 때만 다시 만들어지므로, 검열판 그림만 바꿨을 때도
# 새로 굽도록 캐시 키에 넣는다.
var _fingerprint := 0
var _pair_count := 0


func _get_name() -> String:
	return "GameEdition"


func _begin_customize_resources(_platform: EditorExportPlatform, features: PackedStringArray) -> bool:
	_censored = GameEdition.FEATURE in features
	_fingerprint = 0
	_pair_count = 0
	if _censored:
		var files: PackedStringArray = []
		_collect(GameEdition.CENSORED_ROOT.trim_suffix("/"), files)
		files.sort()
		var stamps: PackedStringArray = []
		for file in files:
			stamps.append("%s:%d" % [file, FileAccess.get_modified_time(file)])
			if not file.ends_with(".import"):
				_pair_count += 1
		_fingerprint = hash(",".join(stamps))
	return _censored


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		if file.get_extension() != "md":
			out.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)


# 판마다 내보내기 캐시를 따로 쓴다 — 같으면 일반판 캐시가 검열판에 섞인다.
func _get_customization_configuration_hash() -> int:
	return hash([_censored, _fingerprint])


func _customize_resource(_resource: Resource, path: String) -> Resource:
	if not _censored or path.is_empty() or not GameEdition.has_censored(path):
		return null
	var replacement := load(GameEdition.censored_path(path))
	if replacement == null:
		push_warning("GameEdition: 검열판 그림을 불러오지 못해 원본을 내보낸다: " + path)
		return null
	# 원본 자리에 검열판 리소스를 저장한다. 가져온 텍스처는 검열판 쪽 가져오기 결과(.ctex)를
	# 가리킨 채 저장되므로 그림 데이터가 두 벌 들어가지 않는다. SpriteFrames 같은 것은 얕게
	# 복제한다 — 안의 텍스처는 검열판 경로를 가리킨 채 남는다.
	return replacement if replacement is CompressedTexture2D else replacement.duplicate()


func _end_customize_resources() -> void:
	if _censored:
		print("GameEdition: 검열판 내보내기 — assets_censored/ 파일 %d개로 원본을 바꿔 넣는다." % _pair_count)

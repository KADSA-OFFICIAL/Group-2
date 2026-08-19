extends SceneTree

## 두들 아이콘을 **공통 여백 규격**으로 맞춘다.
##
## 왜 필요한가 (실제 겪은 문제):
##   아이콘 31장은 512x512 캔버스에 내용이 최대 85% 로 들어가 있다(사방 7.5% 여백).
##   그런데 icon_craft.png 만 298x307 캔버스에 내용이 100% 로 꽉 차 있었다.
##   UI 는 아이콘을 정해진 크기 칸에 비율 유지로 그리므로, 여백이 없는 아이콘은
##   같은 칸에서 혼자 약 18% 크게 보인다. 아이콘 줄이 들쭉날쭉해지는 원인이다.
##
## 정규화 규칙:
##   - 정사각 캔버스. 한 변 = 내용의 긴 변 / CONTENT_RATIO.
##   - 내용을 캔버스 가운데에 둔다.
##   - **리샘플링하지 않는다.** 여백만 붙이므로 무손실이다.
##     (512 로 키우려면 확대가 필요한데, 아이콘이 화면에 그려지는 크기는 14~44px 라
##      원본 해상도를 키워서 얻는 것이 없다. 중요한 것은 캔버스 대비 내용 비율이다.)
##
## 사용법:
##   godot --headless --path . --script res://tools/normalize_icon.gd -- [--dry-run] <png경로...>
##
## 입력 파일을 덮어쓴다(--dry-run 이면 계산 결과만 출력한다).
##
## 참고: tools/normalize_portrait.gd(초상 정규화), ui/UITheme.gd(아이콘 이름 규칙)

# 내용이 캔버스에서 차지하는 비율. 기존 아이콘 31장의 실측값이다.
const CONTENT_RATIO := 0.85


func _initialize() -> void:
	await process_frame

	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("사용법: --script res://tools/normalize_icon.gd -- [--dry-run] <png경로...>")
		quit(2)
		return

	var dry_run := false
	var paths: Array[String] = []
	for a in args:
		if a == "--dry-run":
			dry_run = true
		else:
			paths.append(a)

	var failed := 0
	for p in paths:
		if not _normalize(p, dry_run):
			failed += 1

	if dry_run:
		print("\n(--dry-run: 파일을 쓰지 않았다)")
	quit(1 if failed > 0 else 0)


func _normalize(path: String, dry_run: bool) -> bool:
	var src := Image.load_from_file(path)
	if src == null:
		printerr("열 수 없습니다: ", path)
		return false

	src.convert(Image.FORMAT_RGBA8)

	var used := src.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		printerr("내용이 없습니다(전부 투명): ", path)
		return false

	var side := int(round(maxi(used.size.x, used.size.y) / CONTENT_RATIO))
	var dst := Vector2i(
		int(round((side - used.size.x) * 0.5)),
		int(round((side - used.size.y) * 0.5)))

	var before := 100.0 * maxi(used.size.x, used.size.y) / maxi(src.get_width(), src.get_height())
	print("%-24s %dx%d -> %dx%d, 내용 %dx%d, 점유율 %.0f%% -> %.0f%%" % [
		path.get_file(), src.get_width(), src.get_height(), side, side,
		used.size.x, used.size.y, before, CONTENT_RATIO * 100.0])

	if dry_run:
		return true

	var out := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(src, used, dst)

	var err := out.save_png(path)
	if err != OK:
		printerr("저장 실패(", err, "): ", path)
		return false
	return true

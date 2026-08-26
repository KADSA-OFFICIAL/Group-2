extends SceneTree

## 생성된 장면 그림을 **메타 화면 배경 규격**으로 맞춘다.
##
## 왜 필요한가 (실제 겪은 문제):
##   생성기 산출물은 1216x832(=1.46:1)로 나온다. 화면 뷰포트는 1280x720(=1.78:1)이고
##   배경은 비율 유지로 화면을 덮으므로, 그대로 넣으면 **세로 약 18%가 잘려 나간다.**
##   저장하고 VRAM 에 올려도 화면에 안 나오는 픽셀이다 — #272 에서 스토리 배경이 겪은
##   것과 같은 함정이다. 어디가 잘릴지도 그림마다 달라서 미리 볼 수 없다.
##
## 정규화 규칙:
##   - **먼저 자르고**(16:9 창을 원본에서 떼어낸다) 그 다음 줄인다. 순서를 바꾸면
##     버릴 픽셀까지 리샘플링하게 되고, 남는 부분의 화질만 손해다.
##   - 세로 창의 위치는 그림마다 다르다. 주제가 아래에 깔린 그림(좌판 위의 물건)은
##     위를, 주제가 가운데인 그림은 사방을 고르게 버려야 한다. 자동으로 판정할 수
##     없으므로 아래 ANCHORS 에 파일별로 적는다(0 = 위쪽을 남긴다, 1 = 아래쪽을 남긴다).
##   - **알파를 버린다.** 배경은 무엇 뒤에도 놓이지 않으므로 알파가 필요 없고,
##     RGBA 로 두면 용량만 늘어난다.
##
## 사용법:
##   godot --headless --path . --script res://tools/normalize_screen_backdrop.gd -- \
##       [--dry-run] <입력png>:<출력이름> ...
##
##   예: ... -- ~/Downloads/abc.png:craft
##   출력은 항상 res://assets/sprites/screens/<출력이름>.png 다. 입력은 건드리지 않는다.
##
## 참고: tools/normalize_portrait.gd(같은 방식의 초상 정규화),
##       assets/sprites/screens/README.md, ui/HUDKit.gd(make_backdrop)

# 목표 가로세로비. 뷰포트가 1280x720 이므로 16:9 다.
const TARGET_ASPECT := 16.0 / 9.0

# 저장할 가로 픽셀. 스토리 배경(#272)이 정한 "가로 960 안팎" 관례를 따른다.
# 배경은 UI 뒤에 스크림까지 덮고 깔리는 그림이라 원본 해상도를 지킬 이유가 없다.
const OUTPUT_WIDTH := 960

# 출력 폴더.
const OUTPUT_DIR := "res://assets/sprites/screens"

# 세로로 자를 창의 위치. 0.0 = 맨 위를 남긴다, 0.5 = 가운데, 1.0 = 맨 아래를 남긴다.
# 그림을 눈으로 보고 정한 값이다. 새 배경을 넣으면 여기에 한 줄 추가한다.
const ANCHORS := {
	# 대장간 실내. 위쪽 1/4이 서까래라 버려도 아깝지 않고, 모루와 바닥은 지켜야 한다.
	"craft": 0.60,
	# 사당. 지붕의 뼈 장식부터 아래 계단까지가 전부 주제라 고르게 버린다.
	"sanctum": 0.50,
	# 곳간. 건물이 가운데 서 있고 위는 하늘, 아래는 흙바닥이다.
	"storage": 0.50,
	# 시장 좌판. 주제(늘어놓은 물건)가 아래쪽에 깔려 있어 위를 더 버린다.
	"shop": 0.62,
}

# ANCHORS 에 없는 이름이 왔을 때 쓸 값.
const DEFAULT_ANCHOR := 0.5


func _initialize() -> void:
	await process_frame

	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("사용법: --script res://tools/normalize_screen_backdrop.gd -- [--dry-run] <입력png>:<출력이름> ...")
		quit(2)
		return

	var dry_run := false
	var jobs: Array[String] = []
	for a in args:
		if a == "--dry-run":
			dry_run = true
		else:
			jobs.append(a)

	if not dry_run:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var failed := 0
	for j in jobs:
		if not _normalize(j, dry_run):
			failed += 1

	if failed > 0:
		printerr("실패 %d 건." % failed)
	quit(1 if failed > 0 else 0)


func _normalize(job: String, dry_run: bool) -> bool:
	# "<경로>:<이름>" 으로 쪼갠다. 윈도우 경로에 드라이브 문자(C:)가 있으므로
	# 앞에서가 아니라 **뒤에서** 나눈다.
	var sep := job.rfind(":")
	if sep <= 1:
		printerr("형식이 <입력png>:<출력이름> 이 아닙니다: %s" % job)
		return false

	var src := job.substr(0, sep)
	var name := job.substr(sep + 1)

	var image := Image.load_from_file(src)
	if image == null:
		printerr("읽지 못했습니다: %s" % src)
		return false

	var w := image.get_width()
	var h := image.get_height()

	# 16:9 창을 떼어낸다. 원본이 목표보다 세로로 길면 위아래를, 가로로 길면 좌우를 버린다.
	var crop_w := w
	var crop_h := int(round(float(w) / TARGET_ASPECT))
	if crop_h > h:
		crop_h = h
		crop_w = int(round(float(h) * TARGET_ASPECT))

	var anchor: float = ANCHORS.get(name, DEFAULT_ANCHOR)
	var x := int(round(float(w - crop_w) * 0.5))
	var y := int(round(float(h - crop_h) * anchor))

	var out_w := OUTPUT_WIDTH
	var out_h := int(round(float(OUTPUT_WIDTH) / TARGET_ASPECT))

	print("%s: %dx%d -> 자르기 %dx%d @(%d,%d) anchor=%.2f -> %dx%d" % [
		name, w, h, crop_w, crop_h, x, y, anchor, out_w, out_h
	])
	if h - crop_h > 0:
		print("    버리는 세로: 위 %dpx / 아래 %dpx (원본의 %.1f%%)" % [
			y, h - crop_h - y, float(h - crop_h) / float(h) * 100.0
		])

	if dry_run:
		return true

	var cropped := image.get_region(Rect2i(x, y, crop_w, crop_h))
	cropped.resize(out_w, out_h, Image.INTERPOLATE_LANCZOS)

	# 배경은 무엇 뒤에도 놓이지 않는다. 알파를 들고 있을 이유가 없다.
	cropped.convert(Image.FORMAT_RGB8)

	var dst := "%s/%s.png" % [OUTPUT_DIR, name]
	var err := cropped.save_png(dst)
	if err != OK:
		printerr("쓰지 못했습니다(%d): %s" % [err, dst])
		return false

	print("    -> %s" % dst)
	return true

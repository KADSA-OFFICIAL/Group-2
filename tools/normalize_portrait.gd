extends SceneTree

## 저작된 초상 일러스트를 **공통 프레임**으로 정규화한다.
##
## 왜 필요한가 (실제 겪은 문제):
##   저작된 6장은 캔버스 크기(1378x2476)가 같은데 그 안의 인물 크기가 제각각이었다.
##   투명 여백을 뺀 인물의 실제 높이가 1216px ~ 1958px 로 **1.6배** 차이 났고,
##   캔버스 안에서 인물이 놓인 위치(위/아래)도 달랐다.
##   같은 칸에 넣으면 어떤 인물은 칸을 꽉 채우고 어떤 인물은 절반만 차지한다.
##   비율이 찌그러진 것이 아니라 **인물의 크기 기준선이 없는 것**이 문제였다.
##
## 정규화 규칙:
##   - 캔버스 가로세로비를 CANVAS_ASPECT 하나로 통일한다.
##     UI 는 칸에 맞춰 비율 유지로 그리므로, **캔버스 비율과 인물이 차지하는 비율**만
##     같으면 원본 해상도가 달라도 화면에서 같은 크기로 선다.
##   - 전신(FULL): 인물 높이 = 캔버스 높이의 FIGURE_HEIGHT_RATIO, 발바닥을 공통
##     기준선(BASELINE_RATIO)에 올린다. 가로는 가운데.
##   - 반신(BUST): 전신처럼 세울 수 없다(발이 없다). 인물 너비 = 캔버스 너비의
##     BUST_WIDTH_RATIO 로 두고 머리를 위에 붙인다. 아래 빈 자리는 UI 가 크롭해서 쓴다.
##   - **리샘플링하지 않는다.** 캔버스만 다시 잡고 정수 픽셀로 복사하므로 무손실이다.
##     (인물 높이를 물리적으로 맞추면 최대 1.6배 확대가 필요해 화질이 상한다.
##      화면에서의 크기는 캔버스 비율이 이미 보장하므로 확대할 이유가 없다.)
##
## 구도(전신/반신)는 자동으로 판정하지 않는다. 반신인지 전신인지는 그림을 봐야
## 알 수 있고, 경계상자 비율만으로 찍으면 팔을 벌린 전신을 반신으로 오판한다.
## 아래 BUST_FILES 에 반신 파일 이름을 적는다.
##
## 사용법:
##   godot --headless --path . --script res://tools/normalize_portrait.gd -- <png경로...>
##   godot --headless --path . --script res://tools/normalize_portrait.gd -- --dry-run <png경로...>
##
## 입력 파일을 **덮어쓴다**(--dry-run 이면 계산 결과만 출력한다).
## 초상 폴더는 PortraitSystem 이 통째로 훑어 목록을 만들기 때문에, 백업본을 그 폴더에
## 두면 게임 안에서 고를 수 있는 초상으로 뜬다. 백업은 반드시 폴더 **밖**에 둘 것.
##
## 원본이 아직 흰 배경 위의 불투명 PNG 라면 **먼저 tools/cutout_portrait.gd 로 누끼를
## 딴다.** 이 도구는 알파를 전제로 인물 경계상자를 잡으므로, 배경이 남아 있으면
## 캔버스 전체를 인물로 착각한다.
##
## 참고: tools/cutout_portrait.gd(누끼 — 이 도구보다 먼저 돌린다),
##       tools/normalize_walk_sheet.gd(같은 방식의 워크 시트 정규화), ui/HUDKit.gd

# 공통 캔버스 가로세로비(가로 / 세로). 저작본이 쓰던 1378/2476 = 0.5566 을 유지한다.
# 바꾸면 6장을 모두 다시 정규화해야 한다.
const CANVAS_ASPECT := 0.5566

# 전신 인물이 캔버스 세로에서 차지하는 비율.
const FIGURE_HEIGHT_RATIO := 0.92

# 발바닥에서 캔버스 아래끝까지의 여백 비율. 머리 위 여백은 나머지(=4%)가 된다.
const BASELINE_RATIO := 0.04

# 반신 인물이 캔버스 가로에서 차지하는 비율.
const BUST_WIDTH_RATIO := 0.92

# 머리 위 여백 비율(반신).
const BUST_TOP_RATIO := 0.04

# 반신(가슴 위) 구도인 파일. 여기 없으면 전신으로 본다.
const BUST_FILES := ["childhood_friend.png"]

# 이 알파 이상을 "내용"으로 본다.
#
# Image.get_used_rect() 를 그대로 쓰면 안 된다. 그 함수는 알파가 1 이라도 내용으로 세는데,
# 저작본에는 눈에 보이지 않는 얼룩 픽셀이 인물에서 멀찍이 떨어진 곳에 남아 있다
# (girl_green 은 왼쪽 위, childhood_friend 는 왼쪽에 있었다).
# 그 얼룩까지 경계상자에 넣으면 상자가 인물보다 넓어져서, 가운데 정렬했을 때
# **인물이 한쪽으로 치우친다.** 실제로 첫 정규화에서 그렇게 됐다.
# tools/normalize_walk_sheet.gd 도 같은 이유로 같은 임계값을 쓴다.
const ALPHA_MIN := 0.05


func _initialize() -> void:
	await process_frame

	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("사용법: --script res://tools/normalize_portrait.gd -- [--dry-run] <png경로...>")
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

	# 알파 없는 포맷이 섞여 들어오면 경계상자가 캔버스 전체가 된다.
	src.convert(Image.FORMAT_RGBA8)

	var used := _content_rect(src)
	if used.size.x <= 0 or used.size.y <= 0:
		printerr("내용이 없습니다(전부 투명): ", path)
		return false

	var is_bust: bool = BUST_FILES.has(path.get_file())
	var canvas := _canvas_size(used.size, is_bust)
	var dst_pos := _place(canvas, used.size, is_bust)

	var before_h := float(used.size.y) / float(src.get_height())
	var after_h := float(used.size.y) / float(canvas.y)
	print("%-24s %s  원본 %dx%d, 인물 %dx%d -> 캔버스 %dx%d, 인물 위치 %d,%d" % [
		path.get_file(), "반신" if is_bust else "전신",
		src.get_width(), src.get_height(), used.size.x, used.size.y,
		canvas.x, canvas.y, dst_pos.x, dst_pos.y,
	])
	print("%-24s   세로 점유율 %.0f%% -> %.0f%%" % ["", before_h * 100.0, after_h * 100.0])

	if dry_run:
		return true

	var out := Image.create_empty(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	# 확대/축소 없이 정수 픽셀 복사. 인물이 캔버스보다 크면 넘치는 만큼만 잘린다.
	out.blit_rect(src, used, dst_pos)

	var err := out.save_png(path)
	if err != OK:
		printerr("저장 실패(", err, "): ", path)
		return false
	return true


# ALPHA_MIN 이상인 픽셀의 경계상자. get_used_rect() 를 쓰지 않는 이유는 ALPHA_MIN 주석 참고.
func _content_rect(image: Image) -> Rect2i:
	var w := image.get_width()
	var h := image.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1

	for y in h:
		for x in w:
			if image.get_pixel(x, y).a < ALPHA_MIN:
				continue
			if x < min_x:
				min_x = x
			if x > max_x:
				max_x = x
			if y < min_y:
				min_y = y
			if y > max_y:
				max_y = y

	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


# 인물 경계상자를 담을 캔버스 크기. 인물을 키우지 않으려고 캔버스를 인물에 맞춘다.
func _canvas_size(figure: Vector2i, is_bust: bool) -> Vector2i:
	var height: float
	var width: float
	if is_bust:
		width = float(figure.x) / BUST_WIDTH_RATIO
		height = width / CANVAS_ASPECT
	else:
		height = float(figure.y) / FIGURE_HEIGHT_RATIO
		width = height * CANVAS_ASPECT
		# 가로로 넓은 인물(팔을 벌린 포즈, 크게 퍼진 머리)은 캔버스를 **넓히기만** 한다.
		#
		# 예전에는 여기서 세로도 함께 늘려 캔버스 비율을 CANVAS_ASPECT 로 고정했다.
		# 그러면 인물의 세로 점유율이 FIGURE_HEIGHT_RATIO 아래로 떨어지고, 화면은
		# 칸에 비율 유지로 그리므로 **그 인물만 작게 선다.** 아린이 76%, 하랑이 78%
		# 였고 나머지가 92% 라, 아린만 눈에 띄게 작았다(#369).
		#
		# 세로 점유율을 지키는 쪽을 택한다. 캔버스 비율이 인물마다 조금씩 달라지지만,
		# 화면의 칸이 전부 이보다 넓어서(가장 좁은 곳이 230x330 = 0.697) 높이 기준으로
		# 맞춰지고, 결국 **모든 인물이 같은 높이로 선다** — 원래 이 규약이 노리던 것이다.
		var min_width := float(figure.x) / FIGURE_HEIGHT_RATIO
		if min_width > width:
			width = min_width
	return Vector2i(int(round(width)), int(round(height)))


# 캔버스 안에서 인물을 놓을 좌상단 좌표.
func _place(canvas: Vector2i, figure: Vector2i, is_bust: bool) -> Vector2i:
	var x := int(round((canvas.x - figure.x) * 0.5))
	if is_bust:
		return Vector2i(x, int(round(canvas.y * BUST_TOP_RATIO)))
	# 발바닥을 공통 기준선에 올린다.
	return Vector2i(x, canvas.y - int(round(canvas.y * BASELINE_RATIO)) - figure.y)

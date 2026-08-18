extends SceneTree

## 생성기가 뽑아준 4방향 워크 시트를 게임에서 쓸 수 있는 **균일 격자 시트**로 정규화한다.
##
## 왜 필요한가 (실제 겪은 문제):
##   1. 셀 폭이 정수로 나뉘지 않는다. 균등 격자로 자르면 폭이 넓은 행(뒷모습 등)이
##      옆 프레임과 겹쳐 잘려 나간다.
##   2. 프레임마다 캐릭터가 셀 안에서 한쪽으로 흘러간다(측정값 약 29px/프레임).
##      그대로 재생하면 제자리걸음이 아니라 옆으로 미끄러진다.
##
## 정규화 규칙:
##   - 가로: 프레임마다 내용 경계상자의 중심을 셀 중심에 맞춘다.
##     한 행 안에서 경계상자 폭이 같으면 이 이동은 순수 평행이동 제거이므로 무손실이다.
##
## 잘림 판정: **내부 절단선 위에 내용 픽셀이 있는지**로 본다(있으면 그만큼 잘려 나갔다).
## 프레임 폭 차이는 잘림의 근거가 아니다 — 정상적인 포즈 차이로도 몇 px 달라진다.
##   - 세로: 행 단위로 맞춘다. 행 안 프레임끼리의 높이차(발 들기)는 보존하고,
##     행의 바닥선만 모든 행이 공유하는 기준선에 맞춘다.
##   - 리샘플링하지 않는다. 정수 픽셀 복사만 해서 원본 해상도를 유지한다.
##
## 행 순서는 화면 방향 기준 하/좌/상/우로 가정한다(Godot의 +y가 아래).
## 다른 순서의 시트를 받으면 이 가정을 먼저 확인할 것.
##
## 사용법:
##   godot --headless --path . --script res://tools/normalize_walk_sheet.gd -- <입력png> <출력res경로>
##
## 출력: 정규화한 PNG + 셀 크기/발 기준선 등 저작에 필요한 수치를 콘솔에 출력한다.
## 그 수치를 CharacterData/EnemyData의 walk_sprite_scale / walk_sprite_offset에 넣는다.

const ROWS := 4
const COLS := 3

# 셀 여백(px). 스프라이트가 셀 경계에 딱 붙지 않게 한다.
const PAD_X := 8
const PAD_TOP := 8
const PAD_BOTTOM := 8

# 이 알파 이상을 "내용"으로 본다.
const ALPHA_MIN := 0.05

const ROW_NAMES := ["down", "left", "up", "right"]


func _initialize() -> void:
	await process_frame

	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("사용법: --script res://tools/normalize_walk_sheet.gd -- <입력png> <출력res경로>")
		quit(2)
		return

	var src_path: String = args[0]
	var dst_path: String = args[1]

	var src := Image.load_from_file(src_path)
	if src == null:
		print("입력 이미지를 열 수 없습니다: ", src_path)
		quit(2)
		return
	src.convert(Image.FORMAT_RGBA8)
	print("입력: %s  (%dx%d)" % [src_path, src.get_width(), src.get_height()])

	# --- 1. 행 구간을 찾는다 (빈 줄로 갈라진 덩어리) ---
	var row_bands := _bands(_occupancy(src, true))
	if row_bands.size() != ROWS:
		print("경고: 행 덩어리가 %d개다(%d개 기대). 시트 구조를 확인할 것: %s" % [row_bands.size(), ROWS, str(row_bands)])
		if row_bands.size() < ROWS:
			quit(2)
			return

	# --- 2. 행마다 열 3개로 가른다 ---
	var boxes := []
	for r in range(ROWS):
		var y0: int = row_bands[r][0]
		var y1: int = row_bands[r][1]
		var cuts := _column_cuts(src, y0, y1)
		var row := []
		for c in range(COLS):
			row.append(_content_box(src, Rect2i(cuts[c], y0, cuts[c + 1] - cuts[c], y1 - y0 + 1)))
		boxes.append(row)
		print("  행 %d (%s): y %d..%d, 열 절단 %s" % [r, ROW_NAMES[r], y0, y1, str(cuts)])

		# 잘림 판정: **내부** 절단선 위에 내용 픽셀이 있으면 내용을 가로질러 자른 것이다.
		# 양 끝 절단선은 정의상 내용 경계와 같으므로 세지 않는다.
		# (프레임 폭 차이는 잘림의 근거가 아니다 — 발이나 머리카락이 한 프레임에서
		#  더 나오는 정상적인 포즈 차이로도 몇 px 달라진다.)
		for k in range(1, COLS):
			var cut_x: int = cuts[k]
			var bleed := 0
			for y in range(y0, y1 + 1):
				if src.get_pixel(cut_x, y).a >= ALPHA_MIN:
					bleed += 1
			if bleed > 0:
				print("    경고: 절단선 x=%d 위에 내용 %dpx — 프레임이 겹쳐 그만큼 잘려 나간다" % [cut_x, bleed])

	# --- 3. 셀 크기 결정 ---
	var max_w := 0
	var max_h := 0
	var row_bottom := []
	for r in range(ROWS):
		var rb := -1
		var widths := []
		for c in range(COLS):
			rb = maxi(rb, boxes[r][c].position.y + boxes[r][c].size.y - 1)
			widths.append(boxes[r][c].size.x)
		row_bottom.append(rb)
		# 폭이 완전히 같으면 가로 중심 정렬이 순수 평행이동 제거이므로 무손실이다.
		# 다르면 포즈 차이라는 뜻이고, 중심 정렬이 그 차이의 절반만큼 프레임을 밀어
		# 원본에 없던 미세한 이동이 생긴다(보통 몇 px이라 무해하다).
		# 실제 잘림 여부는 위의 절단선 검사가 판정한다.
		var wmin: int = widths.min()
		var wmax: int = widths.max()
		if wmax - wmin > 0:
			print("    참고: 행 %d(%s) 프레임 폭 %s — 포즈 차이. 중심 정렬로 최대 %.1fpx 밀림" % [r, ROW_NAMES[r], str(widths), float(wmax - wmin) / 2.0])
		for c in range(COLS):
			max_w = maxi(max_w, boxes[r][c].size.x)
			max_h = maxi(max_h, rb - boxes[r][c].position.y + 1)

	var cell_w: int = int(ceil(float(max_w + PAD_X * 2) / 4.0)) * 4
	var cell_h: int = int(ceil(float(max_h + PAD_TOP + PAD_BOTTOM) / 4.0)) * 4
	var baseline := cell_h - PAD_BOTTOM - 1

	# --- 4. 새 시트로 복사 ---
	var dst := Image.create_empty(cell_w * COLS, cell_h * ROWS, false, Image.FORMAT_RGBA8)
	dst.fill(Color(0, 0, 0, 0))
	for r in range(ROWS):
		for c in range(COLS):
			var b: Rect2i = boxes[r][c]
			var dx: int = c * cell_w + int(round((float(cell_w) - float(b.size.x)) / 2.0))
			var lift: int = row_bottom[r] - (b.position.y + b.size.y - 1)
			var dy: int = r * cell_h + (baseline - lift) - (b.size.y - 1)
			dst.blit_rect(src, b, Vector2i(dx, dy))

	var err := dst.save_png(ProjectSettings.globalize_path(dst_path))
	if err != OK:
		print("저장 실패(", err, "): ", dst_path)
		quit(2)
		return

	# --- 5. 저작에 필요한 수치 출력 ---
	var content_h := 0
	for r in range(ROWS):
		for c in range(COLS):
			content_h = maxi(content_h, boxes[r][c].size.y)

	print("")
	print("출력: %s" % dst_path)
	print("  셀 %dx%d, 시트 %dx%d" % [cell_w, cell_h, cell_w * COLS, cell_h * ROWS])
	print("  셀 안 발 기준선 y=%d (셀 중심 기준 +%d)" % [baseline, baseline - cell_h / 2])
	print("  가장 큰 내용 높이 %dpx" % content_h)
	print("")
	print("  SpriteFrames 영역(region) — 행 순서 하/좌/상/우:")
	for r in range(ROWS):
		var line := "    %-5s: " % ROW_NAMES[r]
		for c in range(COLS):
			line += "Rect2(%d, %d, %d, %d)  " % [c * cell_w, r * cell_h, cell_w, cell_h]
		print(line)
	print("")
	print("  walk_sprite_offset.y 구하는 법:")
	print("    발을 노드 원점에서 아래로 F px에 두려면  offset.y = F / scale - %d" % (baseline - cell_h / 2))
	print("    (충돌 캡슐 높이 H를 원점 중심으로 두었다면 F = H / 2)")
	print("  화면 키 = %d x scale  (배율 0.25면 %.0fpx)" % [content_h, float(content_h) * 0.25])

	quit(0)


# 축 방향 점유 여부 배열. vertical=true면 y축(행), false면 x축(열).
func _occupancy(img: Image, vertical: bool) -> Array:
	var n := img.get_height() if vertical else img.get_width()
	var m := img.get_width() if vertical else img.get_height()
	var out := []
	out.resize(n)
	for i in range(n):
		var found := false
		for j in range(m):
			var a := img.get_pixel(j, i).a if vertical else img.get_pixel(i, j).a
			if a >= ALPHA_MIN:
				found = true
				break
		out[i] = found
	return out


# 한 행(y0..y1) 안에서 프레임 3개를 가르는 절단선 4개를 반환한다.
# 빈 열로 깔끔히 갈라지면 그 경계를 쓰고, 프레임이 붙어 있으면
# 기대 위치(1/3, 2/3) 근처에서 열 밀도가 가장 낮은 곳을 찾아 자른다.
func _column_cuts(img: Image, y0: int, y1: int) -> Array:
	var w := img.get_width()
	var dens := []
	dens.resize(w)
	for x in range(w):
		var n := 0
		for y in range(y0, y1 + 1):
			if img.get_pixel(x, y).a >= ALPHA_MIN:
				n += 1
		dens[x] = n

	var occ := []
	occ.resize(w)
	for x in range(w):
		occ[x] = dens[x] > 0
	var bands := _bands(occ)

	# 빈 열로 3개가 깔끔히 갈라진 경우
	if bands.size() == COLS:
		return [
			bands[0][0],
			int((float(bands[0][1]) + float(bands[1][0])) / 2.0),
			int((float(bands[1][1]) + float(bands[2][0])) / 2.0),
			bands[2][1] + 1,
		]

	# 붙어 있는 경우: 전체 내용 구간을 3등분한 기대 위치 근처에서 최소 밀도를 찾는다
	var lo: int = bands[0][0]
	var hi: int = bands[bands.size() - 1][1]
	var span := float(hi - lo + 1)
	var cuts := [lo]
	for k in range(1, COLS):
		var expect := lo + int(span * float(k) / float(COLS))
		# 기대 위치 ±span/9 안에서 가장 밀도가 낮은 열
		var radius := int(span / 9.0)
		var best := expect
		var best_d := 1 << 30
		for x in range(maxi(lo, expect - radius), mini(hi, expect + radius) + 1):
			if dens[x] < best_d:
				best_d = dens[x]
				best = x
		cuts.append(best)
	cuts.append(hi + 1)
	return cuts


func _bands(flags: Array) -> Array:
	var out := []
	var start := -1
	for i in range(flags.size()):
		if flags[i] and start < 0:
			start = i
		elif not flags[i] and start >= 0:
			out.append([start, i - 1])
			start = -1
	if start >= 0:
		out.append([start, flags.size() - 1])
	return out


func _content_box(img: Image, win: Rect2i) -> Rect2i:
	var minx := 1 << 30
	var maxx := -1
	var miny := 1 << 30
	var maxy := -1
	for y in range(win.position.y, win.position.y + win.size.y):
		for x in range(win.position.x, win.position.x + win.size.x):
			if img.get_pixel(x, y).a >= ALPHA_MIN:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	if maxx < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)

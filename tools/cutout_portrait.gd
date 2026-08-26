extends SceneTree

## 단색 배경 위에 그려진 원본에서 **누끼를 딴다**(#292).
##
## 왜 필요한가 (실제 겪은 문제):
##   생성기 산출물은 흰 배경 위에 인물이 얹힌 불투명 PNG 로 나온다. 이것을 그냥
##   "흰색을 투명으로" 처리하면 두 가지가 동시에 망가진다.
##
##     1) **인물 안의 흰색까지 뚫린다.** 설아의 흰 드레스, 태희의 흰 양말,
##        미나의 흰 블라우스가 구멍이 된다. 이 로스터는 흰옷이 많아서 반드시 터진다.
##     2) **가장자리에 흰 후광이 남는다.** 안티에일리어싱된 경계 픽셀은 흰 배경과
##        섞인 색이라, 알파만 깎고 RGB 를 그대로 두면 어두운 면 위에서 흰 실선이 된다.
##
## 그래서 두 가지를 따로 다룬다:
##
##   배경 판정은 **색이 아니라 연결성**으로 한다.
##     테두리에서 시작해 배경색과 비슷한 픽셀만 타고 번져 나간다(flood fill).
##     인물 안쪽의 흰색은 테두리와 이어져 있지 않으므로 살아남는다.
##
##   경계는 **되돌려서** 만든다.
##     경계 픽셀은 C = a * F + (1 - a) * BG 로 만들어져 있다. 옆의 확실한 인물
##     픽셀에서 F 를 얻으면 a 를 풀 수 있고, 색은 F 로 바꿔 넣는다.
##     알파만 깎는 것과 달리 배경색 성분이 실제로 사라진다.
##
##     a 는 배경색과 가장 크게 차이 나는 채널 하나로 푼다. 세 채널을 평균 내면
##     인물 색이 배경과 비슷한 채널이 분모를 0 으로 끌고 가서 값이 튄다.
##
## 사용법:
##   godot --headless --path . --script res://tools/cutout_portrait.gd -- \
##       [--dry-run] <입력png>:<출력png> ...
##
## 입력은 건드리지 않는다. 출력 경로를 따로 받는다 — 원본은 되돌릴 수 없으므로
## 덮어쓰지 않는다(normalize_portrait.gd 와 다른 점이다).
##
## 이 도구 다음에 tools/normalize_portrait.gd 를 돌려 캔버스 규격을 맞춘다.
##
## 참고: tools/normalize_portrait.gd, assets/sprites/characters/README.md

# 배경색으로 볼 색 차이(채널당 0~255). 넉넉하면 인물의 밝은 부분까지 먹고,
# 빡빡하면 배경에 남은 옅은 얼룩을 놓친다.
const BG_TOLERANCE: int = 10

# 경계로 볼 띠의 두께(px). 배경에서 이만큼 안쪽까지를 "되돌릴 대상"으로 본다.
# 안티에일리어싱은 보통 1~2px 라 2 면 충분하고, 키우면 인물을 깎아 먹는다.
const EDGE_BAND: int = 2

# 경계 픽셀의 인물 색 F 를 찾을 때 볼 반경(px).
const FG_PROBE_RADIUS: int = 3

# 이 값보다 채널 대비가 작으면 a 를 못 푼다(인물 색이 배경과 거의 같다).
# 그럴 때는 되돌리지 않고 불투명으로 남긴다 — 잘못 푸느니 그대로 두는 편이 낫다.
const MIN_CHANNEL_CONTRAST: float = 12.0 / 255.0

# 이 알파 미만은 지운다. 되돌려도 색이 불안정한 구간이다.
const ERASE_BELOW: float = 3.0 / 255.0

# 이웃 오프셋. 리터럴을 그 자리에 두면 타입 추론이 안 된다.
const NEIGHBORS_4: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1),
]

# 픽셀 분류
const BACKGROUND := 0
const UNKNOWN := 1
const FOREGROUND := 2


func _initialize() -> void:
	await process_frame

	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("사용법: --script res://tools/cutout_portrait.gd -- [--dry-run] <입력png> <출력png> ...")
		quit(2)
		return

	var dry_run := false
	var jobs: Array[String] = []
	for a in args:
		if a == "--dry-run":
			dry_run = true
		else:
			jobs.append(a)

	if jobs.size() % 2 != 0:
		printerr("입력과 출력을 짝으로 적어야 합니다. 인자 %d 개는 홀수입니다." % jobs.size())
		quit(2)
		return

	var failed := 0
	for i in range(0, jobs.size(), 2):
		if not _cutout(jobs[i], jobs[i + 1], dry_run):
			failed += 1

	if failed > 0:
		printerr("실패 %d 건." % failed)
	quit(1 if failed > 0 else 0)


func _cutout(src: String, dst: String, dry_run: bool) -> bool:
	var image := Image.load_from_file(src)
	if image == null:
		printerr("읽지 못했습니다: %s" % src)
		return false
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var w := image.get_width()
	var h := image.get_height()
	var name := src.get_file()

	# ===== 1. 배경색을 네 모서리에서 잰다 =====
	var bg := _corner_color(image)
	print("%s: %dx%d  배경색 rgb(%d,%d,%d)" % [
		name, w, h,
		int(round(bg.r * 255.0)), int(round(bg.g * 255.0)), int(round(bg.b * 255.0)),
	])

	# ===== 2. 테두리에서 flood fill 해서 진짜 배경만 고른다 =====
	var kind := PackedByteArray()
	kind.resize(w * h)
	kind.fill(FOREGROUND)

	var queue: Array[int] = []
	var tol := float(BG_TOLERANCE) / 255.0

	for x in w:
		_seed(image, kind, queue, x, 0, w, bg, tol)
		_seed(image, kind, queue, x, h - 1, w, bg, tol)
	for y in h:
		_seed(image, kind, queue, 0, y, w, bg, tol)
		_seed(image, kind, queue, w - 1, y, w, bg, tol)

	var head := 0
	while head < queue.size():
		var idx := queue[head]
		head += 1
		var cx := idx % w
		var cy := idx / w
		for d in NEIGHBORS_4:
			var nx := cx + d.x
			var ny := cy + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			_seed(image, kind, queue, nx, ny, w, bg, tol)

	var bg_count := queue.size()

	# ===== 3. 배경에 붙은 안쪽 EDGE_BAND 픽셀을 경계(UNKNOWN)로 승격 =====
	# 이 띠 안에서만 색을 되돌린다. 나머지 인물은 원본 그대로 둔다.
	var band: Array[int] = []
	for step in EDGE_BAND:
		var wave: Array[int] = []
		var source: Array[int] = queue if step == 0 else band
		for idx in source:
			var cx := idx % w
			var cy := idx / w
			for d in NEIGHBORS_8:
				var nx := cx + d.x
				var ny := cy + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var ni := ny * w + nx
				if kind[ni] != FOREGROUND:
					continue
				kind[ni] = UNKNOWN
				wave.append(ni)
		band.append_array(wave)
		if step == 0:
			band = wave.duplicate()

	# ===== 4. 배경은 지우고, 경계는 되돌린다 =====
	for idx in queue:
		image.set_pixel(idx % w, idx / w, Color(0.0, 0.0, 0.0, 0.0))

	var recovered := 0
	var erased := 0
	var kept := 0

	for idx in band:
		var x := idx % w
		var y := idx / w
		var observed := image.get_pixel(x, y)

		var reference: Variant = _foreground_reference(image, kind, w, h, x, y)
		if reference == null:
			# 주변에 확실한 인물 픽셀이 없다 — 배경에 떠 있는 티끌이다.
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			erased += 1
			continue

		var fg: Color = reference

		# 배경과 가장 크게 차이 나는 채널로 a 를 푼다.
		var denominator := 0.0
		var numerator := 0.0
		var channels := [
			[fg.r - bg.r, observed.r - bg.r],
			[fg.g - bg.g, observed.g - bg.g],
			[fg.b - bg.b, observed.b - bg.b],
		]
		for c in channels:
			if absf(c[0]) > absf(denominator):
				denominator = c[0]
				numerator = c[1]

		if absf(denominator) < MIN_CHANNEL_CONTRAST:
			# 인물 색이 배경과 거의 같다. 잘못 푸느니 불투명으로 남긴다.
			kept += 1
			continue

		var alpha := clampf(numerator / denominator, 0.0, 1.0)
		if alpha < ERASE_BELOW:
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			erased += 1
			continue

		image.set_pixel(x, y, Color(fg.r, fg.g, fg.b, alpha))
		recovered += 1

	print("    배경 %d px 지움 / 경계 %d px 되돌림 / 티끌 %d px 지움 / 대비부족 %d px 유지" % [
		bg_count, recovered, erased, kept
	])

	if dry_run:
		return true

	var err := image.save_png(dst)
	if err != OK:
		printerr("쓰지 못했습니다(%d): %s" % [err, dst])
		return false
	print("    -> %s" % dst)
	return true


# 아직 배경으로 안 찍힌 픽셀이 배경색과 비슷하면 배경으로 찍고 큐에 넣는다.
func _seed(image: Image, kind: PackedByteArray, queue: Array[int], x: int, y: int,
		w: int, bg: Color, tol: float) -> void:
	var idx := y * w + x
	if kind[idx] == BACKGROUND:
		return
	var px := image.get_pixel(x, y)
	if absf(px.r - bg.r) > tol or absf(px.g - bg.g) > tol or absf(px.b - bg.b) > tol:
		return
	kind[idx] = BACKGROUND
	queue.append(idx)


# 경계 픽셀이 되찾아야 할 인물 색. 반경 안의 확실한 인물 픽셀 평균이다.
func _foreground_reference(image: Image, kind: PackedByteArray, w: int, h: int,
		x: int, y: int) -> Variant:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for dy in range(-FG_PROBE_RADIUS, FG_PROBE_RADIUS + 1):
		var yy := y + dy
		if yy < 0 or yy >= h:
			continue
		for dx in range(-FG_PROBE_RADIUS, FG_PROBE_RADIUS + 1):
			var xx := x + dx
			if xx < 0 or xx >= w:
				continue
			if kind[yy * w + xx] != FOREGROUND:
				continue
			var px := image.get_pixel(xx, yy)
			r += px.r
			g += px.g
			b += px.b
			n += 1
	if n == 0:
		return null
	return Color(r / n, g / n, b / n, 1.0)


# 네 모서리의 평균색. 배경색을 흰색이라고 박아 두지 않는 이유는 파일 위 주석에 있다.
func _corner_color(image: Image) -> Color:
	var w := image.get_width()
	var h := image.get_height()
	var samples := [
		image.get_pixel(0, 0), image.get_pixel(w - 1, 0),
		image.get_pixel(0, h - 1), image.get_pixel(w - 1, h - 1),
	]
	var r := 0.0
	var g := 0.0
	var b := 0.0
	for s in samples:
		r += s.r
		g += s.g
		b += s.b
	return Color(r / samples.size(), g / samples.size(), b / samples.size(), 1.0)

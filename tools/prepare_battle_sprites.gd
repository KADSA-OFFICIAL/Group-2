extends SceneTree

# Mechanical preparation of generated artwork: chroma removal, sizing and palette.
# This script does not draw characters or weapons.
func prepare(job: Dictionary) -> Image:
	var src := Image.load_from_file(ProjectSettings.globalize_path(job.source))
	src.convert(Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x,y)
			if job.get("chroma", true) and minf(c.r,c.b)-c.g > 0.24:
				src.set_pixel(x,y,Color.TRANSPARENT)
	var bounds := src.get_used_rect()
	var crop := src.get_region(bounds)
	var w := int(job.width)
	var h := int(job.height)
	var factor := minf((w-2.0*ceil(w*0.05))/crop.get_width(),(h-ceil(h*0.05))/crop.get_height())
	crop.resize(roundi(crop.get_width()*factor),roundi(crop.get_height()*factor),Image.INTERPOLATE_LANCZOS)
	var palette: Array[Color] = []
	for value in job.palette: palette.append(Color(value))
	var region: Array = job.accent_region
	var accent := Rect2(region[0]*src.get_width(),region[1]*src.get_height(),region[2]*src.get_width(),region[3]*src.get_height())
	for y in crop.get_height():
		for x in crop.get_width():
			var c := crop.get_pixel(x,y)
			if c.a < 0.08:
				crop.set_pixel(x,y,Color.TRANSPARENT)
				continue
			var best := 0
			var distance := INF
			for i in palette.size():
				# Quantize the existing elemental ornament separately from near-white
				# hair/skin; this changes no shapes and creates no new painted content.
				if i == 3 and not accent.has_point(Vector2(bounds.position)+Vector2(x,y)/factor): continue
				var p := palette[i]
				var d := pow(c.r-p.r,2)*0.30+pow(c.g-p.g,2)*0.59+pow(c.b-p.b,2)*0.11
				if d < distance:
					distance = d
					best = i
			var color := palette[best]
			color.a = c.a
			crop.set_pixel(x,y,color)
	var out := Image.create_empty(w,h,false,Image.FORMAT_RGBA8)
	# Re-crop after removing subvisible edge pixels, ensuring the sole meets y=h-1.
	crop = crop.get_region(crop.get_used_rect())
	out.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((w-crop.get_width())/2,h-crop.get_height()))
	return out

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Usage: --script tools/prepare_battle_sprites.gd -- <manifest.json> [review_directory]")
		quit(1)
		return
	var jobs = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not jobs is Array or jobs.is_empty():
		push_error("Manifest must contain sprite jobs")
		quit(1)
		return
	var sheet := Image.create_empty(768,560,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("0C111C"))
	var silhouette := Image.create_empty(768,560,false,Image.FORMAT_RGBA8)
	silhouette.fill(Color("E8E8E8"))
	for i in jobs.size():
		var job: Dictionary = jobs[i]
		var out := prepare(job)
		DirAccess.make_dir_recursive_absolute(job.output.get_base_dir())
		out.save_png(job.output)
		var small: Image = out.duplicate()
		small.resize(out.get_width()/4,out.get_height()/4,Image.INTERPOLATE_LANCZOS)
		var pos := Vector2i((128-small.get_width())/2+(i%6)*128,36+(i/6)*260)
		sheet.blend_rect(small,Rect2i(Vector2i.ZERO,small.get_size()),pos)
		var big: Image = small.duplicate()
		big.resize(big.get_width()*2,big.get_height()*2,Image.INTERPOLATE_NEAREST)
		var big_pos := Vector2i((128-big.get_width())/2+(i%6)*128,pos.y+88)
		sheet.blend_rect(big,Rect2i(Vector2i.ZERO,big.get_size()),big_pos)
		for y in big.get_height():
			for x in big.get_width():
				big.set_pixel(x,y,Color(0,0,0,big.get_pixel(x,y).a))
		silhouette.blend_rect(big,Rect2i(Vector2i.ZERO,big.get_size()),Vector2i(big_pos.x,pos.y))
		print(job.id, " ", out.get_size(), " bounds=",out.get_used_rect())
	if args.size()>1:
		DirAccess.make_dir_recursive_absolute(args[1])
		sheet.save_png(args[1]+"/battle-contact-sheet.png")
		silhouette.save_png(args[1]+"/battle-silhouettes.png")
	quit()

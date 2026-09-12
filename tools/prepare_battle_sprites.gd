extends SceneTree

# Production processing only: remove the keyed backdrop and resize, retaining
# the generated skin, eyes, clothing and line colors without palette quantization.
func prepare(job: Dictionary) -> Image:
	var src := Image.load_from_file(ProjectSettings.globalize_path(job.source))
	src.convert(Image.FORMAT_RGBA8)
	var original: Image = src.duplicate()
	if job.get("chroma",true):
		for y in src.get_height():
			for x in src.get_width():
				var c := original.get_pixel(x,y)
				var excess := minf(c.r,c.b)-c.g
				if excess <= 0.24: continue
				var result := Color.TRANSPARENT
				if excess < 0.92:
					var found := false
					for radius in range(1,5):
						for dy in range(-radius,radius+1):
							for dx in range(-radius,radius+1):
								var p := Vector2i(x+dx,y+dy)
								if not Rect2i(Vector2i.ZERO,src.get_size()).has_point(p): continue
								var neighbor := original.get_pixelv(p)
								var e := minf(neighbor.r,neighbor.b)-neighbor.g
								if e < 0.20:
									result = neighbor
									result.a = clampf(1-(excess-e)/(1-e),0,1)
									found = true
									break
							if found: break
						if found: break
				src.set_pixel(x,y,result)
	if job.has("crop"):
		var r: Array = job.crop
		var rect := Rect2i(roundi(r[0]*src.get_width()),roundi(r[1]*src.get_height()),roundi(r[2]*src.get_width()),roundi(r[3]*src.get_height()))
		src = src.get_region(rect.intersection(Rect2i(Vector2i.ZERO,src.get_size())))
	if job.get("preserve_canvas",false):
		src.resize(int(job.width),int(job.height),Image.INTERPOLATE_LANCZOS)
		return src
	var crop := src.get_region(src.get_used_rect())
	var w := int(job.width)
	var h := int(job.height)
	var margin := float(job.get("margin",0.05))
	var foot := bool(job.get("foot",true))
	var factor := minf((w-2*ceil(w*margin))/crop.get_width(),(h-ceil(h*margin)*(1 if foot else 2))/crop.get_height())
	crop.resize(roundi(crop.get_width()*factor),roundi(crop.get_height()*factor),Image.INTERPOLATE_LANCZOS)
	for y in crop.get_height():
		for x in crop.get_width():
			if crop.get_pixel(x,y).a < 0.03: crop.set_pixel(x,y,Color.TRANSPARENT)
	crop = crop.get_region(crop.get_used_rect())
	var out := Image.create_empty(w,h,false,Image.FORMAT_RGBA8)
	out.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((w-crop.get_width())/2,(h-crop.get_height()) if foot else (h-crop.get_height())/2))
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


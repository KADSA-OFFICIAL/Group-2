extends "res://tools/prepare_battle_sprites.gd"

# Generated frames share a fixed camera/canvas. Never fit each silhouette to
# full height: that would enlarge kneeling/death frames and move planted feet.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Expected animation export manifest")
		quit(1)
		return
	var jobs: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var only_unit := ""
	for argument in args:
		if argument.begins_with("--unit="): only_unit = argument.trim_prefix("--unit=")
	for job in jobs:
		if not only_unit.is_empty() and job.unit != only_unit: continue
		var canvas := Vector2i(int(job.width), int(job.height))
		var source := Image.load_from_file(ProjectSettings.globalize_path(job.source))
		var factor := minf(float(canvas.x)/source.get_width(), float(canvas.y)/source.get_height())
		job.width = roundi(source.get_width()*factor)
		job.height = roundi(source.get_height()*factor)
		job.preserve_canvas = true
		var img := prepare(job)
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x,y).a < 0.04: img.set_pixel(x,y,Color(0,0,0,0))
		var bounds := img.get_used_rect()
		var out := Image.create_empty(canvas.x,canvas.y,false,Image.FORMAT_RGBA8)
		var offset := Vector2i((canvas.x-img.get_width())/2+int(job.get("offset_x",0)),canvas.y-bounds.end.y)
		out.blit_rect(img,Rect2i(Vector2i.ZERO,img.get_size()),offset)
		# Idle alone has a fixed upright silhouette. Register generated camera
		# variation against untouched idle_0; never apply this to falling poses.
		if job.animation == "idle":
			var base_path: String = job.output.get_base_dir()+"/idle_0.png"
			var base := Image.load_from_file(ProjectSettings.globalize_path(base_path))
			var target_height := base.get_used_rect().size.y + (4 if int(job.frame) == 2 else 2)
			var figure := out.get_region(out.get_used_rect())
			var registration_scale := minf(float(target_height)/figure.get_height(),float(canvas.x-2)/figure.get_width())
			figure.resize(roundi(figure.get_width()*registration_scale),roundi(figure.get_height()*registration_scale),Image.INTERPOLATE_LANCZOS)
			var foot_x := roundi(_foot_center(base)-_foot_center(figure))
			foot_x = clampi(foot_x,0,canvas.x-figure.get_width())
			out.fill(Color.TRANSPARENT)
			out.blit_rect(figure,Rect2i(Vector2i.ZERO,figure.get_size()),Vector2i(foot_x,canvas.y-figure.get_height()))
		DirAccess.make_dir_recursive_absolute(job.output.get_base_dir())
		var error := out.save_png(job.output)
		if error != OK:
			push_error("Could not save "+str(job.output))
			quit(1)
			return
		print(job.id," ",out.get_used_rect())
	quit()


func _foot_center(img: Image) -> float:
	var weight := 0.0
	var moment := 0.0
	for y in range(maxi(0,img.get_height()-20),img.get_height()):
		for x in img.get_width():
			var alpha := img.get_pixel(x,y).a
			weight += alpha
			moment += alpha*x
	return moment/weight if weight > 0.0 else img.get_width()*0.5

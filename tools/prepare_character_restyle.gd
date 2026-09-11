extends "res://tools/prepare_battle_sprites.gd"

# #485: mechanical exports from approved image-generated illustrations.
func _initialize() -> void:
	for id in ["arin","gangji"]:
		var root: String = "res://art/character-assets/v2/"+id
		DirAccess.make_dir_recursive_absolute(root)
		var source: String = "res://art/character-assets/v2/source-plates/"+id+"_portrait.png"
		var portrait := prepare({"source":source,"width":941,"height":1691,"margin":0.04,"foot":false})
		portrait.save_png("res://assets/sprites/characters/portraits/"+id+".png")
		var full := prepare({"source":source,"width":1400,"height":2200,"margin":0.10,"foot":false})
		full.save_png(root+"/char_"+id+"_fullbody.png")
		var square := prepare({"source":"res://art/character-assets/v2/source-plates/"+id+"_icon.png","width":256,"height":256,"margin":0.08,"foot":false})
		square.save_png(root+"/char_"+id+"_portrait_square.png")
		# Preserve aspect when making the two actual UI-size previews.
		for size in [Vector2i(42,36),Vector2i(60,32)]:
			var small := square.duplicate() as Image
			small.resize(size.y,size.y,Image.INTERPOLATE_LANCZOS)
			var framed := Image.create_empty(size.x,size.y,false,Image.FORMAT_RGBA8)
			framed.blit_rect(small,Rect2i(Vector2i.ZERO,small.get_size()),Vector2i((size.x-size.y)/2,0))
			framed.save_png(root+"/char_"+id+("_portrait_hud.png" if size.x == 42 else "_portrait_wide.png"))
		var silhouette := square.duplicate() as Image
		for y in silhouette.get_height():
			for x in silhouette.get_width():
				silhouette.set_pixel(x,y,Color(0,0,0,silhouette.get_pixel(x,y).a))
		silhouette.save_png(root+"/char_"+id+"_silhouette.png")
		var cutin := prepare({"source":"res://art/character-assets/v2/source-plates/"+id+"_cutin.png","width":2400,"height":1350,"preserve_canvas":true})
		# Keep the left 40% strictly empty for typography, including AA pixels.
		var placed := Image.create_empty(2400,1350,false,Image.FORMAT_RGBA8)
		placed.blit_rect(cutin,Rect2i(Vector2i.ZERO,cutin.get_size()),Vector2i(24,0))
		cutin = placed
		cutin.save_png(root+"/char_"+id+"_cutin.png")
		var overscan := Image.create_empty(2800,1350,false,Image.FORMAT_RGBA8)
		overscan.blit_rect(cutin,Rect2i(Vector2i.ZERO,cutin.get_size()),Vector2i(200,0))
		overscan.save_png(root+"/char_"+id+"_cutin_overscan.png")
		print(id," portrait ",portrait.get_used_rect()," and 7 art variants exported")
	quit()


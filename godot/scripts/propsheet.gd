## Лист моделей окружения гонок: `--resolution 1280x720 -- --propsheet=<папка>`.
## Каждая модель (RaceProps) — отдельным кадром спереди (лицо должно смотреть в камеру, по +Z) и сбоку,
## рядом красный столбик ростом Пахана (1,85 м) — видно масштаб и поворот. Печатает «PROPS …» и «PROPSHEET ok».
extends Node3D

var out := ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.34, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-30), 0)
	sun.shadow_enabled = true
	add_child(sun)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.22, 0.22, 0.24)
	fl.material_override = fm
	add_child(fl)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	_run(cam)

func _run(cam: Camera3D) -> void:
	await get_tree().process_frame
	var n := 0
	for id in RaceProps.SIZE.keys():
		if not RaceProps.has(id):
			print("PROPS нет модели: ", id)
			continue
		var holder := Node3D.new()
		add_child(holder)
		var t0 := Time.get_ticks_msec()
		var node := RaceProps.spawn(id, holder, Vector3.ZERO, 0.0)
		var ms := Time.get_ticks_msec() - t0
		var pole := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 1.85, 0.3)
		pole.mesh = bm
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(0.9, 0.1, 0.1)
		pole.material_override = red
		var sz: Vector3 = RaceProps.SIZE[id]
		pole.position = Vector3(sz.x * 0.5 + 0.8, 0.925, 0)
		holder.add_child(pole)
		var tris := 0
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh
			for si in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(si)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var d: float = maxf(sz.x, sz.y) * 1.4 + 2.0
		for view in [["front", Vector3(0, sz.y * 0.55, d)], ["side", Vector3(d, sz.y * 0.55, d * 0.2)]]:
			cam.global_position = view[1]
			cam.look_at(Vector3(0, sz.y * 0.45, 0), Vector3.UP)
			cam.fov = 50.0
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [id, view[0]]))
		print("PROPS %s: треугольников %d, загрузка %d мс" % [id, tris, ms])
		holder.queue_free()
		await get_tree().process_frame
		n += 1
	print("PROPSHEET ok: моделей %d" % n)
	get_tree().quit()

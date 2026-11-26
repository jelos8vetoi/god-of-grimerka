## Зонд камеры Подземки (без игры): `--headless --path godot --script res://scripts/golda67/pz_camprobe.gd`
## Строит G67Podzemka и для сетки точек внутри каждой комнаты пускает луч «пружины камеры» (слой 8, длина 4,6 м, 16 сторон,
## высота опоры 1,6 м, как SpringArm3D в game.gd). Если конец луча (с запасом 0,25 м) вне всех комнат — камера уйдёт в пустоту.
## Печатает «PZCAM дыра: …» по каждой комнате и «PZCAM итог: дыр N».
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var pz := G67Podzemka.new()
	root.add_child(pz)
	pz.build()
	for i in 3:
		await physics_frame
	var space := pz.get_world_3d().direct_space_state
	var rooms: Dictionary = G67Podzemka.ROOMS
	var holes := 0
	var by_room := {}
	for id in rooms:
		var r: Array = rooms[id]
		var x0 := float(r[0])
		var x1 := float(r[1])
		var z0 := float(r[2])
		var z1 := float(r[3])
		var y0 := float(r[4])
		var x := x0 + 0.5
		while x <= x1 - 0.5:
			var z := z0 + 0.5
			while z <= z1 - 0.5:
				var piv := Vector3(x, y0 + 1.6, z)
				for k in 16:
					var a := TAU * float(k) / 16.0
					var dir := Vector3(sin(a), 0.32, cos(a)).normalized()
					var q := PhysicsRayQueryParameters3D.create(piv, piv + dir * 4.6, 8)
					var hit := space.intersect_ray(q)
					var end: Vector3 = piv + dir * 4.6 if hit.is_empty() else (hit["position"] as Vector3) - dir * 0.2
					if not _inside(rooms, end):
						holes += 1
						var key := String(id)
						if not by_room.has(key):
							by_room[key] = []
						if (by_room[key] as Array).size() < 6:
							by_room[key].append("опора (%.1f, %.1f) → камера (%.1f, %.1f, %.1f)" % [x, z, end.x, end.y, end.z])
				z += 1.0
			x += 1.0
	for key in by_room:
		for s in by_room[key]:
			print("PZCAM дыра: %s: %s" % [key, s])
	print("PZCAM итог: дыр %d" % holes)
	quit()

func _inside(rooms: Dictionary, p: Vector3) -> bool:
	for id in rooms:
		var r: Array = rooms[id]
		if p.x >= float(r[0]) - 0.25 and p.x <= float(r[1]) + 0.25 and p.z >= float(r[2]) - 0.25 and p.z <= float(r[3]) + 0.25 and p.y >= float(r[4]) - 0.3 and p.y <= float(r[5]) + 0.3:
			return true
	return false

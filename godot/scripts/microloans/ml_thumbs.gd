## Модели для 3D-превью карточек «Микрозаймов» (MLUI.thumb): подработки, улучшения, бизнесы, вещи из хлама.
## build(id, узел) ставит модель в начало координат и возвращает её размер (для камеры превью).
## Модели — MGModels (свой .glb владельца из assets/minigames, если есть) или MGProps.
class_name MLThumbs

static func build(id: String, r: Node3D) -> float:
	if id.begins_with("junk_"):
		MGProps.junk_item(r, int(id.substr(5)))
		return 0.55
	match id:
		"job_podezd":
			var t := fit("res://assets/models/tyaga812.glb", r, 0.95)
			t.rotation.y = -PI * 0.5 - 0.5
			for k in 5:
				MGProps.ball(r, Vector3(0.45 + k * 0.07, 0.03, 0.3 - k * 0.06), 0.04, MGProps.mat("paper"), Vector3(1, 0.7, 1.2))
			return 1.0
		"job_repair":
			MGModels.spawn("ml_job_console", r, Vector3(0, 0, 0), -0.4, Vector3(0.32, 0.08, 0.22), func(n): MGProps.console_open(n))
			MGProps.tools(MGProps_at(r, Vector3(0.2, 0, 0.15)))
			return 0.5
		"job_deliv":
			MGProps.carton(MGProps_at(r, Vector3(0, 0, 0)), Vector3(0.5, 0.35, 0.4), "ХРУПКОЕ")
			MGProps.carton(MGProps_at(r, Vector3(0.05, 0.35, 0), 0.3), Vector3(0.35, 0.25, 0.3), "")
			return 0.75
		"job_sound":
			MGModels.spawn("ml_job_mixer", r, Vector3(0, 0, 0.1), 0.0, Vector3(0.6, 0.12, 0.45), func(n): MGProps.mixer(n))
			var sp := MGProps_at(r, Vector3(-0.45, 0, -0.2), 0.3)
			sp.scale = Vector3.ONE * 0.4
			MGProps.speaker(sp)
			return 0.9
		"job_junk":
			for k in 4:
				MGProps.junk_item(MGProps_at(r, Vector3(-0.3 + k * 0.2, 0, (k % 2) * 0.15), k * 0.6), [0, 1, 4, 7][k])
			return 0.9
		"up_phone":
			var p := MGProps_at(r, Vector3.ZERO, 0.3)
			p.rotation.x = -1.1
			p.position.y = 0.08
			MGProps.phone(p)
			return 0.25
		"up_calc":
			MGProps.calculator(MGProps_at(r, Vector3.ZERO, 0.4))
			return 0.22
		"up_scanner":
			MGProps.laptop(MGProps_at(r, Vector3.ZERO, 0.4), Color(0.4, 1.0, 0.5))
			return 0.45
		"up_slot", "up_talk":
			for k in 3:
				MGProps.box(r, Vector3(0, 0.02 + k * 0.03, 0), Vector3(0.22, 0.028, 0.3), MGProps.mat("red") if (k + int(id == "up_talk")) % 2 == 0 else MGProps.mat("black"), Vector3(0, 0.2 * k, 0))
			return 0.4
		"up_contacts":
			MGProps.box(r, Vector3(0, 0.03, 0), Vector3(0.16, 0.06, 0.22), MGProps.mat("blue_paint"))
			MGProps.text(r, "А–Я", Vector3(0, 0.062, 0), 30, Color(0.95, 0.9, 0.8), Vector3(-PI / 2, 0, 0))
			return 0.3
		"up_scooter":
			MGProps.cyl(r, Vector3(0, 0.05, 0.3), 0.06, 0.06, 0.04, MGProps.mat("rubber"), Vector3(0, 0, PI / 2))
			MGProps.cyl(r, Vector3(0, 0.05, -0.3), 0.06, 0.06, 0.04, MGProps.mat("rubber"), Vector3(0, 0, PI / 2))
			MGProps.box(r, Vector3(0, 0.08, 0), Vector3(0.12, 0.03, 0.6), MGProps.mat("red"))
			MGProps.cyl(r, Vector3(0, 0.45, 0.28), 0.015, 0.015, 0.75, MGProps.mat("steel"))
			MGProps.cyl(r, Vector3(0, 0.82, 0.28), 0.012, 0.012, 0.36, MGProps.mat("black"), Vector3(0, 0, PI / 2))
			return 0.95
		"biz_workshop":
			MGProps.desk(MGProps_at(r, Vector3.ZERO), 1.2, 0.6)
			MGProps.tools(MGProps_at(r, Vector3(-0.2, 0.78, 0)))
			MGProps.console_open(MGProps_at(r, Vector3(0.2, 0.78, 0), 0.3))
			return 1.4
		"biz_cleaning":
			return build("job_podezd", r)
		"biz_delivery":
			return build("job_deliv", r)
		"biz_studio":
			return build("job_sound", r)
		"biz_warehouse":
			MGProps.carton(MGProps_at(r, Vector3(-0.3, 0, 0)), Vector3(0.5, 0.45, 0.45), "ПАРТИЯ")
			MGProps.junk_item(MGProps_at(r, Vector3(0.3, 0, 0.1)), 4)
			return 0.9
	MGProps.carton(MGProps_at(r, Vector3.ZERO), Vector3(0.4, 0.3, 0.3), "?")
	return 0.6

## модель из файла, вписанная в size по самой длинной стороне, низом на пол, центром в начало координат
static func fit(path: String, parent: Node, size: float) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	var ps := load(path) as PackedScene
	if ps == null:
		return holder
	var m := ps.instantiate() as Node3D
	var acc: Array = []
	MGModels._walk(m, Transform3D.IDENTITY, acc)
	var bb := AABB()
	for i in acc.size():
		bb = acc[i] if i == 0 else bb.merge(acc[i])
	var s := size / maxf(0.001, maxf(bb.size.x, maxf(bb.size.y, bb.size.z)))
	holder.add_child(m)
	m.scale = Vector3.ONE * s
	var c := bb.get_center()
	m.position = Vector3(-c.x, -bb.position.y, -c.z) * s
	return holder

static func MGProps_at(r: Node3D, p: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	r.add_child(n)
	return n

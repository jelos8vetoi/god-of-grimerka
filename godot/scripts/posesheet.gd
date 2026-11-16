## Проверка анимаций: рендерит персонажей в нужных кадрах анимаций и складывает в лист (--posesheet=папка[,кто]).
extends Node3D

var out := ""
var who := ""
var cam: Camera3D

const SETS := {
	"pahan": ["res://assets/models/pahan.glb", 1.85, -1.0, ["Idle:0", "Run:0.25", "Light1:0.3", "Light1:0.5", "Light1:0.7", "Light2:0.3", "Light2:0.52", "Charge:0", "FullSwing:0.3", "FullSwing:0.48", "FullSwing:0.75", "Spin:0", "Smash:0.4", "Smash:0.55", "Heavy:0.35", "Block:0"]],
	"clipper": ["res://assets/models/clipper.glb", 1.8, 1.0, ["Idle:0", "Run:0.25", "Slash:0.32", "Slash:0.52", "Slash:0.72", "Hit:0.3", "Spawn:0.5"]],
	"hater": ["res://assets/models/hater.glb", 1.75, 1.0, ["Idle:0", "Run:0.25", "Cast:0.4", "Cast:0.6", "Hit:0.3"]],
}

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.27, 0.33)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(-0.8, 0.6, 0)
	add_child(l)
	# земля на y=0 — видно, стоит ли персонаж на ногах
	var gm := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(8, 0.02, 8)
	gm.mesh = gb
	gm.position.y = -0.01
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.45, 0.2, 0.2)
	gm.material_override = gmat
	add_child(gm)
	cam = Camera3D.new()
	cam.fov = 35
	add_child(cam)
	cam.make_current()
	await get_tree().process_frame
	for k in SETS:
		if who != "" and who != k:
			continue
		await _sheet(k)
	get_tree().quit()

func _sheet(k: String) -> void:
	var cfg: Array = SETS[k]
	var r := Rig.new()
	add_child(r)
	var poses: Dictionary = Poses.pahan_armed() if k == "pahan" else (Poses.clipper() if k == "clipper" else Poses.hater())
	r.setup(cfg[0], cfg[1], poses, true, cfg[2])
	if k == "pahan":
		r.attach("res://assets/models/balon.glb", "r", {"axis": "y", "from": 98.0, "to": 0.0, "grip": 0.07, "length": 0.56})
	elif k == "clipper":
		r.attach("res://assets/models/katana.glb", "r", {"axis": "z", "from": -48.8, "to": 48.8, "grip": 0.15, "edge": true, "length": 0.62, "part": func(y): return y > 13.0})
		r.attach("res://assets/models/katana.glb", "r", {"bone": "hips", "axis": "z", "from": -37.0, "to": 47.0, "grip": 0.3, "dir": [0.2, -0.35, -0.9], "length": 0.5, "part": func(y): return y < 13.0, "off": [0.17, 0.02, 0.02]})
	else:
		r.attach("res://assets/models/staff.glb", "r", {"axis": "y", "from": 0.0, "to": 97.5, "grip": 0.45, "length": 1.05})
	var shots: Array = cfg[3]
	var cw := 240
	var ch := 300
	var sheet := Image.create(cw * shots.size(), ch * 2, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var parts: PackedStringArray = shots[i].split(":")
		var full := "g/" + parts[0]
		r.player.play(full, 0.0)
		r.player.seek(float(parts[1]) * r.player.get_animation(full).length, true)
		r.player.pause()
		for row in 2:
			var ang := 0.35 if row == 0 else 1.45
			cam.position = Vector3(sin(ang) * 6.2, 1.0, cos(ang) * 6.2)
			cam.look_at(Vector3(0, 0.95, 0))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var sz := img.get_size()
			var crop := img.get_region(Rect2i(sz.x / 2 - sz.y * 0.4, 0, int(sz.y * 0.8), sz.y))
			crop.convert(Image.FORMAT_RGBA8)
			crop.resize(cw, ch)
			sheet.blit_rect(crop, Rect2i(0, 0, cw, ch), Vector2i(i * cw, row * ch))
	sheet.save_png(out.path_join("sheet_" + k + ".png"))
	r.queue_free()
	await get_tree().process_frame

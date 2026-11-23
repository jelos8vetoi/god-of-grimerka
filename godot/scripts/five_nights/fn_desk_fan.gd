## Настольный вентилятор будки: крутит ротор из модели desk_fan_a.glb (RotorPivot) и слегка дрожит корпусом.
## Своего _process нет: скорость и шаг времени даёт офис (на паузе и вне ночи вентилятор стоит).
class_name FNDeskFan
extends Node3D

const BLADES := 3                      # лопастей в модели
const SPIN_MAX := 46.5                 # рад/с (≈7,4 об/с): за кадр при 60 к/с ≈0,37 шага лопастей — без «обратного вращения» на экране
const SHAKE_HZ := 23.0                 # дрожь двигателя
const SHAKE_POS := 0.0004              # м, при полной скорости
const SHAKE_TILT := 0.15               # градусов, при полной скорости
const STOP_BELOW := 0.02               # ниже этой скорости ротор стоит
const BLUR := true                     # размытие лопастей: полупрозрачный диск
const BLUR_R := 0.13                   # м: до концов лопастей, внутри решётки
const BLUR_ALPHA := 0.3
const BLUR_FROM := 0.3                 # скорость, с которой диск начинает проявляться

var rotor: Node3D
var body: Node3D
var blur_disc: MeshInstance3D
var blur_mat: StandardMaterial3D
var base_pos := Vector3.ZERO
var base_rot := Vector3.ZERO
var phase := 0.0

func _ready() -> void:
	body = $Model
	base_pos = body.position
	base_rot = body.rotation
	rotor = find_child("RotorPivot", true, false)
	if BLUR and rotor != null:
		_make_blur()

func _make_blur() -> void:
	var k := rotor.global_transform.basis.get_scale().x
	var cyl := CylinderMesh.new()
	cyl.top_radius = BLUR_R / k
	cyl.bottom_radius = BLUR_R / k
	cyl.height = 0.004 / k
	cyl.radial_segments = 32
	cyl.rings = 1
	blur_mat = StandardMaterial3D.new()
	blur_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blur_mat.albedo_color = Color(0.5, 0.52, 0.5, 0.0)
	var blade := rotor.find_child("Object_7", true, false) as MeshInstance3D
	if blade != null and blade.mesh != null:
		var bm := blade.mesh.surface_get_material(0) as BaseMaterial3D
		if bm != null:
			blur_mat.albedo_color = Color(bm.albedo_color.r, bm.albedo_color.g, bm.albedo_color.b, 0.0)
	blur_disc = MeshInstance3D.new()
	blur_disc.name = "BlurDisc"
	blur_disc.mesh = cyl
	blur_disc.material_override = blur_mat
	blur_disc.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	blur_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blur_disc.visible = false
	rotor.add_child(blur_disc)

## spin 0…1 — доля полной скорости (ambience.fan_spin)
func tick(dt: float, spin: float) -> void:
	if rotor == null:
		return
	var s := clampf(spin, 0.0, 1.0)
	if s >= STOP_BELOW:
		rotor.rotate_z(-SPIN_MAX * s * dt)
	phase += dt * SHAKE_HZ * TAU * (1.0 + 0.07 * sin(phase * 0.31))
	body.position = base_pos + Vector3(sin(phase), cos(phase * 1.37) * 0.6, sin(phase * 0.73) * 0.5) * SHAKE_POS * s
	var tl := deg_to_rad(SHAKE_TILT) * s
	body.rotation = base_rot + Vector3(sin(phase * 0.9) * tl, 0.0, cos(phase * 1.13) * tl)
	if blur_disc != null:
		var a := BLUR_ALPHA * clampf((s - BLUR_FROM) / (1.0 - BLUR_FROM), 0.0, 1.0)
		blur_disc.visible = a > 0.002
		blur_mat.albedo_color.a = a

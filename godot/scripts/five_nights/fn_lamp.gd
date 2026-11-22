## Лампа коридора «5 НОЧЕЙ»: свет и стекло мигают по режиму. Дети по договорённости: Light (Light3D, может не быть) и
## Glass (MeshInstance3D со своим светящимся материалом). Номинальные значения читаются из сцены.
class_name FNLamp
extends Node3D

@export_enum("steady", "hum", "sputter", "pulse", "dead") var mode := "hum"

var light: Light3D
var glass_mat: StandardMaterial3D
var rated := 0.0
var glass_rated := 0.0
var t := 0.0
var k := 1.0
var dip_left := 0.0
var next_dip := 0.0
var phase := "on"
var phase_left := 0.0
var blinks := 0
var blackout := false

func _ready() -> void:
	light = get_node_or_null("Light") as Light3D
	var glass := get_node_or_null("Glass") as MeshInstance3D
	if light != null:
		rated = light.light_energy
	if glass != null:
		glass_mat = glass.material_override as StandardMaterial3D
	if glass_mat != null:
		glass_rated = glass_mat.emission_energy_multiplier
	next_dip = randf_range(6.0, 14.0)
	_start_on()
	rest()

func _start_on() -> void:
	phase = "on"
	phase_left = randf_range(0.6, 3.5)

func _apply() -> void:
	if light != null:
		light.light_energy = rated * k
	if glass_mat != null:
		glass_mat.emission_energy_multiplier = glass_rated * k

func rest() -> void:
	k = 0.0 if mode == "dead" else 1.0
	dip_left = 0.0
	_start_on()
	_apply()

func tick(dt: float) -> void:
	t += dt
	match mode:
		"steady":
			k = 1.0
		"hum":
			next_dip -= dt
			if next_dip <= 0.0:
				next_dip = randf_range(6.0, 14.0)
				dip_left = 0.08
			k = 0.97 + 0.03 * sin(t * 13.0)
			if dip_left > 0.0:
				dip_left -= dt
				k = 0.45
		"sputter":
			_sputter(dt)
		"pulse":
			k = 0.85 + 0.15 * sin(t * 3.0)
		_:
			k = 0.0
	_apply()

func _sputter(dt: float) -> void:
	phase_left -= dt
	match phase:
		"on":
			k = randf_range(0.92, 1.0)
			if phase_left <= 0.0:
				blackout = randf() < 0.2
				blinks = randi_range(2, 5)
				phase = "off"
				phase_left = randf_range(0.4, 1.0) if blackout else randf_range(0.04, 0.12)
		"off":
			k = 0.0
			if phase_left <= 0.0:
				if blackout:
					_start_on()
				else:
					phase = "flash"
					phase_left = randf_range(0.03, 0.1)
		_:
			k = 1.0
			if phase_left <= 0.0:
				blinks -= 1
				if blinks > 0:
					phase = "off"
					phase_left = randf_range(0.04, 0.12)
				else:
					_start_on()

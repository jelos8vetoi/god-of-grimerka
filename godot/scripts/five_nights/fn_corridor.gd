## Левый коридор «5 НОЧЕЙ» (CAM 4), собранный в редакторе: scenes/five_nights/cam4_corridor.tscn. Узел Cctv держит точку
## обзора камеры (для предпросмотра в редакторе, в игре его нет), EnemySpots — места врагов, AnomalyFigure — силуэт для
## аномалии, Lamps — лампы с мерцанием (FNLamp).
class_name FNCorridor
extends Node3D

@export_range(0.0, 12.0, 0.5) var sway := 4.0        # размах поворота камеры, градусы

var view := {}                 # {pos, look, fov, sway} — как у FNFacility.cams
var spot_xf: Array = []        # Transform3D узлов EnemySpots по порядку
var figure: Node3D
var lamps: Array = []
var flicker := true

func _ready() -> void:
	var cam := get_node_or_null("Cctv") as Camera3D
	if cam != null:
		var pos := cam.global_position
		view = {"pos": pos, "look": pos - cam.global_basis.z * 8.0, "fov": cam.fov, "sway": sway}
		cam.queue_free()
	for s in $EnemySpots.get_children():
		spot_xf.append((s as Node3D).global_transform)
	figure = $AnomalyFigure
	for l in $Lamps.get_children():
		if l is FNLamp:
			lamps.append(l)

func tick(dt: float) -> void:
	if not flicker:
		return
	for l in lamps:
		(l as FNLamp).tick(dt)

## проверки замораживают свет, чтобы кадры можно было сравнивать
func freeze(on: bool) -> void:
	flicker = not on
	if on:
		for l in lamps:
			(l as FNLamp).rest()

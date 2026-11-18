## Гонщик на пылесосе ТЯГА-812 — только вид: персонаж игры (Пахан, madk1d, клиппер, хейтер, бот, Дрей) верхом
## на модели tyaga812.glb, позы езды — те же клипы, что у Пахана в кампании (TyagaClips: RideSit, RideBoost,
## RideDrift, RideJump…). Физики и ввода здесь нет: их ведёт гоночный участник (race_rider.gd) или экран меню.
## Вперёд — +Z, как у героя в игре. Пылесос стоит там же, где в кампании верхом (TyagaClips.V_RIDE).
class_name RaceVisual
extends Node3D

const HEIGHT := 1.85          # все гонщики одного роста: рука на трубе, таз на сиденье (клипы посчитаны под Пахана)
## Кто ездит: модель, имя на табло, сторона оружия рига, цвет корпуса пылесоса (у Пахана — родной)
const RIDERS := {
	"pahan": {"model": "pahan", "name": "ПАХАН", "wsign": -1.0, "tint": Color(1, 1, 1), "own": true},
	"madk1d": {"model": "madk1d", "name": "MADK1D", "wsign": 1.0, "tint": Color(0.55, 0.75, 1.0)},
	"clipper": {"model": "clipper", "name": "КЛИППЕР", "wsign": 1.0, "tint": Color(0.95, 0.4, 0.35)},
	"hater": {"model": "hater", "name": "ХЕЙТЕР", "wsign": 1.0, "tint": Color(0.7, 0.5, 1.0)},
	"bot": {"model": "bot", "name": "БОТ-812", "wsign": 1.0, "tint": Color(0.55, 0.95, 0.55)},
	"drey": {"model": "drey", "name": "ДРЕЙ", "wsign": 1.0, "tint": Color(1.0, 0.82, 0.35)},
}

var id := "pahan"
var rig: Rig
var unit: Node3D              # пылесос (под героем)
var rock: Node3D              # корпус: дрожь мотора и покачивание
var rock_t := 0.0
var power := 0.4              # 0..1: насколько сильно трясёт мотор
var squash := 0.0             # >0 — присел (приземление), <0 — вытянулся (прыжок)

## Клипы езды для любого скелета Mixamo: базовые позы Пахана + все клипы ТЯГИ-812
static func clips() -> Dictionary:
	var A := Poses.pahan()
	TyagaClips.add_to(A)
	return A

func setup(rider: String, shadows := true) -> void:
	id = rider if RIDERS.has(rider) else "pahan"
	var cfg: Dictionary = RIDERS[id]
	rig = Rig.new()
	add_child(rig)
	rig.setup("res://assets/models/%s.glb" % String(cfg["model"]), HEIGHT, clips(), shadows, float(cfg["wsign"]), "race_" + id)
	unit = Node3D.new()
	unit.position = TyagaClips.V_RIDE
	add_child(unit)
	rock = Node3D.new()
	unit.add_child(rock)
	var m: Node3D = (load(Tyaga.MODEL) as PackedScene).instantiate()
	m.rotation.y = PI * 0.5
	m.scale = Vector3.ONE * TyagaClips.K
	rock.add_child(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not cfg.get("own", false) and g.mesh != null:
			for si in g.mesh.get_surface_count():
				var src := g.mesh.surface_get_material(si)
				if src is StandardMaterial3D:
					var mat: StandardMaterial3D = src.duplicate()
					mat.albedo_color = mat.albedo_color * (cfg["tint"] as Color)
					g.set_surface_override_material(si, mat)
	rig.play("RideSit", 0.0)

static func rider_name(rider: String) -> String:
	return String((RIDERS.get(rider, RIDERS["pahan"]) as Dictionary)["name"])

## Корпус живёт: дрожь мотора (три несовпадающие частоты), покачивание на ходу, приседание
func _process(dt: float) -> void:
	if rock == null:
		return
	rock_t += dt
	squash = lerpf(squash, 0.0, 1.0 - exp(-9.0 * dt))
	var jx: float = sin(rock_t * 61.0) * 0.004 * power
	var jy: float = abs(sin(rock_t * 47.0 + 0.7)) * 0.005 * power
	var roll: float = sin(rock_t * 7.0 + 0.4) * 0.025 * power + sin(rock_t * 71.0) * 0.006 * power
	rock.position = Vector3(jx, jy, 0.0)
	rock.rotation = Vector3(sin(rock_t * 9.0) * 0.012 * power, 0.0, roll)
	rock.scale = Vector3(1.0 + 0.1 * squash, 1.0 - 0.16 * squash, 1.0 + 0.1 * squash)

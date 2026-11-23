## Проекция лицевой плиты и глубины корпуса в координаты экрана, без второй камеры.
extends Node2D

const SIZE := Vector2(1440, 720)
const FEED := Rect2(26, 51, 1056, 594)
const PANEL := Rect2(1100, 51, 314, 594)
const PIVOT := Vector2(720, 518)
const FOCAL_LENGTH := 1800.0
const OUTLINE := [
	Vector2(18, 0), Vector2(1422, 0), Vector2(1440, 18), Vector2(1440, 702),
	Vector2(1422, 720), Vector2(18, 720), Vector2(0, 702), Vector2(0, 18),
]

var fit := 1.0
var origin := Vector2.ZERO
var rotation_3d := Basis.IDENTITY
var wear := PackedVector2Array()

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 19084
	for i in 45:
		var x := rng.randf_range(24.0, SIZE.x - 24.0)
		var y := (4.0 if i < 20 else SIZE.y - 16.0) + rng.randf_range(0.0, 10.0)
		wear.append(Vector2(x, y))
		wear.append(Vector2(x + rng.randf_range(1.0, 9.0), y - rng.randf_range(-1.0, 2.0)))

func pose(progress: float, frame: Vector2) -> Transform2D:
	var fold := 1.0 - progress
	var pitch := pow(fold, 0.83)
	var settle := sin(smoothstep(0.71, 1.0, progress) * PI) * (1.0 - smoothstep(0.11, 0.34, fold))
	fit = minf((frame.x - 76.0) / SIZE.x, (frame.y - 118.0) / SIZE.y)
	origin = frame * Vector2(0.5, 0.52) + (PIVOT - SIZE * 0.5) * fit
	origin += Vector2(frame.x * 0.068 * fold, frame.y * 1.01 * pow(fold, 1.44) - settle * 4.0)
	rotation_3d = Basis.from_euler(Vector3(-0.77 * pitch + 0.042 * settle, 0.29 * pitch, -0.15 * pitch))
	queue_redraw()

	# Надписи и кнопки включаются у рабочего положения, когда лицевая плита почти фронтальна.
	var center := _project(SIZE * 0.5)
	var horizontal := (_project(Vector2(SIZE.x, SIZE.y * 0.5)) - _project(Vector2(0, SIZE.y * 0.5))) / SIZE.x
	var vertical := (_project(Vector2(SIZE.x * 0.5, SIZE.y)) - _project(Vector2(SIZE.x * 0.5, 0))) / SIZE.y
	return Transform2D(horizontal, vertical, center - horizontal * SIZE.x * 0.5 - vertical * SIZE.y * 0.5)

func _project(p: Vector2, depth := 0.0) -> Vector2:
	var point := rotation_3d * Vector3(p.x - PIVOT.x, p.y - PIVOT.y, depth)
	return origin + Vector2(point.x, point.y) * (fit * FOCAL_LENGTH / (FOCAL_LENGTH + point.z))

func _plane(points: Array, col: Color, depth := 0.0) -> void:
	var projected := PackedVector2Array()
	for p in points:
		projected.append(_project(p, depth))
	draw_colored_polygon(projected, col)

func _plate(rect: Rect2, col: Color) -> void:
	_plane([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)], col)

func _edge(a: Vector2, b: Vector2, col: Color, width := 1.0) -> void:
	draw_line(_project(a), _project(b), col, width * fit, true)

func _draw() -> void:
	const DEPTH := 48.0
	_plane(OUTLINE, Color("#0d0f0e"), DEPTH)
	for i in OUTLINE.size():
		var a: Vector2 = OUTLINE[i]
		var b: Vector2 = OUTLINE[(i + 1) % OUTLINE.size()]
		var wall := Color("#272a26") if i in [3, 4, 5] else Color("#151917")
		draw_colored_polygon(PackedVector2Array([_project(a), _project(b), _project(b, DEPTH), _project(a, DEPTH)]), wall)
	_plane(OUTLINE, Color("#272c28"))
	var inside := PackedVector2Array()
	for p: Vector2 in OUTLINE:
		inside.append(_project(p.lerp(SIZE * 0.5, 0.014)))
	draw_colored_polygon(inside, Color("#202421"))
	for i in OUTLINE.size():
		var a: Vector2 = OUTLINE[i]
		var b: Vector2 = OUTLINE[(i + 1) % OUTLINE.size()]
		_edge(a, b, Color("#4b5048") if i in [0, 6, 7] else Color("#131614"))

	_plate(FEED.grow(6.0), Color("#121713"))
	_plate(FEED.grow(2.0), Color("#0a0e0b"))
	# Смягчённый отблеск на погашенном стекле и матовый свет на рамке.
	var glass := PackedVector2Array([
		_project(FEED.position), _project(Vector2(FEED.end.x, FEED.position.y)),
		_project(FEED.end), _project(Vector2(FEED.position.x, FEED.end.y)),
	])
	var reflection := PackedColorArray([Color("#293430"), Color("#18211e"), Color("#111714"), Color("#1a2420")])
	draw_polygon(glass, reflection)
	_plate(PANEL.grow(4.0), Color("#101411"))
	_plate(PANEL, Color("#1b221e"))
	_edge(Vector2(26, 650), Vector2(1414, 650), Color("#4c5148"))
	_edge(Vector2(23, 45), Vector2(1417, 45), Color("#101411"), 2.0)
	_edge(Vector2(190, 693), Vector2(1245, 693), Color("#161a16"))
	for x in [57.0, 1320.0]:
		for i in 7:
			_plate(Rect2(x + i * 10.0, 691, 5, 10), Color("#111613"))
			_edge(Vector2(x + i * 10.0, 701), Vector2(x + i * 10.0 + 5.0, 701), Color("#3d4239"))
	for p in [Vector2(12, 31), Vector2(1428, 31), Vector2(12, 683), Vector2(1428, 683)]:
		_plate(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color("#131714"))
		_edge(p + Vector2(-2, 1), p + Vector2(2, -1), Color("#565c52"))
	for i in range(0, wear.size(), 2):
		_edge(wear[i], wear[i + 1], Color(0.50, 0.52, 0.44, 0.26 if i % 6 == 0 else 0.12))

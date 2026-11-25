class_name G67Sign
extends RefCounted
## Табличка под надписью в мире. Label3D сам по себе — буквы в воздухе; board() ставит за текстом тёмный щит с рамкой
## по размеру надписи, чтобы она читалась как настоящая вывеска на стене, стойке или подвесе.
## hang > 0 — два подвеса вверх такой длины (вывеска под потолком); post > 0 — стойка вниз (вывеска на ножке).

const PAD := Vector2(0.22, 0.14)
const C_BOARD := Color(0.06, 0.065, 0.08)
const C_FRAME := Color(0.34, 0.34, 0.36)

static func size_of(lb: Label3D) -> Vector2:
	var f: Font = lb.font if lb.font != null else ThemeDB.fallback_font
	var w := lb.width if lb.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	var s := f.get_multiline_string_size(lb.text, HORIZONTAL_ALIGNMENT_CENTER, w, lb.font_size)
	return s * lb.pixel_size

static func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, metal := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.7
	m.metallic = metal
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

static func board(lb: Label3D, hang := 0.0, post := 0.0, col := C_BOARD) -> void:
	var s := size_of(lb) + PAD
	_box(lb, Vector3(s.x, s.y, 0.04), Vector3(0, 0, -0.035), col)
	_box(lb, Vector3(s.x + 0.07, s.y + 0.07, 0.03), Vector3(0, 0, -0.055), C_FRAME, 0.6)
	if hang > 0.0:
		for sx in [-1.0, 1.0]:
			_box(lb, Vector3(0.03, hang, 0.03), Vector3(sx * (s.x * 0.5 - 0.12), s.y * 0.5 + hang * 0.5, -0.05), C_FRAME, 0.6)
	if post > 0.0:
		_box(lb, Vector3(0.07, post, 0.07), Vector3(0, -s.y * 0.5 - post * 0.5, -0.06), C_FRAME, 0.6)

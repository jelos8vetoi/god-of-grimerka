## Карточка-листок по центру экрана: текст крупно, подпись мельче. Закрывается E/Esc или уходом от места; игру не останавливает.
class_name G67ReadCard
extends CanvasLayer

var hero: Node3D
var origin := Vector3.ZERO
var t := 0.0
var text_all := ""

static func open(parent: Node, hero_node: Node3D, text: String, sub: String) -> G67ReadCard:
	for c in parent.get_children():
		if c is G67ReadCard:
			c.queue_free()
	var rc := G67ReadCard.new()
	rc.layer = 60
	rc.hero = hero_node
	rc.origin = hero_node.global_position
	rc.text_all = text + "\n" + sub
	parent.add_child(rc)
	var vp := parent.get_viewport().get_visible_rect().size
	var panel := ColorRect.new()
	panel.color = Color(0.95, 0.94, 0.89, 0.97)
	panel.size = Vector2(vp.x * 0.5, vp.y * 0.34)
	panel.position = Vector2(vp.x * 0.25, vp.y * 0.28)
	rc.add_child(panel)
	var edge := ColorRect.new()
	edge.color = Color(0.1, 0.1, 0.12)
	edge.size = panel.size + Vector2(8, 8)
	edge.position = panel.position - Vector2(4, 4)
	rc.add_child(edge)
	rc.move_child(edge, 0)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(vp.y * 0.05))
	l.add_theme_color_override("font_color", Color(0.06, 0.06, 0.08))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(panel.size.x * 0.9, panel.size.y * 0.6)
	l.position = panel.position + Vector2(panel.size.x * 0.05, panel.size.y * 0.08)
	rc.add_child(l)
	if sub != "":
		var sl := Label.new()
		sl.text = sub
		sl.add_theme_font_size_override("font_size", int(vp.y * 0.028))
		sl.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3))
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.size = Vector2(panel.size.x * 0.9, panel.size.y * 0.3)
		sl.position = panel.position + Vector2(panel.size.x * 0.05, panel.size.y * 0.66)
		rc.add_child(sl)
	return rc

func _process(dt: float) -> void:
	t += dt
	if t > 0.5 and (Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ESCAPE)):
		queue_free()
	elif hero == null or not is_instance_valid(hero) or hero.global_position.distance_to(origin) > 3.2:
		queue_free()

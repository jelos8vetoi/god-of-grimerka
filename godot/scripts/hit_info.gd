## Одно попадание: что ядро боя передаёт цели (enemy.take_hit_info). Собирается в combat.gd из AttackData.
class_name HitInfo
extends RefCounted

var damage := 0.0
var stagger := 0.0          # сколько равновесия снять
var dir := Vector3.FORWARD  # куда летит удар (от бьющего к цели)
var knockback := 0.0
var launch := 0.0
var stun := 0.0
var heavy := false
var power := 0              # 0 — лёгкий, 1 — тяжёлый, 2 — добивание
var attack_id := ""
var style_id := ""
var source: Node = null
var pos := Vector3.ZERO     # точка контакта

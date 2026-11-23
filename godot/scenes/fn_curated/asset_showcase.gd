extends Node3D

@onready var rotor := $Office/desk_fan_a.find_child("RotorPivot", true, false) as Node3D

func _process(delta: float) -> void:
	if rotor:
		rotor.rotate_z(-3.0 * delta)

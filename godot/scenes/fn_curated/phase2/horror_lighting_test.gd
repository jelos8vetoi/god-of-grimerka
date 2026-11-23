extends Node3D

enum State { NORMAL, CRT, EMERGENCY, BLACKOUT }
@export var initial_state := State.NORMAL

func _ready() -> void:
	set_state(initial_state)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			set_state(event.keycode - KEY_1)

func set_state(state: int) -> void:
	$Normal.visible = state == State.NORMAL
	$CRT.visible = state == State.CRT or state == State.NORMAL
	$Monitor/Phosphor.visible = $CRT.visible
	$Emergency.visible = state == State.EMERGENCY
	$Residual.visible = true
	$World.environment.ambient_light_energy = [0.18, 0.045, 0.075, 0.018][state]

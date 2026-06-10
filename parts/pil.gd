extends Node3D
## Toplanabilir FENER PILI. "pil" grubuna girer; oyuncu yaklasinca toplar (oyuncu.gd).
func _ready() -> void:
	add_to_group("pil")
func _process(delta: float) -> void:
	rotate_y(delta * 1.6)
	position.y += sin(Time.get_ticks_msec() * 0.004) * 0.0015

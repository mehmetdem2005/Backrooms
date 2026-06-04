extends CharacterBody3D
## Basit birinci-sahis gezgin (Backrooms dunyasini dolasmak icin).
## Fare = bakis, WASD = hareket, Shift = kos, Space = zipla, Esc = imleci birak.

@export var hiz: float = 4.0
@export var kosu: float = 7.0
@export var ziplama: float = 4.5
@export var fare_hassas: float = 0.0025

var _yer_cekimi: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _kamera: Camera3D

func _ready() -> void:
	_kamera = $Kamera
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(olay: InputEvent) -> void:
	if olay is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-olay.relative.x * fare_hassas)
		_kamera.rotate_x(-olay.relative.y * fare_hassas)
		_kamera.rotation.x = clampf(_kamera.rotation.x, -1.4, 1.4)
	elif olay is InputEventKey and olay.pressed and olay.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _yer_cekimi * delta
	if Input.is_action_pressed("ui_accept") and is_on_floor():
		velocity.y = ziplama
	var ileri := Input.get_axis("ui_down", "ui_up")
	var yan := Input.get_axis("ui_left", "ui_right")
	# WASD (eylem haritasi olmasa da fiziksel tuslarla)
	var giris := Vector2.ZERO
	giris.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	giris.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	if giris == Vector2.ZERO:
		giris = Vector2(yan, -ileri)
	var v := (transform.basis * Vector3(giris.x, 0, giris.y)).normalized()
	var s := kosu if Input.is_physical_key_pressed(KEY_SHIFT) else hiz
	velocity.x = v.x * s
	velocity.z = v.z * s
	move_and_slide()

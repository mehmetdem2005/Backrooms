extends Node
## OYUN DURUMU (autoload) - oyuncu/canavar referanslari, alarm durumu, girdi haritasi.
## Faz 3: nefes/kalp/kosu/egilme/stamina + alarm + canavar aksiyonu burdan koordine edilir.

signal alarm_basladi
signal alarm_bitti
signal yakalandi_sinyal

var oyuncu: Node3D = null
var canavar: Node3D = null
var alarm: bool = false
var ses_yaricapi: float = 4.0      # oyuncu gurultu yaricapi (mod'a gore; canavar algisi icin)

func _ready() -> void:
	# Girdi haritasi (project.godot'a yazmak yerine kodla) - fiziksel tuslar
	_ekle("ileri", [KEY_W, KEY_UP])
	_ekle("geri",  [KEY_S, KEY_DOWN])
	_ekle("sol",   [KEY_A, KEY_LEFT])
	_ekle("sag",   [KEY_D, KEY_RIGHT])
	_ekle("atla",  [KEY_SPACE])
	_ekle("kos",   [KEY_SHIFT])
	_ekle("egil",  [KEY_CTRL, KEY_C])
	_ekle("sessiz",[KEY_ALT])
	_ekle("alarm", [KEY_G])
	_ekle("etkilesim", [KEY_E])
	_ekle("fener", [KEY_F])

func _ekle(ad: String, tuslar: Array) -> void:
	if InputMap.has_action(ad):
		return
	InputMap.add_action(ad)
	for k in tuslar:
		var e := InputEventKey.new(); e.physical_keycode = k
		InputMap.action_add_event(ad, e)

func alarmi_baslat() -> void:
	if alarm: return
	alarm = true
	emit_signal("alarm_basladi")

func alarmi_durdur() -> void:
	if not alarm: return
	alarm = false
	emit_signal("alarm_bitti")

func yakalandi() -> void:
	emit_signal("yakalandi_sinyal")

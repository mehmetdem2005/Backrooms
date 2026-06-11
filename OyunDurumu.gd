extends Node
## OYUN DURUMU (autoload) - oyuncu/canavar referanslari, alarm durumu, girdi haritasi.
## Faz 3: nefes/kalp/kosu/egilme/stamina + alarm + canavar aksiyonu burdan koordine edilir.

signal alarm_basladi
signal alarm_bitti
signal yakalandi_sinyal

var oyuncu: Node3D = null
var canavar: Node3D = null
var nav: Node = null               # NavIzgara (yol bulma)
var alarm: bool = false
var av_modu: bool = false          # sinematik sonrasi aktif av (canavar avlar)
var sinematik: bool = false        # acilis sinematigi sirasinda oyuncu kontrolu kilitli
var ses_yaricapi: float = 4.0      # oyuncu gurultu yaricapi (mod'a gore; canavar algisi icin)
var son_ses_konum: Vector3 = Vector3.ZERO
var son_ses_zaman: float = -999.0

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

## Psikolojik altyazilar (#28) - ara ara beliren rahatsiz edici ic-ses/fisilti
const SAKIN := ["Buraya daha once geldin.", "Duvarlar nefes aliyor.", "Yalniz degilsin.",
	"Cikis... hic olmadi ki.", "Birileri seni izliyor.", "Geri donme. Beni gorursun."]
const AVDA := ["Korktugunda daha lezzetli oluyorsun.", "Kosmak ise yaramaz.", "Seni koklayabiliyorum.",
	"Geri gel...", "Daha hizli kac, hadi.", "Nereye saklanirsan saklan."]
var _alt_t := 16.0

func _process(delta: float) -> void:
	if sinematik: return
	_alt_t -= delta
	if _alt_t <= 0.0:
		var alt := get_node_or_null("/root/Altyazi")
		if alt and oyuncu:
			var liste: Array = AVDA if (av_modu or alarm) else SAKIN
			alt.call("goster", liste[randi() % liste.size()], 3.5)
		_alt_t = randf_range(9.0, 16.0) if (av_modu or alarm) else randf_range(20.0, 38.0)

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

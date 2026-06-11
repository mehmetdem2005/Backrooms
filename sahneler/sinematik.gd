extends Node
## ACILIS SINEMATIGI (#24): KALITELI uyanma (goz kapagi + bulanik->net + vignette) ->
## canavar IBLIS SESIYLE konusur (gercek replikler, altyazi senkron) -> 'ON saniye' ->
## birakir -> korkunc geri sayim 10..1 -> AV baslar ('Geliyorum').
## Oyuncu kontrolu sinematik boyunca kilitli (OyunDurumu.sinematik).

var _od: Node
var _alt: Node
var _oyuncu: Node3D
var _canavar: Node3D
var _kara: ColorRect              # uyanma post-efekti (shader)
var _mat: ShaderMaterial
var _ses_konus: AudioStreamPlayer # canavar konusmasi (iblis ses)
var _ses_growl: AudioStreamPlayer # uyaninca hirilti

const CIN := {
	"cin1": "Uyan. Uyan artik kucuk sey.",
	"cin2": "Ne zamandir seni izliyordum. Uykunda bile korkuyordun.",
	"cin3": "Bu duvarlarin arasinda kac kisi curudu? Hicbiri cikamadi.",
	"cin4": "Sana on saniye veriyorum. Kacmani izlemek en sevdigim kisim.",
	"cin5": "Geliyorum.",
}

func _ready() -> void:
	call_deferred("_basla")

func _basla() -> void:
	_od = get_node_or_null("/root/OyunDurumu")
	_alt = get_node_or_null("/root/Altyazi")
	if _od == null: return
	_od.sinematik = true
	_od.av_modu = false
	for _t in range(180):
		_oyuncu = _od.oyuncu; _canavar = _od.canavar
		if _oyuncu and _canavar: break
		await get_tree().process_frame
	_ui_kur()
	if _oyuncu and _canavar:
		var ileri := -_oyuncu.global_transform.basis.z
		var p: Vector3 = _oyuncu.global_position + ileri * 1.15
		_canavar.call("sinematik_yerlestir", p, _oyuncu.global_position)
	await _akis()

func _ui_kur() -> void:
	var cl := CanvasLayer.new(); cl.layer = 60; cl.name = "SinematikUI"; add_child(cl)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://sahneler/uyanma.gdshader")
	_mat.set_shader_parameter("blur_amt", 1.0)
	_mat.set_shader_parameter("eyelid", 0.0)     # goz kapali
	_mat.set_shader_parameter("vignette", 0.9)
	_mat.set_shader_parameter("darken", 0.7)
	_mat.set_shader_parameter("desat", 1.0)
	_kara = ColorRect.new()
	_kara.material = _mat
	_kara.set_anchors_preset(Control.PRESET_FULL_RECT)
	_kara.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_kara)
	_ses_konus = AudioStreamPlayer.new(); _ses_konus.volume_db = 3.0; add_child(_ses_konus)
	var g = load("res://audio/canavar_growl.wav")
	_ses_growl = AudioStreamPlayer.new(); _ses_growl.stream = g
	_ses_growl.pitch_scale = 0.55; _ses_growl.volume_db = 2.0; add_child(_ses_growl)

func _b(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _say(metin: String, sure: float) -> void:
	if _alt: _alt.call("goster", metin, sure)

## Bir canavar repligini sesle + altyazi senkron oynat, bitene kadar bekle.
func _replik(ad: String) -> void:
	var s = load("res://audio/canavar/" + ad + ".wav")
	var sure := 2.4
	if s:
		_ses_konus.stream = s
		_ses_konus.play()
		if s is AudioStream: sure = s.get_length()
	_say(CIN[ad], sure + 0.6)
	await _b(sure + 0.45)

func _p(ad: String, deg) -> void:
	if _mat: _mat.set_shader_parameter(ad, deg)

func _akis() -> void:
	# 1) KALITELI UYANMA: agir goz kapaklari, birkac yari-kirpis, bulanik->net.
	#    (nefes/kalp sesi oyuncu tarafindan zaten caliyor -> bogucu uyanis atmosferi)
	var tw := create_tween().set_parallel(false)
	# ilk aralik: hafif aralanir (cok bulanik, koyu)
	tw.tween_method(_p.bind("eyelid"), 0.0, 0.22, 1.0)
	tw.tween_method(_p.bind("eyelid"), 0.22, 0.06, 0.5)   # tekrar kapanir (sersem)
	tw.tween_method(_p.bind("eyelid"), 0.06, 0.45, 0.9)
	tw.tween_method(_p.bind("eyelid"), 0.45, 0.20, 0.4)   # kirpis
	tw.tween_method(_p.bind("eyelid"), 0.20, 1.0, 1.1)    # tam acilis
	# paralel: bulanik->net, karartma/desat/vignette yerlesir
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_method(_p.bind("blur_amt"), 1.0, 0.0, 4.6)
	tw2.tween_method(_p.bind("darken"), 0.7, 0.0, 4.2)
	tw2.tween_method(_p.bind("desat"), 1.0, 0.0, 4.4)
	tw2.tween_method(_p.bind("vignette"), 0.9, 0.28, 4.0)
	await tw.finished
	# 2) Gozler acildi: canavar yuzde -> hirilti, sonra IBLIS SESIYLE konusur.
	_ses_growl.play()
	await _b(0.5)
	await _replik("cin1")
	await _replik("cin2")
	await _replik("cin3")
	await _replik("cin4")
	# 3) BIRAK: kontrol acilir, canavar geri cekilir, post-efekt kapanir.
	_p("vignette", 0.0)
	_kara.visible = false
	_od.sinematik = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if DisplayServer.is_touchscreen_available() else Input.MOUSE_MODE_CAPTURED
	if _canavar and _oyuncu:
		var geri := (_canavar.global_position - _oyuncu.global_position)
		geri.y = 0
		if geri.length() > 0.1: _canavar.global_position += geri.normalized() * 3.0
	# 4) Korkunc geri sayim 10..1 (her rakamda vurus + altyazi)
	var rakam := ["ON", "DOKUZ", "SEKIZ", "YEDI", "ALTI", "BES", "DORT", "UC", "IKI", "BIR"]
	for r in rakam:
		_say(r + "...", 1.0); _ses_growl.play(); await _b(1.0)
	# 5) AV baslar
	_od.av_modu = true
	await _replik("cin5")
	queue_free()

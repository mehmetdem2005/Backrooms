extends Node3D
## CANAVAR AI (Faz 4 #14-16) - NavIzgara (AStar, duvardan gecmez) + algi (gorus raycast) +
## durum makinesi: AVLA(kovala) / KESISME(onunu kes, dengeli) / ARA(son gorulen/ses) / DEVRIYE.
## Sadece av aktifken (OyunDurumu.av_modu veya alarm) avlar; oncesi sinematik kontrolunde.

@export var animasyon: String = "NlaTrack_009"
@export var devriye_hiz: float = 1.6
@export var ara_hiz: float = 2.8
@export var avla_hiz: float = 3.9
@export var gorus_menzil: float = 24.0
@export var gorus_aci: float = 0.40       # cos(esik) ~66 derece yari-aci

var _ap: AnimationPlayer
var _od: Node
var _player: Node3D
var _nav: Node
var _growl: AudioStreamPlayer3D
var _konus: AudioStreamPlayer3D     # canavar KONUSMASI (iblis ses, konumdan gelir)
var _konus_cd := 8.0                # ilk replige kadar bekleme
var _alt: Node

# Av sirasinda ara ara soylenen replikler (konum-bazli, uzun bekleme ile).
const AV_METIN := {
	"av1": "Neredesin? Kokunu aliyorum.",
	"av2": "Saklanmak seni kurtarmayacak.",
	"av3": "Daha hizli kos. Hadi, eglendir beni.",
	"av4": "Kalbini duyabiliyorum. Ne kadar da hizli atiyor.",
	"av5": "Geri gel buraya, seni lanet olasi.",
	"av6": "Bu duvarlar benim. Sen sadece... etsin.",
	"av7": "Yoruldugunu biliyorum. Dur biraz. Dur da seni yakalayayim.",
	"av8": "Bu sefer canin daha cok yanacak.",
}
var _av_adlar: Array = []

var _durum := "UYKU"
var _ev: Vector3
var _yol: PackedVector3Array = PackedVector3Array()
var _yol_i := 0
var _repath := 0.0
var _hedef: Vector3
var _gorus_zaman := -999.0
var _gorus_basla := -999.0
var _son_gorulen: Vector3
var _mesafe := 999.0
var _kesisme_cd := 6.0
var _kesisme_t := 0.0
var _growl_acik := false

func _ready() -> void:
	_ap = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap:
		var ad := animasyon
		if ad == "" or not _ap.has_animation(ad):
			var liste := _ap.get_animation_list()
			if not liste.is_empty(): ad = liste[0]
		if _ap.has_animation(ad): _ap.get_animation(ad).loop_mode = Animation.LOOP_LINEAR
		if ad != "": _ap.play(ad)
	_ev = global_position
	var s = load("res://audio/canavar_growl.wav")
	if s is AudioStreamWAV:
		s = s.duplicate(); s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0; s.loop_end = int(s.get_length() * s.mix_rate)
	_growl = AudioStreamPlayer3D.new()
	_growl.stream = s; _growl.pitch_scale = 0.85; _growl.unit_size = 9.0
	_growl.max_distance = 32.0; _growl.volume_db = 4.0
	add_child(_growl)
	# konusma kanali (iblis ses dosyalari, konumdan gelir)
	_konus = AudioStreamPlayer3D.new()
	_konus.unit_size = 14.0; _konus.max_distance = 40.0; _konus.volume_db = 6.0
	add_child(_konus)
	_av_adlar = AV_METIN.keys()
	_alt = get_node_or_null("/root/Altyazi")
	_od = get_node_or_null("/root/OyunDurumu")
	if _od: _od.canavar = self

func _physics_process(delta: float) -> void:
	if _od == null:
		_od = get_node_or_null("/root/OyunDurumu"); return
	if _player == null: _player = _od.oyuncu
	if _nav == null: _nav = _od.nav
	var avda: bool = bool(_od.av_modu) or bool(_od.alarm)
	if not avda or _player == null or _nav == null:
		_durum = "UYKU"
		if _growl_acik: _growl.stop(); _growl_acik = false
		if _ap: _ap.speed_scale = 1.0
		return
	_algi(delta)
	_karar(delta)
	_hareket(delta)
	_anim_ses()
	_konusma(delta)

# ----------------------------------------------------- ALGI
func _algi(delta: float) -> void:
	var simdi := float(Time.get_ticks_msec()) / 1000.0
	var goz := global_position + Vector3.UP * 1.5
	var hedef := _player.global_position + Vector3.UP * 1.0
	var d := goz.distance_to(hedef)
	_mesafe = d
	var ileri := -global_transform.basis.z
	var yon := (hedef - goz).normalized()
	var aci_ok := ileri.dot(yon) > gorus_aci or d < 3.5
	var los := _gorus_acik(goz, hedef)
	var alarm: bool = bool(_od.alarm)
	if (d < gorus_menzil and aci_ok and los) or alarm:
		if _gorus_zaman < simdi - 0.5: _gorus_basla = simdi
		_gorus_zaman = simdi
		_son_gorulen = _player.global_position
	# duyma: oyuncu gurultu yaricapi
	if d < float(_od.ses_yaricapi) + 1.0:
		_od.son_ses_konum = _player.global_position
		_od.son_ses_zaman = simdi

func _gorus_acik(a: Vector3, b: Vector3) -> bool:
	var uzay := get_world_3d().direct_space_state
	if uzay == null: return true
	var par := PhysicsRayQueryParameters3D.create(a, b)
	par.collide_with_areas = false
	var carp := uzay.intersect_ray(par)
	if carp.is_empty(): return true
	return carp.get("collider") == _player

# ----------------------------------------------------- KARAR
func _karar(delta: float) -> void:
	var simdi := float(Time.get_ticks_msec()) / 1000.0
	_kesisme_cd -= delta
	var gor := simdi - _gorus_zaman < 0.35
	if _durum == "KESISME":
		_kesisme_t -= delta
		if _kesisme_t <= 0.0 or _mesafe < 5.0: _durum = "AVLA"
		return
	if gor:
		# DENGELI KESISME: uzun suredir goruyor + uzakta + cooldown bitti -> bazen onunu kes
		if _kesisme_cd <= 0.0 and (simdi - _gorus_basla) > 2.5 and _mesafe > 7.0 and randf() < 0.5:
			_durum = "KESISME"; _kesisme_cd = 16.0; _kesisme_t = 4.0
		else:
			_durum = "AVLA"
	elif simdi - _gorus_zaman < 6.0:
		_durum = "ARA"
	elif simdi - float(_od.son_ses_zaman) < 4.0:
		_durum = "ARA"
	else:
		_durum = "DEVRIYE"

func _guncel_hedef() -> Vector3:
	match _durum:
		"AVLA": return _player.global_position
		"KESISME":
			var v: Vector3 = _player.velocity if _player is CharacterBody3D else Vector3.ZERO
			v.y = 0
			var lead := v.normalized() * 9.0 if v.length() > 0.3 else (_player.global_position - global_position).normalized() * 6.0
			return _player.global_position + lead
		"ARA":
			if Time.get_ticks_msec() / 1000.0 - float(_od.son_ses_zaman) < 4.0:
				return _od.son_ses_konum
			return _son_gorulen
		_:
			return _ev

# ----------------------------------------------------- HAREKET (yol takip)
func _hareket(delta: float) -> void:
	# SON YAKLASMA: cok yakinsa waypoint yerine dogrudan oyuncuya saldir (yakalamak icin)
	if (_durum == "AVLA" or _durum == "KESISME") and _player != null and _mesafe < 2.8:
		var dd := _player.global_position - global_position; dd.y = 0.0
		if dd.length() > 0.05:
			global_position += dd.normalized() * avla_hiz * delta
			var bk := Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
			if global_position.distance_to(bk) > 0.05: look_at(bk, Vector3.UP)
		return
	_repath -= delta
	if _durum == "DEVRIYE":
		if _yol_i >= _yol.size() or _yol.is_empty():
			_hedef = _nav.rastgele_yuru(_ev, 7)
			_yenile_yol()
	elif _repath <= 0.0:
		_hedef = _guncel_hedef()
		_yenile_yol()
		_repath = 0.4
	if _yol.is_empty() or _yol_i >= _yol.size(): return
	var hiz := devriye_hiz
	if _durum == "AVLA" or _durum == "KESISME": hiz = avla_hiz
	elif _durum == "ARA": hiz = ara_hiz
	var nokta: Vector3 = _yol[_yol_i]; nokta.y = global_position.y
	var d := nokta - global_position
	if d.length() < 0.6:
		_yol_i += 1
		return
	var adim := d.normalized() * hiz * delta
	global_position += adim
	var bak := global_position + Vector3(d.x, 0, d.z)
	if global_position.distance_to(bak) > 0.05:
		look_at(bak, Vector3.UP)

func _yenile_yol() -> void:
	_yol = _nav.yol(global_position, _hedef)
	_yol_i = 1 if _yol.size() > 1 else 0

# ----------------------------------------------------- ANIM + SES
func _anim_ses() -> void:
	var kov := _durum == "AVLA" or _durum == "KESISME"
	if _ap: _ap.speed_scale = 1.7 if kov else (1.2 if _durum == "ARA" else 1.0)
	var sesli := kov or _mesafe < 8.0
	if sesli and not _growl_acik:
		_growl.play(); _growl_acik = true
	elif not sesli and _growl_acik:
		_growl.stop(); _growl_acik = false

# ----------------------------------------------------- KONUSMA (iblis ses, ara ara)
func _konusma(delta: float) -> void:
	_konus_cd -= delta
	if _konus_cd > 0.0 or (_konus and _konus.playing): return
	if _player == null or _mesafe > 26.0: return       # cok uzaksa konusmaz
	# kovalarken daha sik/yakin konusur; ararken seyrek
	var kov := _durum == "AVLA" or _durum == "KESISME"
	if not kov and randf() < 0.5: return
	var ad: String = _av_adlar[randi() % _av_adlar.size()]
	var s = load("res://audio/canavar/" + ad + ".wav")
	if s == null: return
	_konus.stream = s
	_konus.play()
	if _alt: _alt.call("goster", AV_METIN[ad], 3.4)
	_konus_cd = randf_range(15.0, 26.0) if kov else randf_range(22.0, 34.0)

# Sinematik tarafindan cagrilir: canavari belli konuma anlik koy (kovalamadan)
func sinematik_yerlestir(p: Vector3, bak: Vector3) -> void:
	global_position = p
	var hedef := Vector3(bak.x, p.y, bak.z)
	if p.distance_to(hedef) > 0.05: look_at(hedef, Vector3.UP)

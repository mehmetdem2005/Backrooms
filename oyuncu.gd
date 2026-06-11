extends CharacterBody3D
## FPS oyuncu (Faz 3): yurume/KOSU(stamina)/EGILME/SESSIZ, nefes+kalp sesleri, stamina HUD,
## FENER + PIL sistemi (#8), MOBIL dokunmatik kontroller (#7), alarm + canavar yakalanma aksiyonu.
## PC: fare=bakis, WASD, Shift=kos, Ctrl/C=egil, Alt=sessiz, Space=zipla, F=fener, G=ALARM(test), E=etkilesim.
## Mobil: sol joystick=hareket, sag ekran=bakis, butonlar=kos/egil/zipla/fener/alarm.

@export var yuru: float = 3.6
@export var kosu: float = 6.6
@export var egil_hiz: float = 1.9
@export var sessiz_hiz: float = 2.1
@export var ziplama: float = 4.2
@export var fare_hassas: float = 0.0025
@export var dokunmatik_hassas: float = 0.004
@export var fener_sarj_max: float = 100.0
@export var fener_tuketim: float = 3.5     # %/sn
@export var pil_dolum: float = 55.0        # toplaninca +%

const STAM_MAX := 100.0
const STAM_DRAIN := 22.0
const STAM_REGEN := 14.0

var stamina := STAM_MAX
var _bitkin := false
var _egik := false
var _g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _kam: Camera3D
var _cs: CollisionShape3D
var _fener: SpotLight3D
var _eforlu := false
var _od: Node = null

# fener / pil
var _fener_sarj := 100.0
var _fener_acik := false
var _fener_taban_enerji := 2.0
var _flicker := 0.0

# ses
var _nefes: AudioStreamPlayer
var _kalp: AudioStreamPlayer
var _alarm: AudioStreamPlayer
var _shout: AudioStreamPlayer
var _nefes_normal: AudioStream
var _nefes_agir: AudioStream
var _nefes_agir_acik := false

# hud
var _stam_dolu: ColorRect
var _bat_dolu: ColorRect
var _vignette: ColorRect
var _alarm_lbl: Label
var _alarm_yaniyor := false
var _alarm_faz := 0.0
var _olu := false

# mobil
var _mobil := false
var _joy_idx := -1
var _joy_mer := Vector2.ZERO
var _joy_yari := 90.0
var _joy_vec := Vector2.ZERO
var _bak_idx := -1
var _mobil_bak := Vector2.ZERO
var _m_kos := false
var _m_egil := false
var _m_zipla := false
var _joy_knob: ColorRect
var _buton_alani: Array = []

func _ready() -> void:
	_kam = $Kamera
	_cs = $CollisionShape3D
	_fener = $Kamera/Fener
	_fener_taban_enerji = _fener.light_energy
	_fener.visible = false
	_od = get_node_or_null("/root/OyunDurumu")
	if _od:
		_od.oyuncu = self
		_od.alarm_basladi.connect(_alarm_basla)
		_od.alarm_bitti.connect(_alarm_bit)
		_od.yakalandi_sinyal.connect(_yakalandi)
	_mobil = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _mobil else Input.MOUSE_MODE_CAPTURED
	_ses_kur()
	_hud_kur()
	if _mobil:
		_mobil_kur()

func _loop_stream(yol: String) -> AudioStream:
	var s = load(yol)
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	return s

func _player(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new(); a.stream = stream; a.volume_db = db
	add_child(a); return a

func _ses_kur() -> void:
	_nefes_normal = _loop_stream("res://audio/nefes_normal.wav")
	_nefes_agir = _loop_stream("res://audio/nefes_agir.wav")
	_nefes = _player(_nefes_normal, -14.0)
	_kalp = _player(_loop_stream("res://audio/kalp.wav"), -40.0)
	_alarm = _player(_loop_stream("res://audio/alarm.wav"), -6.0)
	_shout = _player(load("res://audio/bagir.wav"), -2.0)
	_nefes.play(); _kalp.play()

# ----------------------------------------------------- HUD
func _bar(cl: CanvasLayer, y_ofs: int, renk: Color) -> ColorRect:
	var arka := ColorRect.new(); arka.color = Color(0, 0, 0, 0.55)
	arka.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	arka.position = Vector2(24, y_ofs - 2); arka.size = Vector2(208, 18); cl.add_child(arka)
	var dolu := ColorRect.new(); dolu.color = renk
	dolu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	dolu.position = Vector2(26, y_ofs); dolu.size = Vector2(204, 14); cl.add_child(dolu)
	return dolu

func _hud_kur() -> void:
	var cl := CanvasLayer.new(); cl.name = "HUD"; add_child(cl)
	_vignette = ColorRect.new()
	_vignette.color = Color(0.55, 0.0, 0.0, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_vignette)
	_stam_dolu = _bar(cl, -42, Color(0.4, 0.85, 1.0, 0.9))   # stamina
	_bat_dolu = _bar(cl, -66, Color(1.0, 0.85, 0.2, 0.9))    # fener pili
	var lbl := Label.new(); lbl.text = "STAMINA"; lbl.position = Vector2(236, 0)
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); lbl.position = Vector2(236, -44)
	lbl.add_theme_font_size_override("font_size", 11); cl.add_child(lbl)
	var lbl2 := Label.new(); lbl2.text = "PIL"
	lbl2.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); lbl2.position = Vector2(236, -68)
	lbl2.add_theme_font_size_override("font_size", 11); cl.add_child(lbl2)
	_alarm_lbl = Label.new()
	_alarm_lbl.text = "ALARM - KAC!"
	_alarm_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alarm_lbl.position = Vector2(-90, 30)
	_alarm_lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.15))
	_alarm_lbl.add_theme_font_size_override("font_size", 26)
	_alarm_lbl.visible = false
	cl.add_child(_alarm_lbl)

# ----------------------------------------------------- MOBIL UI
func _mobil_kur() -> void:
	var cl := CanvasLayer.new(); cl.name = "Mobil"; add_child(cl)
	var ekran := get_viewport().get_visible_rect().size
	_joy_mer = Vector2(140, ekran.y - 140)
	var taban := ColorRect.new(); taban.color = Color(1, 1, 1, 0.10)
	taban.size = Vector2(_joy_yari * 2, _joy_yari * 2); taban.position = _joy_mer - Vector2(_joy_yari, _joy_yari)
	taban.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(taban)
	_joy_knob = ColorRect.new(); _joy_knob.color = Color(1, 1, 1, 0.28)
	_joy_knob.size = Vector2(54, 54); _joy_knob.position = _joy_mer - Vector2(27, 27)
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(_joy_knob)
	# butonlar (sag-alt)
	_mobil_buton(cl, "KOS", Vector2(ekran.x - 110, ekran.y - 220), func(b): _m_kos = b, true)
	_mobil_buton(cl, "EGIL", Vector2(ekran.x - 220, ekran.y - 140), func(b): _m_egil = b, true)
	_mobil_buton(cl, "ZIP", Vector2(ekran.x - 110, ekran.y - 140), func(_b): _m_zipla = true, false)
	_mobil_buton(cl, "FENER", Vector2(ekran.x - 110, ekran.y - 300), func(_b): _fener_ac_kapa(), false)
	_mobil_buton(cl, "ALARM", Vector2(ekran.x - 220, ekran.y - 300), func(_b): _mobil_alarm(), false)

func _mobil_alarm() -> void:
	if _od: _od.alarmi_baslat()

func _mobil_buton(cl: CanvasLayer, yazi: String, pos: Vector2, geri: Callable, tut: bool) -> void:
	var b := Button.new(); b.text = yazi; b.position = pos; b.size = Vector2(96, 70)
	b.add_theme_font_size_override("font_size", 18)
	cl.add_child(b)
	_buton_alani.append(Rect2(pos, b.size))
	if tut:
		b.button_down.connect(func(): geri.call(true))
		b.button_up.connect(func(): geri.call(false))
	else:
		b.pressed.connect(func(): geri.call(true))

func _buton_ustunde(p: Vector2) -> bool:
	for r in _buton_alani:
		if (r as Rect2).has_point(p): return true
	return false

# ----------------------------------------------------- GIRDI
func _unhandled_input(olay: InputEvent) -> void:
	if _od and _od.sinematik: return
	if olay is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-olay.relative.x * fare_hassas)
		_kam.rotate_x(-olay.relative.y * fare_hassas)
		_kam.rotation.x = clampf(_kam.rotation.x, -1.4, 1.4)
	elif olay is InputEventKey and olay.pressed and not olay.echo:
		if olay.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif olay.keycode == KEY_F:
			_fener_ac_kapa()
		elif olay.keycode == KEY_G and _od:
			_od.alarmi_baslat()
	# mobil dokunma (joystick + bakis)
	elif _mobil and olay is InputEventScreenTouch:
		var st := olay as InputEventScreenTouch
		if st.pressed:
			if st.position.x < get_viewport().get_visible_rect().size.x * 0.45 and _joy_idx == -1:
				_joy_idx = st.index; _joy_mer = st.position
				if _joy_knob: _joy_knob.position = _joy_mer - Vector2(27, 27)
			elif not _buton_ustunde(st.position) and _bak_idx == -1:
				_bak_idx = st.index
		else:
			if st.index == _joy_idx:
				_joy_idx = -1; _joy_vec = Vector2.ZERO
				if _joy_knob: _joy_knob.position = _joy_mer - Vector2(27, 27)
			elif st.index == _bak_idx:
				_bak_idx = -1
	elif _mobil and olay is InputEventScreenDrag:
		var sd := olay as InputEventScreenDrag
		if sd.index == _joy_idx:
			var d := sd.position - _joy_mer
			if d.length() > _joy_yari: d = d.normalized() * _joy_yari
			_joy_vec = d / _joy_yari
			if _joy_knob: _joy_knob.position = _joy_mer + d - Vector2(27, 27)
		elif sd.index == _bak_idx:
			_mobil_bak += sd.relative

# ----------------------------------------------------- HAREKET
func _physics_process(delta: float) -> void:
	if _olu or (_od and _od.sinematik):
		return
	# mobil bakis uygula
	if _mobil and _mobil_bak != Vector2.ZERO:
		rotate_y(-_mobil_bak.x * dokunmatik_hassas)
		_kam.rotate_x(-_mobil_bak.y * dokunmatik_hassas)
		_kam.rotation.x = clampf(_kam.rotation.x, -1.4, 1.4)
		_mobil_bak = Vector2.ZERO

	if not is_on_floor():
		velocity.y -= _g * delta
	if (Input.is_action_pressed("atla") or _m_zipla) and is_on_floor() and not _egik:
		velocity.y = ziplama
	_m_zipla = false

	var giris := Vector2(
		Input.get_action_strength("sag") - Input.get_action_strength("sol"),
		Input.get_action_strength("geri") - Input.get_action_strength("ileri"))
	giris += Vector2(_joy_vec.x, _joy_vec.y)
	if giris.length() > 1.0: giris = giris.normalized()
	var yon := (transform.basis * Vector3(giris.x, 0, giris.y))
	yon.y = 0; yon = yon.normalized()
	var hareket_var := giris.length() > 0.15

	_egik = Input.is_action_pressed("egil") or _m_egil
	var sessiz := Input.is_action_pressed("sessiz")
	var kos_istek := (Input.is_action_pressed("kos") or _m_kos) and hareket_var and not _egik and not sessiz and not _bitkin
	_eforlu = kos_istek

	var hiz := yuru
	if _egik: hiz = egil_hiz
	elif sessiz: hiz = sessiz_hiz
	elif kos_istek: hiz = kosu

	if kos_istek:
		stamina = max(0.0, stamina - STAM_DRAIN * delta)
		if stamina <= 0.0: _bitkin = true
	else:
		stamina = min(STAM_MAX, stamina + STAM_REGEN * delta)
		if _bitkin and stamina > 30.0: _bitkin = false

	if _od:
		_od.ses_yaricapi = (10.0 if kos_istek else (2.0 if _egik else (3.0 if sessiz else 6.0)))

	velocity.x = yon.x * hiz
	velocity.z = yon.z * hiz
	move_and_slide()

	_egilme_uygula(delta)
	_fener_guncelle(delta)
	_pil_kontrol()
	_ses_guncelle(delta)
	_hud_guncelle(delta)
	_canavar_kontrol()

func _egilme_uygula(delta: float) -> void:
	var hedef_kam := 1.0 if _egik else 1.6
	_kam.position.y = lerpf(_kam.position.y, hedef_kam, 10.0 * delta)
	if _cs and _cs.shape is CapsuleShape3D:
		var cap := _cs.shape as CapsuleShape3D
		var hedef_h := 1.1 if _egik else 1.7
		cap.height = lerpf(cap.height, hedef_h, 10.0 * delta)
		_cs.position.y = cap.height * 0.5

# ----------------------------------------------------- FENER + PIL
func _fener_ac_kapa() -> void:
	if not _fener_acik and _fener_sarj > 1.0:
		_fener_acik = true
	else:
		_fener_acik = false
	_fener.visible = _fener_acik

func _fener_guncelle(delta: float) -> void:
	if _fener_acik:
		_fener_sarj = max(0.0, _fener_sarj - fener_tuketim * delta)
		if _fener_sarj <= 0.0:
			_fener_acik = false; _fener.visible = false
		elif _fener_sarj < 20.0:                      # zayif pil: titreme + kisilma
			_flicker += delta * 18.0
			var t := 0.45 + 0.55 * (0.5 + 0.5 * sin(_flicker)) * (_fener_sarj / 20.0)
			_fener.light_energy = _fener_taban_enerji * t
		else:
			_fener.light_energy = _fener_taban_enerji

func _pil_kontrol() -> void:
	for p in get_tree().get_nodes_in_group("pil"):
		if p is Node3D and global_position.distance_to((p as Node3D).global_position) < 1.6:
			_fener_sarj = min(fener_sarj_max, _fener_sarj + pil_dolum)
			p.queue_free()

# ----------------------------------------------------- SES
func _ses_guncelle(delta: float) -> void:
	var alarm_aktif := _od != null and bool(_od.alarm)
	var agir := _eforlu or stamina < 35.0 or _bitkin or alarm_aktif
	if agir != _nefes_agir_acik:
		_nefes_agir_acik = agir
		_nefes.stream = _nefes_agir if agir else _nefes_normal
		_nefes.play()
	_nefes.volume_db = lerpf(_nefes.volume_db, (-6.0 if agir else -16.0), 4.0 * delta)
	var hedef_kalp := -42.0
	if _eforlu or stamina < 30.0: hedef_kalp = -18.0
	if alarm_aktif: hedef_kalp = -6.0
	if _od and _od.canavar:
		var d: float = global_position.distance_to((_od.canavar as Node3D).global_position)
		if d < 18.0: hedef_kalp = maxf(hedef_kalp, lerpf(-4.0, -22.0, clampf(d / 18.0, 0, 1)))
	_kalp.volume_db = lerpf(_kalp.volume_db, hedef_kalp, 3.0 * delta)
	_kalp.pitch_scale = lerpf(_kalp.pitch_scale, (1.5 if alarm_aktif else 1.0), 2.0 * delta)

# ----------------------------------------------------- HUD GUNCELLE
func _hud_guncelle(delta: float) -> void:
	if _stam_dolu:
		_stam_dolu.size.x = 204.0 * (stamina / STAM_MAX)
		_stam_dolu.color = Color(1.0, 0.4, 0.2, 0.9) if _bitkin else Color(0.4, 0.85, 1.0, 0.9)
	if _bat_dolu:
		_bat_dolu.size.x = 204.0 * (_fener_sarj / fener_sarj_max)
		_bat_dolu.color = Color(1.0, 0.3, 0.15, 0.9) if _fener_sarj < 20.0 else Color(1.0, 0.85, 0.2, 0.9)
	if _alarm_yaniyor and _vignette:
		_alarm_faz += delta * 6.0
		_vignette.color.a = 0.18 + 0.16 * (0.5 + 0.5 * sin(_alarm_faz))

# ----------------------------------------------------- ALARM / YAKALANMA
func _alarm_basla() -> void:
	_alarm_yaniyor = true
	if _alarm_lbl: _alarm_lbl.visible = true
	if _alarm and not _alarm.playing: _alarm.play()
	if _shout: _shout.play()

func _alarm_bit() -> void:
	_alarm_yaniyor = false
	if _alarm_lbl: _alarm_lbl.visible = false
	if _alarm: _alarm.stop()
	if _vignette: _vignette.color.a = 0.0

func _canavar_kontrol() -> void:
	if _olu or not _od or _od.canavar == null: return
	var b: Vector3 = (_od.canavar as Node3D).global_position
	var yatay := Vector2(global_position.x - b.x, global_position.z - b.z).length()
	if yatay < 1.5:
		_od.yakalandi()

func _yakalandi() -> void:
	if _olu: return
	_olu = true
	if _vignette: _vignette.color = Color(0, 0, 0, 1.0)
	var a := _player(load("res://audio/yakalandi.wav"), 0.0); a.play()
	await get_tree().create_timer(2.2).timeout
	_olu = false
	if _vignette: _vignette.color = Color(0.55, 0, 0, 0.0)
	if _od: _od.alarmi_durdur()
	stamina = STAM_MAX
	velocity = Vector3.ZERO

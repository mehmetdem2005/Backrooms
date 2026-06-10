extends CharacterBody3D
## FPS oyuncu (Faz 3): yurume / KOSU(stamina) / EGILME(sessiz,alcak) / SESSIZ yurume,
## nefes + kalp atisi sesleri, stamina HUD, alarm + yakalanma (canavar aksiyonu).
## Fare=bakis, WASD=hareket, Shift=kos, Ctrl/C=egil, Alt=sessiz, Space=zipla, F=fener, G=ALARM(test).

@export var yuru: float = 3.6
@export var kosu: float = 6.6
@export var egil_hiz: float = 1.9
@export var sessiz_hiz: float = 2.1
@export var ziplama: float = 4.2
@export var fare_hassas: float = 0.0025

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

var _nefes: AudioStreamPlayer
var _kalp: AudioStreamPlayer
var _alarm: AudioStreamPlayer
var _shout: AudioStreamPlayer
var _nefes_normal: AudioStream
var _nefes_agir: AudioStream
var _nefes_agir_acik := false

var _stam_dolu: ColorRect
var _vignette: ColorRect
var _alarm_lbl: Label
var _alarm_yaniyor := false
var _alarm_faz := 0.0
var _olu := false
var _od: Node = null

func _ready() -> void:
	_kam = $Kamera
	_cs = $CollisionShape3D
	_fener = $Kamera/Fener
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_od = get_node_or_null("/root/OyunDurumu")
	if _od:
		_od.oyuncu = self
		_od.alarm_basladi.connect(_alarm_basla)
		_od.alarm_bitti.connect(_alarm_bit)
		_od.yakalandi_sinyal.connect(_yakalandi)
	_ses_kur()
	_hud_kur()

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

func _hud_kur() -> void:
	var cl := CanvasLayer.new(); add_child(cl)
	_vignette = ColorRect.new()
	_vignette.color = Color(0.55, 0.0, 0.0, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_vignette)
	var arka := ColorRect.new()
	arka.color = Color(0, 0, 0, 0.55)
	arka.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	arka.position = Vector2(24, -42); arka.size = Vector2(208, 18)
	cl.add_child(arka)
	_stam_dolu = ColorRect.new()
	_stam_dolu.color = Color(0.4, 0.85, 1.0, 0.9)
	_stam_dolu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stam_dolu.position = Vector2(26, -40); _stam_dolu.size = Vector2(204, 14)
	cl.add_child(_stam_dolu)
	_alarm_lbl = Label.new()
	_alarm_lbl.text = "ALARM - KAC!"
	_alarm_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alarm_lbl.position = Vector2(-90, 30)
	_alarm_lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.15))
	_alarm_lbl.add_theme_font_size_override("font_size", 26)
	_alarm_lbl.visible = false
	cl.add_child(_alarm_lbl)

func _unhandled_input(olay: InputEvent) -> void:
	if olay is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-olay.relative.x * fare_hassas)
		_kam.rotate_x(-olay.relative.y * fare_hassas)
		_kam.rotation.x = clampf(_kam.rotation.x, -1.4, 1.4)
	elif olay is InputEventKey and olay.pressed and not olay.echo:
		if olay.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif olay.keycode == KEY_F:
			_fener.visible = not _fener.visible
		elif olay.keycode == KEY_G:
			_od.alarmi_baslat()

func _physics_process(delta: float) -> void:
	if _olu:
		return
	if not is_on_floor():
		velocity.y -= _g * delta
	if Input.is_action_pressed("atla") and is_on_floor() and not _egik:
		velocity.y = ziplama

	var giris := Vector2(
		Input.get_action_strength("sag") - Input.get_action_strength("sol"),
		Input.get_action_strength("geri") - Input.get_action_strength("ileri"))
	var yon := (transform.basis * Vector3(giris.x, 0, giris.y))
	yon.y = 0; yon = yon.normalized()
	var hareket_var := giris.length() > 0.1

	_egik = Input.is_action_pressed("egil")
	var sessiz := Input.is_action_pressed("sessiz")
	var kos_istek := Input.is_action_pressed("kos") and hareket_var and not _egik and not sessiz and not _bitkin
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
	if _od and _od.alarm: hedef_kalp = -6.0
	if _od and _od.canavar:
		var d := global_position.distance_to(_od.canavar.global_position)
		if d < 18.0: hedef_kalp = maxf(hedef_kalp, lerpf(-4.0, -22.0, clampf(d / 18.0, 0, 1)))
	_kalp.volume_db = lerpf(_kalp.volume_db, hedef_kalp, 3.0 * delta)
	_kalp.pitch_scale = lerpf(_kalp.pitch_scale, (1.5 if (_od and _od.alarm) else 1.0), 2.0 * delta)

func _hud_guncelle(delta: float) -> void:
	if _stam_dolu:
		_stam_dolu.size.x = 204.0 * (stamina / STAM_MAX)
		_stam_dolu.color = Color(1.0, 0.4, 0.2, 0.9) if _bitkin else Color(0.4, 0.85, 1.0, 0.9)
	if _alarm_yaniyor and _vignette:
		_alarm_faz += delta * 6.0
		_vignette.color.a = 0.18 + 0.16 * (0.5 + 0.5 * sin(_alarm_faz))

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
	if global_position.distance_to(_od.canavar.global_position) < 1.4:
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

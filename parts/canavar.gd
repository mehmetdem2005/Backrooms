extends Node3D
## Canavar - animasyonlu + ALARM aksiyonu (Faz 3).
## Normalde idle/dolanma animasyonu oynar. OyunDurumu.alarm aktif olunca oyuncuyu KOVALAR:
## ona dogru ilerler (basit duvar kacinmali), yuzunu doner, hizli animasyon + hirilti calar.
## (Tam navmesh yol bulma Faz 4'te eklenecek.)

@export var animasyon: String = "NlaTrack_009"
@export var dongusel: bool = true
@export var hiz: float = 1.0
@export var kovalama_hiz: float = 3.4      # m/s kovalarken

var _ap: AnimationPlayer
var _oyuncu: Node3D
var _kovaliyor := false
var _growl: AudioStreamPlayer3D

func _ready() -> void:
	_ap = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap:
		var ad := animasyon
		if ad == "" or not _ap.has_animation(ad):
			var liste := _ap.get_animation_list()
			if not liste.is_empty(): ad = liste[0]
		if dongusel and _ap.has_animation(ad):
			_ap.get_animation(ad).loop_mode = Animation.LOOP_LINEAR
		_ap.speed_scale = hiz
		if ad != "": _ap.play(ad)
	# hirilti (konumlu, gercek canavar sesi - dongu)
	var s = load("res://audio/canavar_growl.wav")
	if s is AudioStreamWAV:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0; s.loop_end = int(s.get_length() * s.mix_rate)
	_growl = AudioStreamPlayer3D.new()
	_growl.stream = s; _growl.pitch_scale = 0.85; _growl.unit_size = 8.0
	_growl.max_distance = 30.0; _growl.volume_db = 4.0
	add_child(_growl)
	if Engine.has_singleton("OyunDurumu") or get_node_or_null("/root/OyunDurumu"):
		get_node("/root/OyunDurumu").canavar = self

func _physics_process(delta: float) -> void:
	var od := get_node_or_null("/root/OyunDurumu")
	if od == null: return
	if _oyuncu == null:
		_oyuncu = od.oyuncu
		return
	var alarm: bool = od.alarm
	if alarm and not _kovaliyor:
		_kovaliyor = true
		if _growl and not _growl.playing: _growl.play()
		if _ap: _ap.speed_scale = 1.7
	elif not alarm and _kovaliyor:
		_kovaliyor = false
		if _growl: _growl.stop()
		if _ap: _ap.speed_scale = hiz

	if not _kovaliyor:
		return

	var hedef := _oyuncu.global_position
	var d := hedef - global_position; d.y = 0.0
	var mesafe := d.length()
	if mesafe > 1.2:
		var yon := d.normalized()
		# basit duvar kacinma: onumuz kapaliysa yana kay
		if _engel_var(yon):
			var sag := Vector3(yon.z, 0, -yon.x)
			yon = sag if not _engel_var(sag) else -sag
		var yeni := global_position + yon * kovalama_hiz * delta
		yeni.y = global_position.y
		global_position = yeni
		var bak := Vector3(hedef.x, global_position.y, hedef.z)
		if global_position.distance_to(bak) > 0.05:
			look_at(bak, Vector3.UP)

func _engel_var(yon: Vector3) -> bool:
	var uzay := get_world_3d().direct_space_state
	if uzay == null: return false
	var bas := global_position + Vector3(0, 1.0, 0)
	var par := PhysicsRayQueryParameters3D.create(bas, bas + yon * 1.2)
	par.exclude = [self]
	var carp := uzay.intersect_ray(par)
	return not carp.is_empty()

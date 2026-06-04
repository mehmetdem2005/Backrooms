extends Node3D
## Canavar (alien yaratik) - yerlestirilebilir + animasyonlu.
## GLB icindeki AnimationPlayer'i bulup secilen animasyonu donguyle oynatir.
## 11 animasyon var (NlaTrack .. NlaTrack_010); Inspector'dan degistirilebilir.

## Oynatilacak animasyon (bos = ilk bulunan). Uzunlar genelde dolanma/idle:
## NlaTrack_009=15.4s, NlaTrack_004=10.8s, NlaTrack_002=8.5s
@export var animasyon: String = "NlaTrack_009"
@export var dongusel: bool = true
@export var hiz: float = 1.0

func _ready() -> void:
	var ap := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	var ad := animasyon
	if ad == "" or not ap.has_animation(ad):
		var liste := ap.get_animation_list()
		if liste.is_empty():
			return
		ad = liste[0]
	if dongusel:
		var an := ap.get_animation(ad)
		if an:
			an.loop_mode = Animation.LOOP_LINEAR
	ap.speed_scale = hiz
	ap.play(ad)

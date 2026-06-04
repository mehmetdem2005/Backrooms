extends Node3D
## Acilabilir sci-fi kapi.
## Cerceve sabittir; "Mente" dugumu menteseden (SAG kenar, kol karsisi) doner.
## Kullanim:  $Kapi.ac()  /  .kapat()  /  .degistir()

@export var acik: bool = false          ## baslangicta acik mi
@export var acilma_acisi: float = 100.0 ## derece cinsinden acilma miktari
@export var sure: float = 0.6           ## animasyon suresi (saniye)

@onready var _mente: Node3D = $Mente
var _kapali_y: float = 0.0
var _tween: Tween

func _ready() -> void:
	_kapali_y = _mente.rotation.y
	if acik:
		_mente.rotation.y = _kapali_y + deg_to_rad(acilma_acisi)

func ac() -> void:
	_hedefe_git(true)

func kapat() -> void:
	_hedefe_git(false)

func degistir() -> void:
	_hedefe_git(not acik)

func _hedefe_git(yeni_durum: bool) -> void:
	acik = yeni_durum
	var hedef: float = _kapali_y + deg_to_rad(acilma_acisi) if acik else _kapali_y
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_mente, "rotation:y", hedef, sure)

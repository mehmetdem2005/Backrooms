extends Node
## CHUNK YONETICISI (Faz 2 performans #2)
## Yapi/Objeler/Isiklar/Lekeler dugumlerini uzaysal "chunk"lara boler; oyuncuya yakin
## chunklari GORUNUR (render+isik acik), uzaktakileri GIZLER. Carpisma her zaman aktif
## kalir (visible fiziki etkilemez) -> dusme yok. Sadece oyuncu chunk degistirince guncellenir.

@export var oyuncu_yolu: NodePath = ^"../Oyuncu"
@export var chunk: float = 14.0       # chunk kenari (m)
@export var yaricap: int = 3          # aktif chunk yaricapi (chunk biriminde) -> (2*r+1)^2 chunk

var _oyuncu: Node3D
var _chunklar: Dictionary = {}        # Vector2i -> Array[Node3D]
var _aktif: Dictionary = {}           # Vector2i -> true
var _son := Vector2i(2147483647, 2147483647)

func _key(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / chunk)), int(floor(p.z / chunk)))

func _ready() -> void:
	_oyuncu = get_node_or_null(oyuncu_yolu) as Node3D
	var kok := get_parent()
	for grup_ad in ["Yapi", "Objeler", "Isiklar", "Lekeler"]:
		var g := kok.get_node_or_null(grup_ad)
		if g == null:
			continue
		for c in g.get_children():
			if c is Node3D:
				var k := _key((c as Node3D).global_position)
				if not _chunklar.has(k):
					_chunklar[k] = []
				_chunklar[k].append(c)
				(c as Node3D).visible = false   # baslangicta gizle; _guncelle acar
	set_physics_process(_oyuncu != null)

func _physics_process(_d: float) -> void:
	var k := _key(_oyuncu.global_position)
	if k == _son:
		return
	_son = k
	var yeni := {}
	for dx in range(-yaricap, yaricap + 1):
		for dz in range(-yaricap, yaricap + 1):
			yeni[Vector2i(k.x + dx, k.y + dz)] = true
	for ck in yeni:                       # yeni gorunenleri ac
		if not _aktif.has(ck) and _chunklar.has(ck):
			for n in _chunklar[ck]:
				n.visible = true
	for ck in _aktif:                     # menzilden cikani gizle
		if not yeni.has(ck) and _chunklar.has(ck):
			for n in _chunklar[ck]:
				n.visible = false
	_aktif = yeni

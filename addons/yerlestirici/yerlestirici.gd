@tool
extends EditorPlugin
## PARÇA YERLEŞTİRİCİ — profesyonel harita kurma aracı (Godot 4.6 uyumlu).
##
## Harita içeriğini SEN yaparsın; bu eklenti yalnızca araçtır, hiçbir doku/parça üretmez.
##
## • OTOMATİK KEŞİF: parts/ klasörüne .tscn at → otomatik listelenir (🔄 ile yenile).
## • OTOMATİK TÜR: zemin/tavan (yatay) / duvar (dikey panel), mesh'in ince ekseninden.
## • KATEGORİLİ DOCK: Zeminler / Duvarlar / Tavanlar, büyük dokunmatik düğmeler.
## • SİSTEMATİK IZGARA: zemin/tavan hücre merkezi, duvar karo kenarı; ölçekle büyür.
## • HIZLI KURMA: sürükle = seri, R = 90° döndür, [ ] = yükseklik, snap aç/kapa.
## • HARİTA YÖNETİMİ: grup (oda/kat) altına toplama, grubu/tümünü temizle, sayaç, undo.

const IZGARA: float = 4.0
const PARCA_KLASORU := "res://parts/"
const GRUP_META := "parca_grubu"
const PARCA_META := "yp"
const YUK_ADIM := 0.5

var parcalar: Dictionary = {}     # ad -> {yol, ikon, eksen, kal, yuk}
var _panel: YerlestirmePanel
var _dock: ScrollContainer
var _son_secilen: String = ""
var _basili: bool = false
var _son_hucre: Vector3 = Vector3(INF, INF, INF)

func _enter_tree() -> void:
	_parcalari_tara()
	_paneli_kur()

func _exit_tree() -> void:
	_panel_kaldir()

# ---------------------------------------------------------------- Panel / dock
func _paneli_kur() -> void:
	_panel = YerlestirmePanel.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.kur(parcalar)
	_panel.yenile_istendi.connect(_parcalari_yenile)
	_panel.grubu_temizle_istendi.connect(_grubu_temizle)
	_panel.tumunu_temizle_istendi.connect(_tumunu_temizle)
	_panel.son_parca_istendi.connect(_son_parcayi_sec)
	_panel.parca_secildi.connect(func(ad): _son_secilen = ad)
	_dock = ScrollContainer.new()
	_dock.name = "Yerleştirici"
	_dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dock.add_child(_panel)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BR, _dock)
	_sayaci_guncelle()

func _panel_kaldir() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	_panel = null

func _parcalari_yenile() -> void:
	var onceki := _panel.secili_ad if _panel else ""
	_parcalari_tara()
	_panel_kaldir()
	_paneli_kur()
	if onceki != "" and parcalar.has(onceki) and _panel:
		_panel.parca_sec(onceki)

# ---------------------------------------------------------------- Keşif
func _parcalari_tara() -> void:
	parcalar.clear()
	var d := DirAccess.open(PARCA_KLASORU)
	if d == null:
		push_warning("Yerleştirici: parça klasörü yok: " + PARCA_KLASORU)
		return
	var dosyalar: Array[String] = []
	d.list_dir_begin()
	var dosya := d.get_next()
	while dosya != "":
		if not d.current_is_dir() and dosya.get_extension().to_lower() == "tscn":
			dosyalar.append(dosya)
		dosya = d.get_next()
	d.list_dir_end()
	dosyalar.sort()
	for f in dosyalar:
		var yol := PARCA_KLASORU + f
		parcalar[f.get_basename()] = _parca_coz(yol, f.get_basename())

func _parca_coz(yol: String, gad: String) -> Dictionary:
	var bilgi := {"yol": yol, "ikon": "", "eksen": "y", "kal": 0.12, "yuk": 0.0}
	var ps := load(yol) as PackedScene
	if ps == null:
		push_warning("Yerleştirici: yüklenemedi: " + yol)
		return bilgi
	var inst := ps.instantiate()
	if inst == null:
		return bilgi
	var mi := _mesh_bul(inst)
	if mi != null and mi.mesh != null:
		var sz: Vector3 = mi.mesh.get_aabb().size
		if sz.y <= sz.x and sz.y <= sz.z:
			bilgi.eksen = "y"; bilgi.kal = sz.y
		elif sz.x <= sz.z:
			bilgi.eksen = "x"; bilgi.kal = sz.x
		else:
			bilgi.eksen = "z"; bilgi.kal = sz.z
		var mat: Material = mi.get_surface_override_material(0)
		if mat == null:
			mat = mi.mesh.surface_get_material(0)
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
			bilgi.ikon = (mat as StandardMaterial3D).albedo_texture.resource_path
	if gad.to_lower().contains("tavan"):
		bilgi.yuk = 3.0
	inst.free()
	return bilgi

# ---------------------------------------------------------------- 3B giriş
func _handles(_o: Object) -> bool:
	return _panel != null and _panel.mod != "yok"

func _forward_3d_gui_input(kamera: Camera3D, olay: InputEvent) -> int:
	if _panel == null or _panel.mod == "yok":
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	# Klavye kısayolları (koy modu)
	if _panel.mod == "koy" and olay is InputEventKey and olay.pressed and not olay.echo:
		match olay.keycode:
			KEY_R:
				_panel.donme_ayarla(_panel.donme() + 90.0)
				_panel.durum_yaz("Döndürme: %d°" % int(_panel.donme()))
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			KEY_BRACKETRIGHT:
				_panel.yukseklik_ayarla(_panel.yukseklik() + YUK_ADIM)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			KEY_BRACKETLEFT:
				_panel.yukseklik_ayarla(_panel.yukseklik() - YUK_ADIM)
				return EditorPlugin.AFTER_GUI_INPUT_STOP

	if olay is InputEventMouseButton and olay.button_index == MOUSE_BUTTON_LEFT:
		if olay.pressed:
			_basili = true
			_son_hucre = Vector3(INF, INF, INF)
			_islem(kamera, olay.position)
		else:
			_basili = false
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	elif olay is InputEventScreenTouch:
		if olay.pressed:
			_basili = true
			_son_hucre = Vector3(INF, INF, INF)
			_islem(kamera, olay.position)
		else:
			_basili = false
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	if _basili:
		if olay is InputEventMouseMotion and (olay.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_islem(kamera, olay.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif olay is InputEventScreenDrag:
			_islem(kamera, olay.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _islem(kamera: Camera3D, ekran: Vector2) -> void:
	if _panel.mod == "koy":
		_yerlestir(kamera, ekran)
	elif _panel.mod == "sil":
		_sil(kamera, ekran)

func _zemin_noktasi(kamera: Camera3D, ekran: Vector2):
	if kamera == null:
		return null
	var bas: Vector3 = kamera.project_ray_origin(ekran)
	var yon: Vector3 = kamera.project_ray_normal(ekran)
	if absf(yon.y) < 0.000001:
		return null
	var t: float = -bas.y / yon.y
	if t < 0.0:
		return null
	return bas + yon * t

# ---------------------------------------------------------------- Yerleştirme
func _yerlestir(kamera: Camera3D, ekran: Vector2) -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		_panel.durum_yaz("Önce sahneyi aç (Harita.tscn)")
		return
	if _panel.secili_ad == "" or not parcalar.has(_panel.secili_ad):
		_panel.durum_yaz("Önce bir parça seç")
		return
	var carpma = _zemin_noktasi(kamera, ekran)
	if carpma == null:
		return

	var ad: String = _panel.secili_ad
	var olc: float = maxf(_panel.olcek(), 0.01)
	var don: float = _panel.donme()
	var yuk: float = _panel.yukseklik()
	var taban: float = _panel.izgara() if _panel.izgara() > 0.001 else IZGARA
	var C: float = taban * olc
	var eksen: String = parcalar[ad].get("eksen", "y")

	var hedef: Vector3
	if not _panel.snap_acik:
		# Serbest yerleştirme (ızgarasız)
		hedef = Vector3(carpma.x, yuk, carpma.z)
	elif eksen == "y":
		hedef = Vector3(floorf(carpma.x / C) * C + C * 0.5, yuk, floorf(carpma.z / C) * C + C * 0.5)
	else:
		var yerel_ince: Vector3 = Vector3.RIGHT if eksen == "x" else Vector3(0.0, 0.0, 1.0)
		var dunya_ince: Vector3 = Basis(Vector3.UP, deg_to_rad(don)) * yerel_ince
		if absf(dunya_ince.x) >= absf(dunya_ince.z):
			hedef = Vector3(roundf(carpma.x / C) * C, yuk, floorf(carpma.z / C) * C + C * 0.5)
		else:
			hedef = Vector3(floorf(carpma.x / C) * C + C * 0.5, yuk, roundf(carpma.z / C) * C)

	# Sürüklemede tekrarı engelle (snap: aynı hücre, serbest: min mesafe)
	if _panel.snap_acik:
		if hedef.is_equal_approx(_son_hucre):
			return
	else:
		if _son_hucre.x != INF and hedef.distance_to(_son_hucre) < C * 0.5:
			return

	# Üst üste binme engeli (sadece snap açıkken; serbest modda engel yok)
	var tip_ad: String = ad.replace(" ", "")
	if _panel.snap_acik:
		for c in _tum_parcalar(kok):
			if c.name.begins_with(tip_ad):
				var fark: Vector3 = c.global_position - hedef
				if absf(fark.x) < C * 0.45 and absf(fark.z) < C * 0.45 and absf(fark.y - yuk) < 0.5:
					_son_hucre = hedef
					return

	var sahne: PackedScene = load(parcalar[ad]["yol"]) as PackedScene
	if sahne == null:
		_panel.durum_yaz("Parça yüklenemedi: " + ad)
		return
	var ornek: Node3D = sahne.instantiate() as Node3D
	if ornek == null:
		return
	ornek.name = tip_ad
	ornek.position = hedef
	ornek.scale = Vector3.ONE * olc
	ornek.rotation = Vector3(0.0, deg_to_rad(don), 0.0)
	# Kalınlık (yalnızca BoxMesh): doğru ince eksene uygula.
	var mi: MeshInstance3D = _mesh_bul(ornek)
	if mi != null and mi.mesh is BoxMesh:
		var bm: BoxMesh = (mi.mesh as BoxMesh).duplicate()
		var sz: Vector3 = bm.size
		match eksen:
			"y": sz.y = parcalar[ad].get("kal", sz.y)
			"x": sz.x = parcalar[ad].get("kal", sz.x)
			_: sz.z = parcalar[ad].get("kal", sz.z)
		bm.size = sz
		mi.mesh = bm
	ornek.set_meta(PARCA_META, true)

	var grup := _grup_dugum(kok, true)
	var ur := get_undo_redo()
	ur.create_action("Parça yerleştir: " + ad, UndoRedo.MERGE_DISABLE, kok)
	ur.add_do_method(grup, "add_child", ornek, true)
	ur.add_do_method(ornek, "set_owner", kok)
	ur.add_do_reference(ornek)
	ur.add_undo_method(grup, "remove_child", ornek)
	ur.commit_action()
	_son_hucre = hedef
	_son_secilen = ad
	_sayaci_guncelle()

# ---------------------------------------------------------------- Silme
func _sil(kamera: Camera3D, ekran: Vector2) -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		return
	var en_yakin: Node3D = null
	var en_kucuk: float = 120.0
	for c in _tum_parcalar(kok):
		var sp: Vector2 = kamera.unproject_position(c.global_position)
		var dd: float = sp.distance_to(ekran)
		if dd < en_kucuk:
			en_kucuk = dd
			en_yakin = c
	if en_yakin == null:
		return
	var ebeveyn := en_yakin.get_parent()
	if ebeveyn == null:
		return
	var ur := get_undo_redo()
	ur.create_action("Parça sil", UndoRedo.MERGE_DISABLE, kok)
	ur.add_do_method(ebeveyn, "remove_child", en_yakin)
	ur.add_undo_method(ebeveyn, "add_child", en_yakin, true)
	ur.add_undo_method(en_yakin, "set_owner", kok)
	ur.add_undo_reference(en_yakin)
	ur.commit_action()
	_sayaci_guncelle()

# ---------------------------------------------------------------- Yönetim
func _grup_dugum(kok: Node, olustur: bool) -> Node3D:
	var ad := _panel.grup_adi if _panel and _panel.grup_adi != "" else "Parcalar"
	for c in kok.get_children():
		if c is Node3D and c.has_meta(GRUP_META) and c.name == ad:
			return c
	if not olustur:
		return null
	var g := Node3D.new()
	g.name = ad
	g.set_meta(GRUP_META, true)
	kok.add_child(g)
	g.owner = kok
	g.transform = Transform3D.IDENTITY
	return g

func _grubu_temizle() -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		return
	var grup := _grup_dugum(kok, false)
	if grup == null or grup.get_child_count() == 0:
		_panel.durum_yaz("Bu grup zaten boş: " + (_panel.grup_adi))
		return
	var cocuklar := grup.get_children()
	var ur := get_undo_redo()
	ur.create_action("Grubu temizle: " + grup.name, UndoRedo.MERGE_DISABLE, kok)
	for c in cocuklar:
		ur.add_do_method(grup, "remove_child", c)
		ur.add_undo_method(grup, "add_child", c, true)
		ur.add_undo_method(c, "set_owner", kok)
		ur.add_undo_reference(c)
	ur.commit_action()
	_sayaci_guncelle()

func _tumunu_temizle() -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		return
	var hepsi := _tum_parcalar(kok)
	if hepsi.is_empty():
		_panel.durum_yaz("Silinecek parça yok")
		return
	var ur := get_undo_redo()
	ur.create_action("Tüm parçaları temizle (%d)" % hepsi.size(), UndoRedo.MERGE_DISABLE, kok)
	for c in hepsi:
		var eb := c.get_parent()
		if eb == null:
			continue
		ur.add_do_method(eb, "remove_child", c)
		ur.add_undo_method(eb, "add_child", c, true)
		ur.add_undo_method(c, "set_owner", kok)
		ur.add_undo_reference(c)
	ur.commit_action()
	_sayaci_guncelle()

func _son_parcayi_sec() -> void:
	if _son_secilen != "" and parcalar.has(_son_secilen) and _panel:
		_panel.parca_sec(_son_secilen)
	elif _panel:
		_panel.durum_yaz("Henüz parça seçilmedi")

func _sayaci_guncelle() -> void:
	if _panel == null:
		return
	var kok: Node = EditorInterface.get_edited_scene_root()
	_panel.parca_sayisi_yaz(0 if kok == null else _tum_parcalar(kok).size())

# ---------------------------------------------------------------- Yardımcılar
func _tum_parcalar(kok: Node) -> Array[Node3D]:
	var sonuc: Array[Node3D] = []
	_topla_parcalar(kok, sonuc)
	return sonuc

func _topla_parcalar(n: Node, dizi: Array[Node3D]) -> void:
	for c in n.get_children():
		if c is Node3D and c.has_meta(PARCA_META):
			dizi.append(c)
		else:
			_topla_parcalar(c, dizi)

func _mesh_bul(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c: Node in n.get_children():
		var r: MeshInstance3D = _mesh_bul(c)
		if r != null:
			return r
	return null

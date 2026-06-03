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

const HATA_AYIKLA := false   # teşhis çıktıları (gerekirse true yap → Output'ta [YP] satırları)
const IZGARA: float = 4.0
const PARCA_KLASORU := "res://parts/"
const GRUP_META := "parca_grubu"
const PARCA_META := "yp"
const YUK_ADIM := 0.5

var parcalar: Dictionary = {}     # ad -> {yol, ikon, eksen, kal, yuk}
var _panel: YerlestirmePanel
var _dock: ScrollContainer
var _arac: HBoxContainer
var _btn_koy: Button
var _btn_sil: Button
var _son_secilen: String = ""
var _basili: bool = false
var _son_hucre: Vector3 = Vector3(INF, INF, INF)
var _basis_konumlari: Array[Vector3] = []   # bu basış/sürükleme boyunca konulan yerler (anlık dedup)

func _enter_tree() -> void:
	_parcalari_tara()
	_paneli_kur()
	_arac_kur()

func _exit_tree() -> void:
	if _arac:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _arac)
		_arac.queue_free()
		_arac = null
	_panel_kaldir()

# Viewport üst barına Koy/Sil/Dur — modu buradan da aç/kapatabilirsin (etkinleştirmeyi garantiler).
func _arac_kur() -> void:
	_arac = HBoxContainer.new()
	_arac.add_theme_constant_override("separation", 4)
	_btn_koy = Button.new()
	_btn_koy.text = "🧱 Koy"
	_btn_koy.toggle_mode = true
	_btn_koy.tooltip_text = "Yerleştirme modu (parçayı soldaki 'Yerleştirici' panelinden seç)"
	_btn_koy.toggled.connect(func(a: bool): _mod_tikla("koy" if a else "yok"))
	_arac.add_child(_btn_koy)
	_btn_sil = Button.new()
	_btn_sil.text = "🗑 Sil"
	_btn_sil.toggle_mode = true
	_btn_sil.modulate = Color(1.0, 0.78, 0.78)
	_btn_sil.toggled.connect(func(a: bool): _mod_tikla("sil" if a else "yok"))
	_arac.add_child(_btn_sil)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _arac)

func _mod_tikla(m: String) -> void:
	if _panel:
		_panel.mod_ayarla(m)
		if m != "yok":
			_editoru_aktiflestir()

func _parca_secildi(ad: String) -> void:
	_son_secilen = ad
	_editoru_aktiflestir()

# Parça seçince / mod açınca 3B viewport'u aktif eder ve eklentiyi aktif handler
# yapar. Böylece dock'tan seçtikten sonra İLK viewport tıklaması yerleştirir
# (yoksa ilk tık yalnızca odağı/handler'ı değiştirir, parça konmaz).
func _editoru_aktiflestir() -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		return
	EditorInterface.set_main_screen_editor("3D")
	EditorInterface.edit_node(kok)

func _arac_guncelle(m: String) -> void:
	if _btn_koy:
		_btn_koy.set_pressed_no_signal(m == "koy")
	if _btn_sil:
		_btn_sil.set_pressed_no_signal(m == "sil")


# ---------------------------------------------------------------- Panel / dock
func _paneli_kur() -> void:
	_panel = YerlestirmePanel.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.kur(parcalar)
	_panel.yenile_istendi.connect(_parcalari_yenile)
	_panel.grubu_temizle_istendi.connect(_grubu_temizle)
	_panel.tumunu_temizle_istendi.connect(_tumunu_temizle)
	_panel.son_parca_istendi.connect(_son_parcayi_sec)
	_panel.parca_secildi.connect(_parca_secildi)
	_panel.mod_degisti.connect(_arac_guncelle)
	_panel.kir_sac_istendi.connect(_kir_sac)
	_panel.kir_temizle_istendi.connect(_kir_temizle)
	_panel.leke_secildi.connect(func(_yol): _editoru_aktiflestir())
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
# Her zaman true: eklenti hep aktif 3B handler olur. Boştayken (_panel.mod == "yok")
# forward PASS ettiği için normal editör/gizmo davranışı bozulmaz. Bu sayede modu
# dock/araç çubuğundan açtığında seçim değişmeden de ilk sürükleme çalışır.
func _handles(_o: Object) -> bool:
	return _panel != null

func _forward_3d_gui_input(kamera: Camera3D, olay: InputEvent) -> int:
	# TEŞHİS: fare/dokunma basışı geldiğinde, mod ne olursa olsun bir kez bildir.
	if HATA_AYIKLA and ((olay is InputEventMouseButton and olay.button_index == MOUSE_BUTTON_LEFT and olay.pressed) \
			or (olay is InputEventScreenTouch and olay.pressed)):
		print("[YP] forward: basış alındı | panel=%s mod=%s secili=%s" % [
			str(_panel != null), (_panel.mod if _panel else "-"), (_panel.secili_ad if _panel else "-")])
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
			_basis_konumlari.clear()
			_islem(kamera, olay.position)
		else:
			_basili = false
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	elif olay is InputEventScreenTouch:
		if olay.pressed:
			_basili = true
			_son_hucre = Vector3(INF, INF, INF)
			_basis_konumlari.clear()
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
	elif _panel.mod == "leke":
		_leke_bas(kamera, ekran)

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
		if HATA_AYIKLA: print("[YP] yerleştir: SAHNE AÇIK DEĞİL")
		_panel.durum_yaz("Önce sahneyi aç (Harita.tscn)")
		return
	if _panel.secili_ad == "" or not parcalar.has(_panel.secili_ad):
		if HATA_AYIKLA: print("[YP] yerleştir: PARÇA SEÇİLİ DEĞİL (secili='%s')" % _panel.secili_ad)
		_panel.durum_yaz("Önce bir parça seç")
		return
	var carpma = _zemin_noktasi(kamera, ekran)
	if carpma == null:
		if HATA_AYIKLA: print("[YP] yerleştir: IŞIN y=0 DÜZLEMİNE DEĞMEDİ (kamera açısı). ekran=%s" % str(ekran))
		return
	if HATA_AYIKLA: print("[YP] yerleştir: kok=%s parça=%s çarpma=%s" % [kok.name, _panel.secili_ad, str(carpma)])

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

	# SAĞLAM ÇAKIŞMA ENGELİ (her modda): aynı/çok yakın koordinatta aynı tip parça
	# varsa ASLA ikincisini koyma. "Tek tıkta üst üste 10 parça" sorununu bitirir.
	var tip_ad: String = ad.replace(" ", "")
	var esik_xz: float = maxf(C * 0.4, 0.2)
	for c in _tum_parcalar(kok):
		if not c.name.begins_with(tip_ad):
			continue
		var fark: Vector3 = c.position - hedef
		if absf(fark.x) < esik_xz and absf(fark.z) < esik_xz and absf(fark.y) < 0.25:
			_son_hucre = hedef
			return
	for p in _basis_konumlari:
		var fb: Vector3 = p - hedef
		if absf(fb.x) < esik_xz and absf(fb.z) < esik_xz and absf(fb.y) < 0.25:
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
	_basis_konumlari.append(hedef)
	_son_secilen = ad
	_sayaci_guncelle()
	_panel.durum_yaz("✓ %s @ (%.1f, %.1f, %.1f)" % [tip_ad, hedef.x, hedef.y, hedef.z])
	if HATA_AYIKLA: print("[YP] YERLEŞTİ ✓ '%s' @ %s  (grup='%s', toplam=%d)" % [
		tip_ad, str(hedef), grup.name, _tum_parcalar(kok).size()])

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

# ---------------------------------------------------------------- AAA Kir (Decal)
# Yerleşik zeminlerin üstüne benzersiz çamur decal'larını TEK MultiMesh ile saçar
# (rastgele konum/dönüş/boyut -> tekrarsız; 1 draw call -> mobil dostu).
func _kir_sac() -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		return
	var parcalar_l := _tum_parcalar(kok)
	if parcalar_l.is_empty():
		_panel.durum_yaz("Önce zemin yerleştir, sonra kir saç")
		return
	var minx := INF; var maxx := -INF; var minz := INF; var maxz := -INF; var miny := INF
	for c in parcalar_l:
		var p: Vector3 = c.global_position
		minx = minf(minx, p.x); maxx = maxf(maxx, p.x)
		minz = minf(minz, p.z); maxz = maxf(maxz, p.z); miny = minf(miny, p.y)
	minx -= 2.2; maxx += 2.2; minz -= 2.2; maxz += 2.2
	var alan: float = maxf((maxx - minx) * (maxz - minz), 1.0)
	var adet: int = clampi(int(alan * 0.8), 24, 3000)

	var duzlem := PlaneMesh.new()
	duzlem.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = duzlem
	mm.instance_count = adet
	for i in adet:
		var x := randf_range(minx, maxx)
		var z := randf_range(minz, maxz)
		var s := randf_range(0.8, 2.6)
		var sx := s * (1.0 if randf() < 0.5 else -1.0)
		var b := Basis().rotated(Vector3.UP, randf() * TAU).scaled(Vector3(sx, 1.0, s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, miny + 0.02, z)))

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/kir_decal.gdshader")
	mat.set_shader_parameter("tex", load("res://textures/dirt_albedo.png"))
	mat.set_shader_parameter("alpha_boost", 2.0)
	mat.set_shader_parameter("renk_boost", 1.4)
	mat.set_shader_parameter("rough", 0.85)

	var dmi := MultiMeshInstance3D.new()
	dmi.name = "KirDecal"
	dmi.multimesh = mm
	dmi.material_override = mat
	dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dmi.set_meta("kir_decal", true)

	var ur := get_undo_redo()
	ur.create_action("Zemine kir saç (%d decal)" % adet, UndoRedo.MERGE_DISABLE, kok)
	ur.add_do_method(kok, "add_child", dmi, true)
	ur.add_do_method(dmi, "set_owner", kok)
	ur.add_do_reference(dmi)
	ur.add_undo_method(kok, "remove_child", dmi)
	ur.commit_action()
	_panel.durum_yaz("✨ %d kir decal saçıldı (tek MultiMesh)" % adet)

func _kir_temizle() -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		return
	var sil: Array[Node] = []
	for c in kok.get_children():
		if c.has_meta("kir_decal"):
			sil.append(c)
	if sil.is_empty():
		_panel.durum_yaz("Temizlenecek kir decal yok")
		return
	var ur := get_undo_redo()
	ur.create_action("Kiri temizle", UndoRedo.MERGE_DISABLE, kok)
	for c in sil:
		ur.add_do_method(kok, "remove_child", c)
		ur.add_undo_method(kok, "add_child", c, true)
		ur.add_undo_method(c, "set_owner", kok)
		ur.add_undo_reference(c)
	ur.commit_action()
	_panel.durum_yaz("Kir decal temizlendi (%d)" % sil.size())

# ---------------------------------------------------------------- Leke (decal)
# Tıklanan ekran noktasından ışın atar, yerleşik parça kutularıyla kesiştirir;
# en yakın yüzeye (doğru normalle) leke quad'ı yapıştırır. Kutu yoksa y=0 zemini.
func _leke_bas(kamera: Camera3D, ekran: Vector2) -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		_panel.durum_yaz("Önce sahneyi aç")
		return
	if _panel.secili_leke == "":
		_panel.durum_yaz("Önce bir leke seç")
		return
	var ro: Vector3 = kamera.project_ray_origin(ekran)
	var rd: Vector3 = kamera.project_ray_normal(ekran)
	var nokta: Vector3
	var normal: Vector3
	var en_t := INF
	var bulundu := false
	for c in _tum_parcalar(kok):
		var h := _ray_kutu(c, ro, rd)
		if h.is_empty():
			continue
		var t: float = h["t"]
		if t < en_t:
			en_t = t; nokta = h["nokta"]; normal = h["normal"]; bulundu = true
	if not bulundu:
		# y=0 zemin düzlemi
		if absf(rd.y) < 0.000001:
			return
		var t0: float = -ro.y / rd.y
		if t0 < 0.0:
			return
		nokta = ro + rd * t0; normal = Vector3.UP
	_leke_yerlestir(kok, nokta, normal)

# Işın-kutu (yerel uzayda AABB), dönüşü {t, nokta, normal} ya da {}.
func _ray_kutu(parca: Node3D, ro: Vector3, rd: Vector3) -> Dictionary:
	var mi := _mesh_bul(parca)
	if mi == null or mi.mesh == null:
		return {}
	var aabb: AABB = mi.mesh.get_aabb()
	var gt: Transform3D = mi.global_transform
	var inv := gt.affine_inverse()
	var lo := inv * ro
	var ld := inv.basis * rd
	var amin := aabb.position
	var amax := aabb.position + aabb.size
	var tnear := -INF; var tfar := INF; var nrm_eksen := 0; var nrm_isaret := 1.0
	for i in 3:
		var o: float = lo[i]; var d: float = ld[i]
		if absf(d) < 1e-9:
			if o < amin[i] or o > amax[i]:
				return {}
			continue
		var t1: float = (amin[i] - o) / d
		var t2: float = (amax[i] - o) / d
		var isaret := -1.0
		if t1 > t2:
			var tmp := t1; t1 = t2; t2 = tmp; isaret = 1.0
		if t1 > tnear:
			tnear = t1; nrm_eksen = i; nrm_isaret = isaret
		if t2 < tfar:
			tfar = t2
		if tnear > tfar:
			return {}
	if tfar < 0.0:
		return {}
	var th: float = tnear if tnear > 0.0 else tfar
	var lp := lo + ld * th
	var wp := gt * lp
	var ln := Vector3.ZERO; ln[nrm_eksen] = nrm_isaret
	var wn := (gt.basis * ln).normalized()
	return {"t": (wp - ro).length(), "nokta": wp, "normal": wn}

func _leke_grup(kok: Node) -> Node3D:
	for c in kok.get_children():
		if c is Node3D and c.name == "Lekeler" and c.has_meta("leke_grup"):
			return c
	var g := Node3D.new()
	g.name = "Lekeler"
	g.set_meta("leke_grup", true)
	kok.add_child(g)
	g.owner = kok
	return g

func _leke_yerlestir(kok: Node, nokta: Vector3, normal: Vector3) -> void:
	var n := normal.normalized()
	if n.length() < 0.5:
		n = Vector3.UP
	var yardim := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var tx := yardim.cross(n).normalized()
	var ty := n.cross(tx).normalized()
	var ac := randf() * TAU if _panel.leke_rastgele else 0.0
	var co := cos(ac); var si := sin(ac)
	var rx := tx * co + ty * si
	var ry := -tx * si + ty * co
	var boyut: float = _panel.leke_boyut * (randf_range(0.7, 1.35) if _panel.leke_rastgele else 1.0)
	var basis := Basis(rx * boyut, n, ry * boyut)   # PlaneMesh yerel Y = normal

	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	mi.mesh = pm
	mi.transform = Transform3D(basis, nokta + n * 0.012)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/kir_decal.gdshader")
	mat.set_shader_parameter("tex", load(_panel.secili_leke))
	mat.set_shader_parameter("alpha_boost", 2.0)
	mat.set_shader_parameter("renk_boost", 1.25)
	mat.set_shader_parameter("rough", 0.7)
	mi.material_override = mat
	mi.set_meta("leke", true)
	mi.name = "Leke"

	var grup := _leke_grup(kok)
	var ur := get_undo_redo()
	ur.create_action("Leke yapıştır", UndoRedo.MERGE_DISABLE, kok)
	ur.add_do_method(grup, "add_child", mi, true)
	ur.add_do_method(mi, "set_owner", kok)
	ur.add_do_reference(mi)
	ur.add_undo_method(grup, "remove_child", mi)
	ur.commit_action()
	_panel.durum_yaz("🩸 Leke yapıştırıldı")

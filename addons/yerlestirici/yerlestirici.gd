@tool
extends EditorPlugin
## PARÇA YERLEŞTİRİCİ — profesyonel harita kurma aracı.
##
## Harita içeriğini SEN yaparsın; bu eklenti yalnızca araçtır. Hiçbir doku/parça
## üretmez — sadece senin koyduğun parçaları kullanır.
##
## • OTOMATİK PARÇA KEŞFİ: parts/ klasörüne bir .tscn parça atman yeter; eklenti
##   onu otomatik listeler. Kod düzenlemeye gerek yok.
## • OTOMATİK TÜR: parçanın türü (zemin/tavan = yatay, duvar = dikey panel) mesh'in
##   ince ekseninden otomatik anlaşılır.
## • SİSTEMATİK IZGARA: zemin/tavan hücre MERKEZİNE, duvar karo KENARINA (ızgara
##   çizgisi) oturur; ölçekle ızgara birlikte büyür (çakışma olmaz).
## • HIZLI KURMA: sürükleyerek seri yerleştirme, R ile 90° döndürme, üst üste binme
##   engeli, tam Geri Al/Yinele.

const IZGARA: float = 4.0
const PARCA_KLASORU := "res://parts/"

# ad -> { yol:String, ikon:String, eksen:String("x"/"y"/"z"), kal:float, yuk:float }
var parcalar: Dictionary = {}

var arac: HBoxContainer
var govde: HBoxContainer
var kucult_btn: Button
var durum: Label
var mod: String = "yok"          # "yok" | "koy" | "sil"
var secili_ad: String = ""
var secili_yol: String = ""
var butonlar: Array = []
var ayarlar: Dictionary = {}     # ad -> YerlestirmeAyari
var secili_ayar: YerlestirmeAyari = null

# Sürükleme durumu
var _basili: bool = false
var _son_hucre: Vector3 = Vector3(INF, INF, INF)

func _enter_tree() -> void:
	_parcalari_tara()

	arac = HBoxContainer.new()
	arac.add_theme_constant_override("separation", 6)

	kucult_btn = Button.new()
	kucult_btn.text = "🧩 ▾"
	kucult_btn.toggle_mode = true
	kucult_btn.button_pressed = true
	kucult_btn.tooltip_text = "Paneli küçült / büyüt"
	kucult_btn.toggled.connect(_kucult_buyut)
	arac.add_child(kucult_btn)

	govde = HBoxContainer.new()
	govde.add_theme_constant_override("separation", 6)
	arac.add_child(govde)

	if parcalar.is_empty():
		var uyari := Label.new()
		uyari.text = "  parts/ klasörüne .tscn parça ekle"
		uyari.modulate = Color(1.0, 0.8, 0.5)
		govde.add_child(uyari)

	# Parça butonları (otomatik keşfedilenler) — ikon parçanın kendi dokusudur.
	for ad: String in parcalar.keys():
		var b: Button = Button.new()
		b.text = " " + ad
		b.toggle_mode = true
		var ikon_yolu: String = parcalar[ad].get("ikon", "")
		if ikon_yolu != "":
			var tex: Texture2D = load(ikon_yolu) as Texture2D
			if tex != null:
				b.icon = tex
				b.expand_icon = true
				b.add_theme_constant_override("icon_max_width", 40)
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(_parca_modu.bind(ad, b))
		govde.add_child(b)
		butonlar.append(b)
		var ay: YerlestirmeAyari = YerlestirmeAyari.new()
		ay.resource_name = ad + " Ayarları"
		ay.kalinlik = parcalar[ad].get("kal", 0.2)
		ay.yukseklik = parcalar[ad].get("yuk", 0.0)
		ayarlar[ad] = ay

	var sil_btn: Button = Button.new()
	sil_btn.text = "🗑 Sil"
	sil_btn.toggle_mode = true
	sil_btn.modulate = Color(1.0, 0.75, 0.75)
	sil_btn.pressed.connect(_sil_modu.bind(sil_btn))
	govde.add_child(sil_btn)
	butonlar.append(sil_btn)

	var dur_btn: Button = Button.new()
	dur_btn.text = "✋ Dur"
	dur_btn.pressed.connect(_durdur)
	govde.add_child(dur_btn)

	var yenile_btn: Button = Button.new()
	yenile_btn.text = "🔄"
	yenile_btn.tooltip_text = "Parça listesini yenile (parts/ klasörünü tekrar tara)"
	yenile_btn.pressed.connect(_yeniden_kur)
	govde.add_child(yenile_btn)

	durum = Label.new()
	durum.text = "  (mod: yok)  —  %d parça" % parcalar.size()
	durum.modulate = Color(0.6, 0.85, 1.0)
	govde.add_child(durum)

	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, arac)

func _exit_tree() -> void:
	if arac:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, arac)
		arac.queue_free()
		arac = null

## parts/ klasöründeki tüm .tscn parçaları bulur ve türünü otomatik çözer.
func _parcalari_tara() -> void:
	parcalar.clear()
	var d := DirAccess.open(PARCA_KLASORU)
	if d == null:
		push_warning("Yerleştirici: parça klasörü bulunamadı: " + PARCA_KLASORU)
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
		var gad := f.get_basename()
		parcalar[gad] = _parca_coz(yol, gad)

## Bir parçanın türünü/ikonunu mesh ve malzemesinden çözer (hiçbir şey üretmez).
func _parca_coz(yol: String, gad: String) -> Dictionary:
	var bilgi := {"yol": yol, "ikon": "", "eksen": "y", "kal": 0.12, "yuk": 0.0}
	var ps := load(yol) as PackedScene
	if ps == null:
		return bilgi
	var inst := ps.instantiate()
	var mi := _mesh_bul(inst)
	if mi != null and mi.mesh is BoxMesh:
		var sz: Vector3 = (mi.mesh as BoxMesh).size
		# En küçük boyut = ince eksen. Y ince -> zemin/tavan; X/Z ince -> duvar.
		if sz.y <= sz.x and sz.y <= sz.z:
			bilgi.eksen = "y"
			bilgi.kal = sz.y
		elif sz.x <= sz.z:
			bilgi.eksen = "x"
			bilgi.kal = sz.x
		else:
			bilgi.eksen = "z"
			bilgi.kal = sz.z
	if mi != null:
		var mat: Material = mi.get_surface_override_material(0)
		if mat == null and mi.mesh != null:
			mat = mi.mesh.surface_get_material(0)
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
			bilgi.ikon = (mat as StandardMaterial3D).albedo_texture.resource_path
	if gad.to_lower().contains("tavan"):
		bilgi.yuk = 3.0
	inst.free()
	return bilgi

func _yeniden_kur() -> void:
	# Toolbar'ı baştan kur (yeni eklenen parçalar görünsün).
	_durdur()
	if arac:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, arac)
		arac.queue_free()
		arac = null
	butonlar.clear()
	ayarlar.clear()
	_enter_tree()

func _kucult_buyut(acik: bool) -> void:
	govde.visible = acik
	kucult_btn.text = "🧩 ▾" if acik else "🧩 ▸"

func _butonlari_ayarla(aktif: Button) -> void:
	for b: Button in butonlar:
		b.button_pressed = (b == aktif)

func _parca_modu(ad: String, btn: Button) -> void:
	mod = "koy"
	secili_ad = ad
	secili_yol = parcalar[ad]["yol"]
	secili_ayar = ayarlar[ad]
	_butonlari_ayarla(btn)
	EditorInterface.inspect_object(secili_ayar)
	durum.text = "  → KOY: %s  (sürükle = seri, R = döndür)" % ad

func _sil_modu(btn: Button) -> void:
	mod = "sil"
	_butonlari_ayarla(btn)
	durum.text = "  → SİL (parçaya dokun / sürükle)"

func _durdur() -> void:
	mod = "yok"
	_basili = false
	_butonlari_ayarla(null)
	if durum:
		durum.text = "  (mod: yok)"

func _handles(_object: Object) -> bool:
	return mod != "yok"

func _forward_3d_gui_input(kamera: Camera3D, olay: InputEvent) -> int:
	if mod == "yok":
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	# R ile 90° döndürme (koy modunda)
	if mod == "koy" and olay is InputEventKey and olay.pressed and not olay.echo and olay.keycode == KEY_R:
		if secili_ayar != null:
			secili_ayar.donme_y = fmod(secili_ayar.donme_y + 90.0, 360.0)
			EditorInterface.inspect_object(secili_ayar)
			durum.text = "  Döndürme: %d°" % int(secili_ayar.donme_y)
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	# Basma / bırakma (fare + dokunmatik)
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

	# Sürükleyerek seri yerleştirme/silme
	if _basili:
		if olay is InputEventMouseMotion and (olay.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_islem(kamera, olay.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif olay is InputEventScreenDrag:
			_islem(kamera, olay.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _islem(kamera: Camera3D, ekran: Vector2) -> void:
	if mod == "koy":
		_yerlestir(kamera, ekran)
	elif mod == "sil":
		_sil(kamera, ekran)

func _zemin_noktasi(kamera: Camera3D, ekran: Vector2):
	var baslangic: Vector3 = kamera.project_ray_origin(ekran)
	var yon: Vector3 = kamera.project_ray_normal(ekran)
	if absf(yon.y) < 0.000001:
		return null
	var t: float = -baslangic.y / yon.y
	if t < 0.0:
		return null
	return baslangic + yon * t

func _yerlestir(kamera: Camera3D, ekran: Vector2) -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		durum.text = "  Önce sahne aç (Harita.tscn)"
		return
	var carpma = _zemin_noktasi(kamera, ekran)
	if carpma == null:
		return

	# --- SİSTEMATİK IZGARA HİZALAMA ---
	# C = efektif hücre (parça ölçeğiyle büyür). Zemin/tavan hücre MERKEZİNE;
	# duvar ince ekseninde ızgara ÇİZGİSİNE (karo kenarı), uzun ekseninde merkeze.
	# Duvarın dünya-ince ekseni, parçanın yerel ince ekseni (eksen) + dönüş (donme_y)
	# birlikte hesaplanarak bulunur.
	var taban: float = secili_ayar.izgara if secili_ayar != null and secili_ayar.izgara > 0.001 else IZGARA
	var olc: float = secili_ayar.olcek if secili_ayar != null and secili_ayar.olcek > 0.001 else 1.0
	var C: float = taban * olc
	var yuk: float = secili_ayar.yukseklik if secili_ayar != null else 0.0
	var eksen: String = parcalar[secili_ad].get("eksen", "y")
	var hedef: Vector3
	if eksen == "y":
		hedef = Vector3(floorf(carpma.x / C) * C + C * 0.5, yuk, floorf(carpma.z / C) * C + C * 0.5)
	else:
		var donme: float = secili_ayar.donme_y if secili_ayar != null else 0.0
		var yerel_ince: Vector3 = Vector3.RIGHT if eksen == "x" else Vector3(0.0, 0.0, 1.0)
		var dunya_ince: Vector3 = Basis(Vector3.UP, deg_to_rad(donme)) * yerel_ince
		if absf(dunya_ince.x) >= absf(dunya_ince.z):
			hedef = Vector3(roundf(carpma.x / C) * C, yuk, floorf(carpma.z / C) * C + C * 0.5)
		else:
			hedef = Vector3(floorf(carpma.x / C) * C + C * 0.5, yuk, roundf(carpma.z / C) * C)

	# Sürüklemede aynı hücreyi tekrar işleme (performans).
	if hedef.is_equal_approx(_son_hucre):
		return

	# Aynı konumda aynı türden parça varsa üst üste bindirme (çakışma engelle).
	var tip_ad: String = secili_ad.replace(" ", "")
	for c in kok.get_children():
		if c is Node3D and c.has_meta("yp") and (c as Node3D).name.begins_with(tip_ad):
			var fark: Vector3 = (c as Node3D).position - hedef
			if absf(fark.x) < C * 0.45 and absf(fark.z) < C * 0.45 and absf(fark.y - yuk) < 0.5:
				_son_hucre = hedef
				return

	var sahne: PackedScene = load(secili_yol) as PackedScene
	if sahne == null:
		return
	var ornek: Node3D = sahne.instantiate()
	ornek.name = tip_ad
	ornek.position = hedef
	if secili_ayar != null:
		ornek.scale = Vector3.ONE * olc
		ornek.rotation = Vector3(0.0, deg_to_rad(secili_ayar.donme_y), 0.0)
		# Kalınlık: doğru ince ekseni Inspector değerine göre ayarla.
		var mi: MeshInstance3D = _mesh_bul(ornek)
		if mi != null and mi.mesh is BoxMesh:
			var bm: BoxMesh = (mi.mesh as BoxMesh).duplicate()
			var sz: Vector3 = bm.size
			match eksen:
				"y": sz.y = secili_ayar.kalinlik
				"x": sz.x = secili_ayar.kalinlik
				_: sz.z = secili_ayar.kalinlik
			bm.size = sz
			mi.mesh = bm
	ornek.set_meta("yp", true)
	var ur: EditorUndoRedoManager = get_undo_redo()
	ur.create_action("Parça yerleştir: " + secili_ad, UndoRedo.MERGE_DISABLE, kok)
	ur.add_do_method(kok, "add_child", ornek, true)
	ur.add_do_method(ornek, "set_owner", kok)
	ur.add_do_reference(ornek)
	ur.add_undo_method(kok, "remove_child", ornek)
	ur.commit_action()
	_son_hucre = hedef

func _mesh_bul(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c: Node in n.get_children():
		var r: MeshInstance3D = _mesh_bul(c)
		if r != null:
			return r
	return null

func _silinebilir(c: Node) -> bool:
	if c is Camera3D or c is DirectionalLight3D or c is WorldEnvironment:
		return false
	return c is Node3D

func _sil(kamera: Camera3D, ekran: Vector2) -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		return
	# Tıklanan/sürüklenen noktaya EKRANDA en yakın parçayı bul.
	var en_yakin: Node3D = null
	var en_kucuk: float = 120.0   # px eşiği
	for c: Node in kok.get_children():
		if not _silinebilir(c):
			continue
		var sp: Vector2 = kamera.unproject_position((c as Node3D).global_position)
		var d: float = sp.distance_to(ekran)
		if d < en_kucuk:
			en_kucuk = d
			en_yakin = c
	if en_yakin == null:
		return
	var ur: EditorUndoRedoManager = get_undo_redo()
	ur.create_action("Parça sil", UndoRedo.MERGE_DISABLE, kok)
	ur.add_do_method(kok, "remove_child", en_yakin)
	ur.add_undo_method(kok, "add_child", en_yakin, true)
	ur.add_undo_method(en_yakin, "set_owner", kok)
	ur.add_undo_reference(en_yakin)
	ur.commit_action()

@tool
extends EditorPlugin
## Parça Yerleştirici (dokunmatik):
## Üst panelde parçanın GÖRSELİNE dokunarak seç → sonra sahnede dokun = yerleşir.
## Panel KÜÇÜLT/BÜYÜT düğmeli (ekranı kaplamaz). Izgara: 4 m.

const IZGARA: float = 4.0

# Parça: Türkçe ad -> { yol, ikon }. Yeni parça buraya eklenir.
var parcalar: Dictionary = {
	"Zemin": {"yol": "res://parts/Zemin.tscn", "ikon": "res://textures/floor_albedo.png", "eksen": "y", "kal": 0.12},
	"Gri Zemin": {"yol": "res://parts/GriZemin.tscn", "ikon": "res://textures/gray_tile_wall_01_albedo.png", "eksen": "y", "kal": 0.12},
	"Duvar": {"yol": "res://parts/Duvar.tscn", "ikon": "res://textures/gray_tile_wall_clean_albedo.png", "eksen": "z", "kal": 0.2},
}

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

func _enter_tree() -> void:
	arac = HBoxContainer.new()
	arac.add_theme_constant_override("separation", 6)

	# KÜÇÜLT/BÜYÜT düğmesi
	kucult_btn = Button.new()
	kucult_btn.text = "🧩 ▾"
	kucult_btn.toggle_mode = true
	kucult_btn.button_pressed = true
	kucult_btn.tooltip_text = "Paneli küçült / büyüt"
	kucult_btn.toggled.connect(_kucult_buyut)
	arac.add_child(kucult_btn)

	# GÖVDE (küçültülünce gizlenen kısım)
	govde = HBoxContainer.new()
	govde.add_theme_constant_override("separation", 6)
	arac.add_child(govde)

	# Parça butonları — GÖRSELLİ (önizleme ikonu + ad)
	for ad: String in parcalar.keys():
		var b: Button = Button.new()
		b.text = " " + ad
		b.toggle_mode = true
		var ikon_yolu: String = parcalar[ad]["ikon"]
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

	durum = Label.new()
	durum.text = "  (mod: yok)"
	durum.modulate = Color(0.6, 0.85, 1.0)
	govde.add_child(durum)

	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, arac)

func _exit_tree() -> void:
	if arac:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, arac)
		arac.queue_free()
		arac = null

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
	# Seçilen parçanın ayarlarını Inspector'da göster (ölçek, döndürme, yükseklik, ızgara)
	EditorInterface.inspect_object(secili_ayar)
	durum.text = "  → KOY: %s (Inspector'dan ayarla → sahnede dokun)" % ad

func _sil_modu(btn: Button) -> void:
	mod = "sil"
	_butonlari_ayarla(btn)
	durum.text = "  → SİL (parçaya dokun)"

func _durdur() -> void:
	mod = "yok"
	_butonlari_ayarla(null)
	durum.text = "  (mod: yok)"

func _handles(_object: Object) -> bool:
	return mod != "yok"

func _forward_3d_gui_input(kamera: Camera3D, olay: InputEvent) -> int:
	if mod == "yok":
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var konum: Vector2 = Vector2.ZERO
	var dokundu: bool = false
	if olay is InputEventMouseButton and olay.pressed and olay.button_index == MOUSE_BUTTON_LEFT:
		konum = olay.position
		dokundu = true
	elif olay is InputEventScreenTouch and olay.pressed:
		konum = olay.position
		dokundu = true
	if not dokundu:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if mod == "koy":
		_yerlestir(kamera, konum)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	elif mod == "sil":
		_sil(kamera, konum)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _zemin_noktasi(kamera: Camera3D, ekran: Vector2):
	var baslangic: Vector3 = kamera.project_ray_origin(ekran)
	var yon: Vector3 = kamera.project_ray_normal(ekran)
	if absf(yon.y) < 0.000001:
		return null
	var t: float = -baslangic.y / yon.y
	if t < 0.0:
		return null
	return baslangic + yon * t

func _hucre_merkez(nokta: Vector3) -> Vector3:
	return Vector3(floorf(nokta.x / IZGARA) * IZGARA + IZGARA * 0.5, 0.0, floorf(nokta.z / IZGARA) * IZGARA + IZGARA * 0.5)

func _yerlestir(kamera: Camera3D, ekran: Vector2) -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		durum.text = "  Önce sahne aç (Harita.tscn)"
		return
	var carpma = _zemin_noktasi(kamera, ekran)
	if carpma == null:
		return
	# --- SİSTEMATİK IZGARA HİZALAMA ---
	# C = efektif hücre boyutu (parça ölçeğiyle birlikte büyür, böylece scale
	#     değişince parçalar üst üste binmeden kenar kenara dizilir).
	# Zemin/tavan (eksen "y") -> hücre MERKEZİNE oturur.
	# Duvar (ince panel)      -> ince ekseninde ızgara ÇİZGİSİNE (karo kenarına),
	#                            uzun ekseninde hücre MERKEZİNE oturur. Böylece
	#                            duvar karonun ortasında değil, kenarında durur.
	#                            Uzun/ince eksen, duvarın dönüşüne (donme_y) göre
	#                            otomatik belirlenir (0/180 = X boyunca, 90/270 = Z boyunca).
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
		var d: float = fmod(absf(donme), 180.0)
		if d > 45.0 and d < 135.0:
			# Duvar Z ekseni boyunca uzanır (ince eksen X): X = ızgara çizgisi, Z = merkez
			hedef = Vector3(roundf(carpma.x / C) * C, yuk, floorf(carpma.z / C) * C + C * 0.5)
		else:
			# Duvar X ekseni boyunca uzanır (ince eksen Z): X = merkez, Z = ızgara çizgisi
			hedef = Vector3(floorf(carpma.x / C) * C + C * 0.5, yuk, roundf(carpma.z / C) * C)
	# Aynı konumda aynı türden parça varsa üst üste bindirme (kopya/çakışma engelle).
	var tip_ad: String = secili_ad.replace(" ", "")
	for c in kok.get_children():
		if c is Node3D and c.has_meta("yp") and (c as Node3D).name.begins_with(tip_ad):
			var fark: Vector3 = (c as Node3D).position - hedef
			if absf(fark.x) < C * 0.45 and absf(fark.z) < C * 0.45 and absf(fark.y - yuk) < 0.5:
				durum.text = "  Bu konum zaten dolu (üst üste binme engellendi)"
				return
	var sahne: PackedScene = load(secili_yol) as PackedScene
	if sahne == null:
		return
	var ornek: Node3D = sahne.instantiate()
	ornek.name = secili_ad.replace(" ", "")
	ornek.position = hedef
	if secili_ayar != null:
		ornek.scale = Vector3.ONE * secili_ayar.olcek
		ornek.rotation = Vector3(0.0, deg_to_rad(secili_ayar.donme_y), 0.0)
		# Kalınlık: ince ekseni Inspector'daki değere göre ayarla
		var mi: MeshInstance3D = _mesh_bul(ornek)
		if mi != null and mi.mesh is BoxMesh:
			var bm: BoxMesh = (mi.mesh as BoxMesh).duplicate()
			var sz: Vector3 = bm.size
			if parcalar[secili_ad].get("eksen", "y") == "y":
				sz.y = secili_ayar.kalinlik
			else:
				sz.z = secili_ayar.kalinlik
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
	# Tıklanan noktaya EKRANDA en yakın parçayı bul (ızgaradan bağımsız, güvenilir)
	var en_yakin: Node3D = null
	var en_kucuk: float = 160.0   # px eşiği
	for c: Node in kok.get_children():
		if not _silinebilir(c):
			continue
		var sp: Vector2 = kamera.unproject_position(c.global_position)
		var d: float = sp.distance_to(ekran)
		if d < en_kucuk:
			en_kucuk = d
			en_yakin = c
	if en_yakin == null:
		return
	var ur: EditorUndoRedoManager = get_undo_redo()
	ur.create_action("Parça sil", UndoRedo.MERGE_DISABLE, kok)
	ur.add_do_method(kok, "remove_child", en_yakin)
	ur.add_undo_method(kok, "add_child", en_yakin)
	ur.add_undo_method(en_yakin, "set_owner", kok)
	ur.add_undo_reference(en_yakin)
	ur.commit_action()

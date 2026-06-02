@tool
extends EditorPlugin
## BACKROOMS LEKELEYİCİ
## Yerleştirici ile koyduğun duvar/zemin/tavan parçalarını boyar, lekeler, çamurlar.
## Yüzeye hizalı şeffaf "sticker" mesh basar (QuadMesh) — Decal kullanmaz, bu yüzden
## Mobile renderer dahil her render motorunda çalışır.

const KAPSAYICI_AD := "Lekeler"

var _kutuphane: LekeKutuphane
var _panel: LekePanel
var _dock: ScrollContainer
var _arac: HBoxContainer
var _boya_arac_btn: Button
var _sil_arac_btn: Button

# 3B viewport sürükleme durumu
var _basili := false
var _son_pos := Vector3.ZERO
var _gecerli_pos := false
var _birim_quad: QuadMesh    # tüm lekelerin paylaştığı birim kare (perf)

func _enter_tree() -> void:
	_kutuphane = LekeKutuphane.new()
	_panel = LekePanel.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.kur(_kutuphane)
	_panel.onbellek_temizle_istendi.connect(_kutuphane.onbellegi_temizle)
	# Uzun içerik için kaydırılabilir kapsayıcıya sar.
	_dock = ScrollContainer.new()
	_dock.name = "Lekeleyici"
	_dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dock.add_child(_panel)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, _dock)

	# Üst bara (3B editör menüsü) görünür AÇ/KAPA düğmeleri.
	_arac = HBoxContainer.new()
	_arac.add_theme_constant_override("separation", 4)
	_boya_arac_btn = Button.new()
	_boya_arac_btn.text = "🖌 Lekele"
	_boya_arac_btn.toggle_mode = true
	_boya_arac_btn.tooltip_text = "Lekeleme fırçasını aç/kapat (ayarlar sağdaki 'Lekeleyici' panelinde)"
	_boya_arac_btn.toggled.connect(func(acik: bool): _panel._mod_ayarla("boya" if acik else "yok"))
	_arac.add_child(_boya_arac_btn)
	_sil_arac_btn = Button.new()
	_sil_arac_btn.text = "🧽 Sil"
	_sil_arac_btn.toggle_mode = true
	_sil_arac_btn.modulate = Color(1.0, 0.78, 0.78)
	_sil_arac_btn.tooltip_text = "Leke silme modunu aç/kapat"
	_sil_arac_btn.toggled.connect(func(acik: bool): _panel._mod_ayarla("sil" if acik else "yok"))
	_arac.add_child(_sil_arac_btn)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _arac)

	# Panel mod değiştiğinde toolbar düğmelerini eşitle.
	_panel.mod_degisti.connect(_arac_guncelle)

	# Leke dokularını arka planda (kare kare) ön-ısıt: ilk fırçada donma olmasın.
	_onisit_baslat()

# Tüm leke dokularının alfasını, her karede bir tane üreterek önbelleğe alır.
# Editörü bloklamaz; kullanıcı boyamaya başladığında önbellek çoğunlukla sıcaktır.
func _onisit_baslat() -> void:
	if _kutuphane == null or _panel == null:
		return
	var liste := _kutuphane.yollar.duplicate()
	for yol in liste:
		if _kutuphane == null:   # eklenti bu sırada kapandıysa dur
			return
		_kutuphane.alfa_doku(yol, _panel.esik, _panel.yumusaklik)
		await get_tree().process_frame

func _exit_tree() -> void:
	if _arac:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _arac)
		_arac.queue_free()
		_arac = null
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	_panel = null
	_kutuphane = null

func _arac_guncelle(m: String) -> void:
	if _boya_arac_btn:
		_boya_arac_btn.set_pressed_no_signal(m == "boya")
	if _sil_arac_btn:
		_sil_arac_btn.set_pressed_no_signal(m == "sil")

func _handles(_o: Object) -> bool:
	return _panel != null and _panel.mod != "yok"

func _forward_3d_gui_input(kamera: Camera3D, olay: InputEvent) -> int:
	if _panel == null or _panel.mod == "yok":
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	# Basma / bırakma
	if olay is InputEventMouseButton:
		if olay.button_index == MOUSE_BUTTON_LEFT:
			if olay.pressed:
				_basili = true
				_gecerli_pos = false
				_islem(kamera, olay.position)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			else:
				_basili = false
				return EditorPlugin.AFTER_GUI_INPUT_STOP
	elif olay is InputEventScreenTouch:
		if olay.pressed:
			_basili = true
			_gecerli_pos = false
			_islem(kamera, olay.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		else:
			_basili = false
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	# Sürükleme (sadece boya modunda, basılıyken)
	if _basili and _panel.mod == "boya":
		var poz := Vector2.ZERO
		var var_mi := false
		if olay is InputEventMouseMotion and (olay.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			poz = olay.position; var_mi = true
		elif olay is InputEventScreenDrag:
			poz = olay.position; var_mi = true
		if var_mi:
			_surukle(kamera, poz)
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _islem(kamera: Camera3D, ekran: Vector2) -> void:
	if _panel.mod == "boya":
		_boya(kamera, ekran)
	elif _panel.mod == "sil":
		_sil(kamera, ekran)

func _surukle(kamera: Camera3D, ekran: Vector2) -> void:
	var kok := EditorInterface.get_edited_scene_root()
	if kok == null:
		return
	var v := LekeIsin.sahne_isin(kok, kamera, ekran)
	if not v.carpti:
		return
	if _gecerli_pos and v.nokta.distance_to(_son_pos) < _panel.aralik:
		return
	if not _yuzey_uygun(v.normal):
		return
	_leke_bas(kok, v.nokta, v.normal, v.dugum)
	_son_pos = v.nokta
	_gecerli_pos = true

func _boya(kamera: Camera3D, ekran: Vector2) -> void:
	var kok := EditorInterface.get_edited_scene_root()
	if kok == null:
		_panel._durum.text = "Önce sahneyi aç (Harita.tscn)"
		return
	var v := LekeIsin.sahne_isin(kok, kamera, ekran)
	if not v.carpti:
		return
	if not _yuzey_uygun(v.normal):
		_panel._durum.text = "Bu yüzey filtreye uymuyor (Yüzey: %s)" % _panel.yuzey_filtre
		return
	_leke_bas(kok, v.nokta, v.normal, v.dugum)
	_son_pos = v.nokta
	_gecerli_pos = true

## Tek tıkta saçılma adedince leke üretir, hepsini tek undo işleminde ekler.
func _leke_bas(kok: Node, nokta: Vector3, normal: Vector3, dugum: Node) -> void:
	var kapsayici := _kapsayici_bul_olustur(kok)
	var n := normal.normalized()
	if n.length() < 0.5:
		n = Vector3.UP  # bozuk/sıfır normal koruması (axis-normalized hatasını önler)
	# Teğet düzlem (saçılma ofseti için)
	var yardim := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var teg_x := yardim.cross(n).normalized()
	var teg_y := n.cross(teg_x).normalized()

	var sigdir := _panel.yuzeye_sigdir and dugum is MeshInstance3D
	var stickerlar: Array[MeshInstance3D] = []
	var adet := maxi(_panel.saci_sayi, 1)
	for i in adet:
		var merkez := nokta
		if i > 0 and _panel.saci_yaricap > 0.0:
			var ac := randf() * TAU
			var r := sqrt(randf()) * _panel.saci_yaricap
			merkez = nokta + teg_x * (cos(ac) * r) + teg_y * (sin(ac) * r)
		# Her damga için yüzey kenarına mesafe. Yüzey dışına düşeni ELE (taşmasın),
		# içindekinin boyutunu kenara sığacak şekilde kırp.
		var azami_yari := INF
		if sigdir:
			var kenar := _kenar_mesafe(dugum as MeshInstance3D, merkez, n)
			if kenar <= 0.03:
				continue  # zemin/duvar dışında -> atla
			azami_yari = kenar
		var yol := _panel.rastgele_yol()
		if yol == "":
			continue
		var s := _sticker_olustur(yol, merkez, n, teg_x, teg_y, i, azami_yari)
		if s != null:
			stickerlar.append(s)
	if stickerlar.is_empty():
		return

	var ur := get_undo_redo()
	ur.create_action("Leke bas (%d)" % stickerlar.size(), UndoRedo.MERGE_DISABLE, kok)
	for s in stickerlar:
		ur.add_do_method(kapsayici, "add_child", s, true)
		ur.add_do_method(s, "set_owner", kok)
		ur.add_do_reference(s)
		ur.add_undo_method(kapsayici, "remove_child", s)
	ur.commit_action()
	_panel._durum.text = "Leke basıldı (%d). Yüzey: %s" % [stickerlar.size(), _panel.yuzey_filtre]

func _sticker_olustur(yol: String, nokta: Vector3, n: Vector3, teg_x: Vector3, teg_y: Vector3, indeks: int, azami_yari: float = INF) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Leke"
	# min/max ters girilse bile geçerli aralık (negatif/sıfır boyut olmasın)
	var bmin := maxf(minf(_panel.boyut_min, _panel.boyut_max), 0.05)
	var bmax := maxf(_panel.boyut_min, _panel.boyut_max)
	var s := randf_range(bmin, bmax)
	# Yüzeyden taşmasın: dairesel falloff sayesinde köşeler zaten sönük olduğundan
	# kenara kadar büyüyebilir; faint kenar bile yüzey içinde kalsın (yari*1.8).
	if azami_yari < INF:
		var ust := maxf(azami_yari * 1.8, 0.04)
		s = minf(s, ust)
	# HIZ: her lekeye yeni mesh yerine PAYLAŞILAN birim kareyi ölçekle (transform'da).
	if _birim_quad == null:
		_birim_quad = QuadMesh.new()
		_birim_quad.size = Vector2(1, 1)
	mi.mesh = _birim_quad

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _kutuphane.alfa_doku(yol, _panel.esik, _panel.yumusaklik)
	var omin := clampf(minf(_panel.opaklik_min, _panel.opaklik_max), 0.0, 1.0)
	var omax := clampf(maxf(_panel.opaklik_min, _panel.opaklik_max), 0.0, 1.0)
	var op := maxf(randf_range(omin, omax), 0.08)  # tamamen görünmez olmasın
	mat.albedo_color = Color(_panel.renk.r, _panel.renk.g, _panel.renk.b, op)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _panel.kendinden_isikli:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _panel.islak:
		mat.metallic = 0.55
		mat.roughness = 0.12
	else:
		mat.roughness = 0.95
	# Üst üste binen lekeler için çizim önceliği (yeni leke üstte).
	mat.render_priority = clampi(1 + indeks, 1, 100)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Yönelim: QuadMesh +Z'yi yüzey normaline hizala; birim kareyi s ile ölçekle
	var b := Basis(teg_x * s, teg_y * s, n)
	if _panel.rastgele_donme:
		b = b.rotated(n, randf() * TAU)
	# Yüzeye yapışsın: ofset birikimi yok (sıralama render_priority ile yapılır),
	# yalnızca z-fighting için minik artış. Böylece leke havada durmaz.
	var ek := _panel.ofset + indeks * 0.0003
	mi.transform = Transform3D(b, nokta + n * ek)
	mi.set_meta("leke", true)
	return mi

func _yuzey_uygun(normal: Vector3) -> bool:
	var ny := normal.normalized().y
	match _panel.yuzey_filtre:
		"zemin": return ny > 0.6
		"tavan": return ny < -0.6
		"duvar": return absf(ny) <= 0.6
		_: return true

## Çarpılan yüzeyin kenarına dünya-uzayında İŞARETLİ mesafe (negatif = yüzey dışı).
## Mesh AABB'sinin, yüzey normaline dik iki ekseni kullanılır. Hem taşma elemesi
## hem de boyut kırpması bunu kullanır.
func _kenar_mesafe(mi: MeshInstance3D, dunya_nokta: Vector3, dunya_n: Vector3) -> float:
	if mi.mesh == null:
		return INF
	var gt := mi.global_transform
	var yp := gt.affine_inverse() * dunya_nokta
	var aabb := mi.mesh.get_aabb()
	var merkez := aabb.position + aabb.size * 0.5
	var yari := aabb.size * 0.5
	var ln := (gt.basis.inverse().transposed() * dunya_n).normalized()
	var olcek := gt.basis.get_scale()
	var ax := absf(ln.x)
	var ay := absf(ln.y)
	var az := absf(ln.z)
	if ax >= ay and ax >= az:
		return minf((yari.y - absf(yp.y - merkez.y)) * olcek.y, (yari.z - absf(yp.z - merkez.z)) * olcek.z)
	elif ay >= ax and ay >= az:
		return minf((yari.x - absf(yp.x - merkez.x)) * olcek.x, (yari.z - absf(yp.z - merkez.z)) * olcek.z)
	return minf((yari.x - absf(yp.x - merkez.x)) * olcek.x, (yari.y - absf(yp.y - merkez.y)) * olcek.y)

func _kapsayici_bul_olustur(kok: Node) -> Node3D:
	for c in kok.get_children():
		if c is Node3D and c.has_meta("leke_kapsayici"):
			return c
	var kap := Node3D.new()
	kap.name = KAPSAYICI_AD
	kap.set_meta("leke_kapsayici", true)
	kok.add_child(kap)
	kap.owner = kok
	kap.transform = Transform3D.IDENTITY
	return kap

func _sil(kamera: Camera3D, ekran: Vector2) -> void:
	var kok := EditorInterface.get_edited_scene_root()
	if kok == null:
		return
	var lekeler: Array[Node] = []
	_lekeleri_topla(kok, lekeler)
	var en_yakin: Node3D = null
	var en_kucuk := 64.0  # px eşiği (dokunmatik dostu)
	for l in lekeler:
		var sp := kamera.unproject_position((l as Node3D).global_position)
		var d := sp.distance_to(ekran)
		if d < en_kucuk:
			en_kucuk = d
			en_yakin = l
	if en_yakin == null:
		return
	var ebeveyn := en_yakin.get_parent()
	var ur := get_undo_redo()
	ur.create_action("Leke sil", UndoRedo.MERGE_DISABLE, kok)
	ur.add_do_method(ebeveyn, "remove_child", en_yakin)
	ur.add_undo_method(ebeveyn, "add_child", en_yakin, true)
	ur.add_undo_method(en_yakin, "set_owner", kok)
	ur.add_undo_reference(en_yakin)
	ur.commit_action()
	_panel._durum.text = "Leke silindi"

func _lekeleri_topla(n: Node, dizi: Array[Node]) -> void:
	if n.has_meta("leke"):
		dizi.append(n)
	for c in n.get_children():
		_lekeleri_topla(c, dizi)

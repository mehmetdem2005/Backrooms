@tool
extends EditorPlugin
## Parça Yerleştirici: yan panelden parça seç, sahnede tıkladığın yere koyar.
## Sol tık = yerleştir • Sağ tık = sil • Izgara: 4 m hizalı.

const IZGARA: float = 4.0

# Parça listesi: Türkçe ad -> sahne yolu. Yeni parça eklendikçe buraya eklenir.
var parcalar: Dictionary = {
	"Zemin": "res://parts/Zemin.tscn",
}

var panel: VBoxContainer
var durum: Label
var secili_yol: String = ""
var secili_ad: String = ""
var yerlestirme_acik: bool = false
var butonlar: Array = []

func _enter_tree() -> void:
	panel = VBoxContainer.new()
	panel.name = "Yerleştirici"
	panel.custom_minimum_size = Vector2(200, 0)

	var baslik: Label = Label.new()
	baslik.text = "🧩  PARÇA YERLEŞTİRİCİ"
	panel.add_child(baslik)

	var ipucu: Label = Label.new()
	ipucu.text = "1) Bir parça seç\n2) Sahnede tıkla = koy\n3) Sağ tık = sil"
	ipucu.modulate = Color(0.75, 0.8, 0.85)
	panel.add_child(ipucu)

	var ayrac: HSeparator = HSeparator.new()
	panel.add_child(ayrac)

	for ad: String in parcalar.keys():
		var b: Button = Button.new()
		b.text = "▸  " + ad
		b.toggle_mode = true
		b.pressed.connect(_parca_secildi.bind(ad, b))
		panel.add_child(b)
		butonlar.append(b)

	var dur: Button = Button.new()
	dur.text = "✋  Yerleştirmeyi durdur"
	dur.pressed.connect(_durdur)
	panel.add_child(dur)

	durum = Label.new()
	durum.text = "Henüz parça seçilmedi."
	durum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	durum.custom_minimum_size = Vector2(190, 0)
	durum.modulate = Color(0.6, 0.85, 1.0)
	panel.add_child(durum)

	add_control_to_dock(DOCK_SLOT_RIGHT_UL, panel)

func _exit_tree() -> void:
	if panel:
		remove_control_from_docks(panel)
		panel.queue_free()
		panel = null

func _parca_secildi(ad: String, btn: Button) -> void:
	secili_ad = ad
	secili_yol = parcalar[ad]
	yerlestirme_acik = true
	for b: Button in butonlar:
		b.button_pressed = (b == btn)
	durum.text = "Seçili: %s\nSahnede TIKLA → koy\nSağ tık → sil" % ad

func _durdur() -> void:
	yerlestirme_acik = false
	for b: Button in butonlar:
		b.button_pressed = false
	durum.text = "Yerleştirme kapalı."

func _handles(_object: Object) -> bool:
	# Yerleştirme açıkken 3B görünüm girişini biz alalım.
	return yerlestirme_acik

func _forward_3d_gui_input(kamera: Camera3D, olay: InputEvent) -> int:
	if not yerlestirme_acik or secili_yol == "":
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var konum: Vector2 = Vector2.ZERO
	var sol: bool = false
	var sag: bool = false
	if olay is InputEventMouseButton and olay.pressed:
		konum = olay.position
		sol = olay.button_index == MOUSE_BUTTON_LEFT
		sag = olay.button_index == MOUSE_BUTTON_RIGHT
	elif olay is InputEventScreenTouch and olay.pressed:
		konum = olay.position
		sol = true
	else:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if sol:
		_yerlestir(kamera, konum)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if sag:
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
		durum.text = "Önce bir sahne aç (Harita.tscn)."
		return
	var carpma = _zemin_noktasi(kamera, ekran)
	if carpma == null:
		return
	var hedef: Vector3 = _hucre_merkez(carpma)
	var sahne: PackedScene = load(secili_yol) as PackedScene
	if sahne == null:
		return
	var ornek: Node3D = sahne.instantiate()
	ornek.position = hedef
	var ur: EditorUndoRedoManager = get_undo_redo()
	ur.create_action("Parça yerleştir: " + secili_ad)
	ur.add_do_method(kok, "add_child", ornek)
	ur.add_do_method(ornek, "set_owner", kok)
	ur.add_do_reference(ornek)
	ur.add_undo_method(kok, "remove_child", ornek)
	ur.commit_action()

func _sil(kamera: Camera3D, ekran: Vector2) -> void:
	var kok: Node = EditorInterface.get_edited_scene_root()
	if kok == null:
		return
	var carpma = _zemin_noktasi(kamera, ekran)
	if carpma == null:
		return
	var hedef_hucre: Vector2 = Vector2(floorf(carpma.x / IZGARA), floorf(carpma.z / IZGARA))
	for c: Node in kok.get_children():
		if c is Node3D:
			var ch: Vector2 = Vector2(floorf(c.position.x / IZGARA), floorf(c.position.z / IZGARA))
			if ch == hedef_hucre and c.name.begins_with("Zemin"):
				var ur: EditorUndoRedoManager = get_undo_redo()
				ur.create_action("Parça sil")
				ur.add_do_method(kok, "remove_child", c)
				ur.add_undo_method(kok, "add_child", c)
				ur.add_undo_method(c, "set_owner", kok)
				ur.add_undo_reference(c)
				ur.commit_action()
				return

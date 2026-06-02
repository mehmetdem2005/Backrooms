@tool
extends EditorPlugin
## Parça Yerleştirici (dokunmatik dostu):
## Panelden bir mod seç (parça = KOY, ya da SİL), sonra sahnede DOKUN.
## Her işlem buton — sağ tık yok. Izgara: 4 m hizalı.

const IZGARA: float = 4.0

# Parça listesi: Türkçe ad -> sahne yolu. Yeni parça buraya eklenir.
var parcalar: Dictionary = {
	"Zemin": "res://parts/Zemin.tscn",
}

var panel: VBoxContainer
var durum: Label
var mod: String = "yok"          # "yok" | "koy" | "sil"
var secili_ad: String = ""
var secili_yol: String = ""
var butonlar: Array = []          # tüm mod butonları (radyo gibi)

func _enter_tree() -> void:
	panel = VBoxContainer.new()
	panel.name = "Yerleştirici"
	panel.custom_minimum_size = Vector2(210, 0)

	var baslik: Label = Label.new()
	baslik.text = "🧩  PARÇA YERLEŞTİRİCİ"
	panel.add_child(baslik)

	var ipucu: Label = Label.new()
	ipucu.text = "Bir mod seç, sonra sahnede DOKUN."
	ipucu.modulate = Color(0.75, 0.8, 0.85)
	ipucu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ipucu.custom_minimum_size = Vector2(200, 0)
	panel.add_child(ipucu)

	panel.add_child(HSeparator.new())

	var l1: Label = Label.new()
	l1.text = "PARÇALAR (dokun = koy)"
	l1.modulate = Color(0.7, 0.9, 0.7)
	panel.add_child(l1)

	for ad: String in parcalar.keys():
		var b: Button = Button.new()
		b.text = "▸  " + ad
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(_parca_modu.bind(ad, b))
		panel.add_child(b)
		butonlar.append(b)

	panel.add_child(HSeparator.new())

	var sil_btn: Button = Button.new()
	sil_btn.text = "🗑  SİL  (dokun = sil)"
	sil_btn.toggle_mode = true
	sil_btn.custom_minimum_size = Vector2(0, 38)
	sil_btn.modulate = Color(1.0, 0.7, 0.7)
	sil_btn.pressed.connect(_sil_modu.bind(sil_btn))
	panel.add_child(sil_btn)
	butonlar.append(sil_btn)

	var dur_btn: Button = Button.new()
	dur_btn.text = "✋  DURDUR"
	dur_btn.custom_minimum_size = Vector2(0, 38)
	dur_btn.pressed.connect(_durdur)
	panel.add_child(dur_btn)

	panel.add_child(HSeparator.new())

	durum = Label.new()
	durum.text = "Mod: yok"
	durum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	durum.custom_minimum_size = Vector2(200, 0)
	durum.modulate = Color(0.6, 0.85, 1.0)
	panel.add_child(durum)

	add_control_to_dock(DOCK_SLOT_RIGHT_UL, panel)

func _exit_tree() -> void:
	if panel:
		remove_control_from_docks(panel)
		panel.queue_free()
		panel = null

func _butonlari_ayarla(aktif: Button) -> void:
	for b: Button in butonlar:
		b.button_pressed = (b == aktif)

func _parca_modu(ad: String, btn: Button) -> void:
	mod = "koy"
	secili_ad = ad
	secili_yol = parcalar[ad]
	_butonlari_ayarla(btn)
	durum.text = "Mod: KOY → %s\nSahnede dokun, yerleşir." % ad

func _sil_modu(btn: Button) -> void:
	mod = "sil"
	_butonlari_ayarla(btn)
	durum.text = "Mod: SİL\nSahnede bir parçaya dokun, silinir."

func _durdur() -> void:
	mod = "yok"
	_butonlari_ayarla(null)
	durum.text = "Mod: yok (dokunma kapalı)"

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
			if ch == hedef_hucre:
				var ur: EditorUndoRedoManager = get_undo_redo()
				ur.create_action("Parça sil")
				ur.add_do_method(kok, "remove_child", c)
				ur.add_undo_method(kok, "add_child", c)
				ur.add_undo_method(c, "set_owner", kok)
				ur.add_undo_reference(c)
				ur.commit_action()
				return

@tool
class_name LekePanel
extends VBoxContainer
## Lekeleyici yan panel (dock). Tüm gelişmiş fırça ayarları burada tutulur;
## eklenti (lekeleyici.gd) bu paneldeki değerleri okuyarak leke basar.

signal mod_degisti(yeni_mod: String)
signal onbellek_temizle_istendi()
signal kirlet_istendi(kapsam: String)     # "secili" | "tum"
signal kir_temizle_istendi()
signal atmosfer_istendi()

# --- Durum (eklenti bunları okur) ---
var mod: String = "yok"                       # "yok" | "boya" | "sil"
var aktif_yollar: Array[String] = []          # rotasyondaki seçili leke yolları
var boyut_min: float = 0.45
var boyut_max: float = 1.2
var opaklik_min: float = 0.4
var opaklik_max: float = 0.8
var saci_sayi: int = 1
var saci_yaricap: float = 0.4
var aralik: float = 0.35                        # sürükleyerek boyamada adım (m)
var rastgele_donme: bool = true
var yuzeye_sigdir: bool = true                  # leke yüzey kenarından taşmasın
var yuzey_filtre: String = "hepsi"             # hepsi|zemin|duvar|tavan
var renk: Color = Color(1, 1, 1)               # tint (dokuyu çarpar)
var esik: float = 0.22
var yumusaklik: float = 0.12
var islak: bool = false
var kendinden_isikli: bool = false
var ofset: float = 0.006                       # yüzeyden uzaklık (z-fighting önler)
# --- Otomatik kirletme (MultiMesh) ---
var kir_yogunluk: int = 6                       # m² başına grime damgası (küçük yamalar)
var kir_islaklik: float = 0.5                  # 0 mat .. 1 ıslak/parlak
var kir_kenar: float = 0.5                     # kenarlara/derzlere yoğunlaşma
var kir_koyuluk: float = 0.45                  # çamur koyuluğu (0 açık kahve .. 1 koyu)

var _kutuphane: LekeKutuphane
var _palet_dugmeleri: Dictionary = {}          # yol -> Button
var _boya_btn: Button
var _sil_btn: Button
var _durum: Label
# Hazır ayarın görsel olarak tazeleyeceği kontroller
var _sl_boyut_min: HSlider
var _sl_boyut_max: HSlider
var _sl_op_min: HSlider
var _sl_op_max: HSlider
var _sl_saci: HSlider
var _renk_btn: ColorPickerButton
var _islak_chk: CheckBox
var _isik_chk: CheckBox

# Hazır ayarlar: ad -> sözlük
const ON_AYARLAR := {
	"Çamur": {"renk": Color(0.55, 0.4, 0.26), "op": [0.6, 0.95], "boyut": [0.9, 2.0], "islak": false, "isikli": false, "saci": 2},
	"Kir / Toz": {"renk": Color(0.5, 0.5, 0.5), "op": [0.25, 0.5], "boyut": [1.2, 2.4], "islak": false, "isikli": false, "saci": 1},
	"Su Lekesi": {"renk": Color(0.55, 0.57, 0.62), "op": [0.2, 0.45], "boyut": [0.8, 1.6], "islak": true, "isikli": false, "saci": 1},
	"Kan": {"renk": Color(0.5, 0.04, 0.04), "op": [0.6, 0.9], "boyut": [0.5, 1.3], "islak": true, "isikli": false, "saci": 2},
	"Yağ / Petrol": {"renk": Color(0.09, 0.09, 0.12), "op": [0.7, 0.95], "boyut": [0.7, 1.6], "islak": true, "isikli": false, "saci": 1},
	"Küf": {"renk": Color(0.26, 0.36, 0.2), "op": [0.4, 0.7], "boyut": [0.8, 1.8], "islak": false, "isikli": false, "saci": 3},
	"Boya Sıçraması": {"renk": Color(0.85, 0.2, 0.15), "op": [0.8, 1.0], "boyut": [0.4, 1.0], "islak": false, "isikli": true, "saci": 4},
}

func kur(kutuphane: LekeKutuphane) -> void:
	_kutuphane = kutuphane
	for y in _kutuphane.yollar:
		aktif_yollar.append(y)
	_arayuz_olustur()

func _arayuz_olustur() -> void:
	name = "Lekeleyici"
	add_theme_constant_override("separation", 6)

	var baslik := Label.new()
	baslik.text = "🖌  BACKROOMS LEKELEYİCİ"
	baslik.add_theme_font_size_override("font_size", 15)
	add_child(baslik)

	# --- Mod düğmeleri ---
	var mod_sat := HBoxContainer.new()
	mod_sat.add_theme_constant_override("separation", 4)
	add_child(mod_sat)
	_boya_btn = Button.new()
	_boya_btn.text = "🖌 Boya"
	_boya_btn.toggle_mode = true
	_boya_btn.custom_minimum_size = Vector2(0, 40)
	_boya_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boya_btn.pressed.connect(_mod_ayarla.bind("boya"))
	mod_sat.add_child(_boya_btn)
	_sil_btn = Button.new()
	_sil_btn.text = "🧽 Sil"
	_sil_btn.toggle_mode = true
	_sil_btn.custom_minimum_size = Vector2(0, 40)
	_sil_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sil_btn.modulate = Color(1.0, 0.78, 0.78)
	_sil_btn.pressed.connect(_mod_ayarla.bind("sil"))
	mod_sat.add_child(_sil_btn)
	var dur_btn := Button.new()
	dur_btn.text = "✋"
	dur_btn.tooltip_text = "Durdur"
	dur_btn.custom_minimum_size = Vector2(40, 40)
	dur_btn.pressed.connect(_mod_ayarla.bind("yok"))
	mod_sat.add_child(dur_btn)

	_durum = Label.new()
	_durum.text = "Mod: yok  —  Boya'ya bas, sahnede sürükle"
	_durum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_durum.modulate = Color(0.65, 0.85, 1.0)
	add_child(_durum)

	add_child(HSeparator.new())

	# --- Hazır ayarlar ---
	var ona_lbl := Label.new()
	ona_lbl.text = "Hazır Ayar"
	add_child(ona_lbl)
	var ona_opt := OptionButton.new()
	ona_opt.add_item("— seç —", 0)
	var idx := 1
	for ad in ON_AYARLAR.keys():
		ona_opt.add_item(ad, idx)
		idx += 1
	ona_opt.item_selected.connect(_on_ayar_secildi.bind(ona_opt))
	add_child(ona_opt)

	add_child(HSeparator.new())

	# --- Leke paleti ---
	var palet_baslik := HBoxContainer.new()
	add_child(palet_baslik)
	var pl := Label.new()
	pl.text = "Leke Paleti"
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palet_baslik.add_child(pl)
	var tum_btn := Button.new()
	tum_btn.text = "Tümü"
	tum_btn.pressed.connect(_palet_hepsi.bind(true))
	palet_baslik.add_child(tum_btn)
	var hic_btn := Button.new()
	hic_btn.text = "Hiç"
	hic_btn.pressed.connect(_palet_hepsi.bind(false))
	palet_baslik.add_child(hic_btn)

	var izgara := GridContainer.new()
	izgara.columns = 3
	add_child(izgara)
	for yol in _kutuphane.yollar:
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = true
		b.custom_minimum_size = Vector2(92, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.expand_icon = true
		var tex := _kutuphane.onizleme(yol, 160)
		if tex != null:
			b.icon = tex
		b.tooltip_text = yol.get_file()
		b.toggled.connect(_palet_degisti.bind(yol))
		izgara.add_child(b)
		_palet_dugmeleri[yol] = b

	add_child(HSeparator.new())

	# --- Fırça ayarları (sliderlar) ---
	_sl_boyut_min = _kaydirici("Boyut Min (m)", 0.1, 4.0, 0.05, boyut_min, func(v): boyut_min = v)
	_sl_boyut_max = _kaydirici("Boyut Max (m)", 0.1, 5.0, 0.05, boyut_max, func(v): boyut_max = v)
	_sl_op_min = _kaydirici("Opaklık Min", 0.0, 1.0, 0.01, opaklik_min, func(v): opaklik_min = v)
	_sl_op_max = _kaydirici("Opaklık Max", 0.0, 1.0, 0.01, opaklik_max, func(v): opaklik_max = v)
	_sl_saci = _kaydirici("Saçılma Adedi", 1, 12, 1, saci_sayi, func(v): saci_sayi = int(v))
	_kaydirici("Saçılma Yarıçapı (m)", 0.0, 4.0, 0.05, saci_yaricap, func(v): saci_yaricap = v)
	_kaydirici("Sürükleme Aralığı (m)", 0.05, 3.0, 0.05, aralik, func(v): aralik = v)
	_kaydirici("Yüzeyden Uzaklık", 0.002, 0.03, 0.001, ofset, func(v): ofset = v)

	add_child(HSeparator.new())

	# --- Renk / kenar ---
	var renk_sat := HBoxContainer.new()
	add_child(renk_sat)
	var renk_lbl := Label.new()
	renk_lbl.text = "Renk Tonu"
	renk_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	renk_sat.add_child(renk_lbl)
	_renk_btn = ColorPickerButton.new()
	_renk_btn.color = renk
	_renk_btn.custom_minimum_size = Vector2(80, 30)
	_renk_btn.color_changed.connect(func(c): renk = c)
	renk_sat.add_child(_renk_btn)

	_kaydirici("Kenar Eşiği (koyu zemini kes)", 0.0, 0.5, 0.01, esik, func(v): _esik_ayarla(v))
	_kaydirici("Kenar Yumuşaklığı", 0.01, 0.6, 0.01, yumusaklik, func(v): _yumusaklik_ayarla(v))

	# --- Yüzey filtresi ---
	var yf_sat := HBoxContainer.new()
	add_child(yf_sat)
	var yf_lbl := Label.new()
	yf_lbl.text = "Yüzey"
	yf_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yf_sat.add_child(yf_lbl)
	var yf_opt := OptionButton.new()
	yf_opt.add_item("Hepsi", 0)
	yf_opt.add_item("Zemin", 1)
	yf_opt.add_item("Duvar", 2)
	yf_opt.add_item("Tavan", 3)
	yf_opt.item_selected.connect(_yuzey_secildi)
	yf_sat.add_child(yf_opt)

	# --- Anahtarlar ---
	var donme_chk := CheckBox.new()
	donme_chk.text = "Rastgele döndür"
	donme_chk.button_pressed = rastgele_donme
	donme_chk.toggled.connect(func(v): rastgele_donme = v)
	add_child(donme_chk)

	var sigdir_chk := CheckBox.new()
	sigdir_chk.text = "Yüzeye sığdır (taşmasın)"
	sigdir_chk.button_pressed = yuzeye_sigdir
	sigdir_chk.toggled.connect(func(v): yuzeye_sigdir = v)
	add_child(sigdir_chk)

	_islak_chk = CheckBox.new()
	_islak_chk.text = "Islak / parlak görünüm"
	_islak_chk.button_pressed = islak
	_islak_chk.toggled.connect(func(v): islak = v)
	add_child(_islak_chk)

	_isik_chk = CheckBox.new()
	_isik_chk.text = "Kendinden ışıklı (unshaded)"
	_isik_chk.button_pressed = kendinden_isikli
	_isik_chk.toggled.connect(func(v): kendinden_isikli = v)
	add_child(_isik_chk)

	add_child(HSeparator.new())

	# --- OTOMATİK KİRLETME (MultiMesh, elle boyamadan) ---
	var ok_baslik := Label.new()
	ok_baslik.text = "🌫 OTOMATİK KİRLETME (MultiMesh)"
	ok_baslik.add_theme_font_size_override("font_size", 14)
	add_child(ok_baslik)
	var ok_aciklama := Label.new()
	ok_aciklama.text = "Seçili yüzeyleri ya da tüm parçaları tek tıkla profesyonel, ıslak, kenarlarda yoğunlaşan kire boğar. Tek MultiMesh = hızlı."
	ok_aciklama.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ok_aciklama.modulate = Color(0.7, 0.78, 0.7)
	add_child(ok_aciklama)
	_kaydirici("Yoğunluk (m²/adet)", 1, 30, 1, kir_yogunluk, func(v): kir_yogunluk = int(v))
	_kaydirici("Islaklık / parlaklık", 0.0, 1.0, 0.01, kir_islaklik, func(v): kir_islaklik = v)
	_kaydirici("Kenar yoğunlaşması", 0.0, 1.0, 0.01, kir_kenar, func(v): kir_kenar = v)
	_kaydirici("Koyuluk", 0.0, 1.0, 0.01, kir_koyuluk, func(v): kir_koyuluk = v)
	var kir_sat := HBoxContainer.new()
	add_child(kir_sat)
	var kir_sec_btn := Button.new()
	kir_sec_btn.text = "Seçiliyi kirlet"
	kir_sec_btn.custom_minimum_size = Vector2(0, 38)
	kir_sec_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kir_sec_btn.pressed.connect(func(): kirlet_istendi.emit("secili"))
	kir_sat.add_child(kir_sec_btn)
	var kir_tum_btn := Button.new()
	kir_tum_btn.text = "Tümünü kirlet"
	kir_tum_btn.custom_minimum_size = Vector2(0, 38)
	kir_tum_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kir_tum_btn.pressed.connect(func(): kirlet_istendi.emit("tum"))
	kir_sat.add_child(kir_tum_btn)
	var kir_temiz_btn := Button.new()
	kir_temiz_btn.text = "Otomatik kiri temizle"
	kir_temiz_btn.modulate = Color(1.0, 0.8, 0.8)
	kir_temiz_btn.pressed.connect(func(): kir_temizle_istendi.emit())
	add_child(kir_temiz_btn)
	var atm_btn := Button.new()
	atm_btn.text = "🌑 Karanlık ıslak atmosfer kur"
	atm_btn.tooltip_text = "Koyu WorldEnvironment + tavan ışıkları ekler (ıslak yansıma görünür olur)"
	atm_btn.custom_minimum_size = Vector2(0, 38)
	atm_btn.pressed.connect(func(): atmosfer_istendi.emit())
	add_child(atm_btn)

	add_child(HSeparator.new())
	var ipucu := Label.new()
	ipucu.text = "İpucu: Sahnede sol tıkla/dokun ve sürükle. Sil modunda lekeye dokun."
	ipucu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ipucu.modulate = Color(0.7, 0.7, 0.7)
	add_child(ipucu)

# --- Yardımcılar ---

func _kaydirici(etiket: String, mn: float, mx: float, adim: float, deger: float, geri: Callable) -> HSlider:
	var sat := VBoxContainer.new()
	sat.add_theme_constant_override("separation", 0)
	add_child(sat)
	var lbl := Label.new()
	lbl.text = "%s: %s" % [etiket, _bicim(deger, adim)]
	sat.add_child(lbl)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = adim
	s.value = deger
	s.custom_minimum_size = Vector2(0, 22)
	s.value_changed.connect(func(v):
		lbl.text = "%s: %s" % [etiket, _bicim(v, adim)]
		geri.call(v))
	sat.add_child(s)
	return s

func _bicim(v: float, adim: float) -> String:
	if adim >= 1.0:
		return str(int(round(v)))
	return "%0.3f" % v if adim < 0.01 else "%0.2f" % v

func _mod_ayarla(yeni: String) -> void:
	mod = yeni
	_boya_btn.button_pressed = (yeni == "boya")
	_sil_btn.button_pressed = (yeni == "sil")
	match yeni:
		"boya": _durum.text = "Mod: BOYA — sahnede sürükleyerek lekele"
		"sil": _durum.text = "Mod: SİL — silmek istediğin lekeye dokun"
		_: _durum.text = "Mod: yok"
	mod_degisti.emit(yeni)

func _palet_degisti(_acik: bool, yol: String) -> void:
	_palet_guncelle()

func _palet_hepsi(ac: bool) -> void:
	for yol in _palet_dugmeleri:
		_palet_dugmeleri[yol].button_pressed = ac
	_palet_guncelle()

func _palet_guncelle() -> void:
	aktif_yollar.clear()
	for yol in _palet_dugmeleri:
		if _palet_dugmeleri[yol].button_pressed:
			aktif_yollar.append(yol)

func _yuzey_secildi(i: int) -> void:
	yuzey_filtre = ["hepsi", "zemin", "duvar", "tavan"][i]

func _esik_ayarla(v: float) -> void:
	esik = v
	onbellek_temizle_istendi.emit()

func _yumusaklik_ayarla(v: float) -> void:
	yumusaklik = v
	onbellek_temizle_istendi.emit()

func _on_ayar_secildi(i: int, opt: OptionButton) -> void:
	if i <= 0:
		return
	var ad := opt.get_item_text(i)
	if not ON_AYARLAR.has(ad):
		return
	var p: Dictionary = ON_AYARLAR[ad]
	# Kontrolleri ayarla — value_changed/toggled/color_changed sinyalleri
	# ilgili değişkenleri otomatik günceller, böylece panel hep senkron kalır.
	_renk_btn.color = p["renk"]
	renk = p["renk"]
	_sl_op_min.value = p["op"][0]
	_sl_op_max.value = p["op"][1]
	_sl_boyut_min.value = p["boyut"][0]
	_sl_boyut_max.value = p["boyut"][1]
	_sl_saci.value = p["saci"]
	_islak_chk.button_pressed = p["islak"]
	_isik_chk.button_pressed = p["isikli"]
	islak = p["islak"]
	kendinden_isikli = p["isikli"]
	_durum.text = "Hazır ayar uygulandı: %s (panelden ince ayar yapabilirsin)" % ad

## Rotasyondan rastgele bir leke yolu döndürür (palet seçimine göre).
func rastgele_yol() -> String:
	if aktif_yollar.is_empty():
		if _kutuphane.yollar.is_empty():
			return ""
		return _kutuphane.yollar[randi() % _kutuphane.yollar.size()]
	return aktif_yollar[randi() % aktif_yollar.size()]

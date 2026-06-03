@tool
class_name YerlestirmePanel
extends PanelContainer
## Yerleştirici ÜST BARI — 3B görünümün üstüne oturan yatay, kompakt, dokunmatik
## dostu kontrol şeridi. Yan dock yerine üstte durur; dar ekranda satırlara sarar.
## Tüm durum burada tutulur; eklenti (yerlestirici.gd) bu paneli okuyarak çalışır.
## Her parça kendi ayarını (ölçek/döndürme/yükseklik/ızgara) hatırlar.

signal mod_degisti(m: String)
signal parca_secildi(ad: String)
signal yenile_istendi()
signal grubu_temizle_istendi()
signal tumunu_temizle_istendi()
signal son_parca_istendi()

const KATEGORI_SIRA := ["Zeminler", "Duvarlar", "Tavanlar", "Diğer"]

var mod: String = "yok"
var secili_ad: String = ""
var snap_acik: bool = true
var grup_adi: String = "Parcalar"

var _parcalar: Dictionary = {}          # ad -> bilgi (eklentiden)
var _ayarlar: Dictionary = {}           # ad -> {olcek, donme, yukseklik, izgara}

var _durum: Label
var _sayac: Label
var _mod_koy: Button
var _mod_sil: Button
var _parca_opt: OptionButton
var _sp_olcek: SpinBox
var _sp_donme: SpinBox
var _sp_yuk: SpinBox
var _sp_izgara: SpinBox
var _snap_chk: CheckButton
var _grup_alani: LineEdit
var _guncelleniyor: bool = false        # SpinBox geri-besleme döngüsünü engeller

func kur(parcalar: Dictionary) -> void:
	_parcalar = parcalar
	_arayuz_olustur()
	_secimi_uygula()

# --- Geçerli parçanın ayarına erişim (eklenti bunları okur) ---
func _ayar(ad: String) -> Dictionary:
	if ad == "":
		return {"olcek": 1.0, "donme": 0.0, "yukseklik": 0.0, "izgara": 4.0}
	if not _ayarlar.has(ad):
		var vy: float = 0.0
		if _parcalar.has(ad):
			vy = float(_parcalar[ad].get("yuk", 0.0))
		_ayarlar[ad] = {"olcek": 1.0, "donme": 0.0, "yukseklik": vy, "izgara": 4.0}
	return _ayarlar[ad]

func olcek() -> float: return _ayar(secili_ad).olcek
func donme() -> float: return _ayar(secili_ad).donme
func yukseklik() -> float: return _ayar(secili_ad).yukseklik
func izgara() -> float: return _ayar(secili_ad).izgara

func donme_ayarla(v: float) -> void:
	_ayar(secili_ad).donme = fposmod(v, 360.0)
	_secimi_uygula()

func yukseklik_ayarla(v: float) -> void:
	_ayar(secili_ad).yukseklik = v
	_secimi_uygula()

func parca_sayisi_yaz(n: int) -> void:
	if _sayac:
		_sayac.text = "Parça: %d" % n

func durum_yaz(s: String) -> void:
	if _durum:
		_durum.text = s

# --- Arayüz (yatay üst bar) ---
func _arayuz_olustur() -> void:
	name = "Yerleştirici"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# HFlowContainer: dar ekranda kontroller alt satıra sarar (portre/tablet uyumlu).
	var ana := HFlowContainer.new()
	ana.add_theme_constant_override("h_separation", 8)
	ana.add_theme_constant_override("v_separation", 4)
	add_child(ana)

	# Mod düğmeleri
	_mod_koy = _mod_dugme("🧱 Koy", "koy", ana)
	_mod_sil = _mod_dugme("🗑 Sil", "sil", ana)
	var dur := Button.new()
	dur.text = "✋ Dur"
	dur.custom_minimum_size = Vector2(0, 40)
	dur.pressed.connect(func(): mod_ayarla("yok"))
	ana.add_child(dur)

	ana.add_child(_ayrac())

	# Parça seçimi (açılır liste, ikonlu) + yenile + son
	ana.add_child(_etiketli("Parça", _parca_secici()))
	var yenile := Button.new()
	yenile.text = "🔄"
	yenile.tooltip_text = "parts/ klasörünü tekrar tara"
	yenile.custom_minimum_size = Vector2(0, 40)
	yenile.pressed.connect(func(): yenile_istendi.emit())
	ana.add_child(yenile)

	ana.add_child(_ayrac())

	# Sayısal ayarlar (SpinBox = kompakt, dokunmatik dostu)
	_sp_olcek = _spin("Ölçek", 0.1, 6.0, 0.05, 1.0, func(v): _ayar_yaz("olcek", v))
	ana.add_child(_etiketli("Ölçek", _sp_olcek))
	var don_kutu := HBoxContainer.new()
	_sp_donme = _spin("Döndürme", 0.0, 359.0, 1.0, 0.0, func(v): _ayar_yaz("donme", v))
	don_kutu.add_child(_etiketli("Döndürme°", _sp_donme))
	var r90 := Button.new()
	r90.text = "⟳90"
	r90.tooltip_text = "90° döndür (R)"
	r90.custom_minimum_size = Vector2(0, 40)
	r90.pressed.connect(func(): donme_ayarla(donme() + 90.0))
	don_kutu.add_child(r90)
	ana.add_child(don_kutu)
	_sp_yuk = _spin("Yükseklik", -4.0, 20.0, 0.5, 0.0, func(v): _ayar_yaz("yukseklik", v))
	ana.add_child(_etiketli("Yükseklik (Y)", _sp_yuk))
	_sp_izgara = _spin("Izgara", 0.25, 16.0, 0.25, 4.0, func(v): _ayar_yaz("izgara", v))
	ana.add_child(_etiketli("Izgara (m)", _sp_izgara))

	_snap_chk = CheckButton.new()
	_snap_chk.text = "Snap"
	_snap_chk.button_pressed = snap_acik
	_snap_chk.tooltip_text = "Izgaraya yapış"
	_snap_chk.toggled.connect(func(v): snap_acik = v)
	ana.add_child(_snap_chk)

	ana.add_child(_ayrac())

	# Harita yönetimi
	_grup_alani = LineEdit.new()
	_grup_alani.text = grup_adi
	_grup_alani.tooltip_text = "Yeni parçalar bu düğüm altında toplanır (oda/kat)"
	_grup_alani.custom_minimum_size = Vector2(110, 40)
	_grup_alani.text_changed.connect(func(t): grup_adi = t.strip_edges() if t.strip_edges() != "" else "Parcalar")
	ana.add_child(_etiketli("Grup", _grup_alani))
	var grup_temiz := Button.new()
	grup_temiz.text = "Grubu sil"
	grup_temiz.custom_minimum_size = Vector2(0, 40)
	grup_temiz.pressed.connect(func(): grubu_temizle_istendi.emit())
	ana.add_child(grup_temiz)
	var tum_temiz := Button.new()
	tum_temiz.text = "Tümünü sil"
	tum_temiz.modulate = Color(1.0, 0.7, 0.7)
	tum_temiz.custom_minimum_size = Vector2(0, 40)
	tum_temiz.pressed.connect(func(): tumunu_temizle_istendi.emit())
	ana.add_child(tum_temiz)

	ana.add_child(_ayrac())

	_sayac = Label.new()
	_sayac.text = "Parça: 0"
	_sayac.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sayac.modulate = Color(0.7, 0.8, 0.7)
	ana.add_child(_sayac)
	_durum = Label.new()
	_durum.text = "Parça seç, 3B'de sürükle (R = döndür)"
	_durum.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_durum.modulate = Color(0.6, 0.85, 1.0)
	ana.add_child(_durum)

# --- Yardımcılar ---
func _ayrac() -> VSeparator:
	return VSeparator.new()

# Etiket (üstte küçük) + kontrol (altta) — kompakt dikey grup.
func _etiketli(metin: String, kontrol: Control) -> VBoxContainer:
	var k := VBoxContainer.new()
	k.add_theme_constant_override("separation", 0)
	var l := Label.new()
	l.text = metin
	l.add_theme_font_size_override("font_size", 10)
	l.modulate = Color(0.75, 0.8, 0.85)
	k.add_child(l)
	k.add_child(kontrol)
	return k

func _spin(_ad: String, mn: float, mx: float, adim: float, deger: float, geri: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = adim
	s.value = deger
	s.custom_minimum_size = Vector2(82, 40)
	s.value_changed.connect(func(v):
		if not _guncelleniyor:
			geri.call(v))
	return s

func _parca_secici() -> OptionButton:
	_parca_opt = OptionButton.new()
	_parca_opt.custom_minimum_size = Vector2(160, 40)
	_doldur_parca_opt()
	_parca_opt.item_selected.connect(func(idx):
		var ad: String = _parca_opt.get_item_metadata(idx)
		if ad != null and ad != "":
			parca_sec(ad))
	return _parca_opt

func _doldur_parca_opt() -> void:
	_parca_opt.clear()
	if _parcalar.is_empty():
		_parca_opt.add_item("(parts/ boş — .tscn ekle)")
		_parca_opt.set_item_disabled(0, true)
		return
	# Kategoriye göre grupla, başlık ayraçlarıyla ekle.
	var gruplar: Dictionary = {}
	for ad in _parcalar.keys():
		var k := _kategori(ad)
		if not gruplar.has(k):
			gruplar[k] = []
		gruplar[k].append(ad)
	var sira := 0
	for kat in KATEGORI_SIRA:
		if not gruplar.has(kat):
			continue
		_parca_opt.add_separator(kat)
		var liste: Array = gruplar[kat]
		liste.sort()
		for ad in liste:
			var ikon: String = _parcalar[ad].get("ikon", "")
			var tex: Texture2D = (load(ikon) as Texture2D) if ikon != "" else null
			if tex != null:
				_parca_opt.add_icon_item(tex, ad, sira)
			else:
				_parca_opt.add_item(ad, sira)
			_parca_opt.set_item_metadata(_parca_opt.get_item_count() - 1, ad)
			sira += 1
	_parca_opt.selected = -1

func _mod_dugme(metin: String, m: String, ana: Control) -> Button:
	var b := Button.new()
	b.text = metin
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func(): mod_ayarla(m))
	ana.add_child(b)
	return b

func _kategori(ad: String) -> String:
	var b: Dictionary = _parcalar.get(ad, {})
	var eksen: String = b.get("eksen", "y")
	if eksen == "y":
		if float(b.get("yuk", 0.0)) > 1.0 or ad.to_lower().contains("tavan"):
			return "Tavanlar"
		return "Zeminler"
	if eksen == "x" or eksen == "z":
		return "Duvarlar"
	return "Diğer"

func _ayar_yaz(alan: String, v: float) -> void:
	if secili_ad == "":
		return
	_ayar(secili_ad)[alan] = v

func parca_sec(ad: String) -> void:
	secili_ad = ad
	mod = "koy"
	# Açılır listede ilgili öğeyi seç
	if _parca_opt:
		for i in _parca_opt.get_item_count():
			if _parca_opt.get_item_metadata(i) == ad:
				_parca_opt.selected = i
				break
	if _mod_koy: _mod_koy.button_pressed = true
	if _mod_sil: _mod_sil.button_pressed = false
	_secimi_uygula()
	durum_yaz("→ KOY: %s  (sürükle = seri, R = döndür)" % ad)
	parca_secildi.emit(ad)
	mod_degisti.emit("koy")

func mod_ayarla(m: String) -> void:
	mod = m
	if _mod_koy: _mod_koy.button_pressed = (m == "koy")
	if _mod_sil: _mod_sil.button_pressed = (m == "sil")
	match m:
		"koy": durum_yaz("→ KOY: %s" % (secili_ad if secili_ad != "" else "(parça seç)"))
		"sil": durum_yaz("→ SİL (parçaya dokun / sürükle)")
		_: durum_yaz("(mod: yok)")
	mod_degisti.emit(m)

# Geçerli parçanın ayarlarını SpinBox'lara yansıtır (geri-besleme döngüsü olmadan).
func _secimi_uygula() -> void:
	if _sp_olcek == null:
		return
	var a := _ayar(secili_ad)
	_guncelleniyor = true
	_sp_olcek.value = a.olcek
	_sp_donme.value = a.donme
	_sp_yuk.value = a.yukseklik
	_sp_izgara.value = a.izgara
	_guncelleniyor = false

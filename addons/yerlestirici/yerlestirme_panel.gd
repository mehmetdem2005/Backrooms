@tool
class_name YerlestirmePanel
extends VBoxContainer
## Yerleştirici dock paneli — kategorili parça listesi, ayarlar ve harita yönetimi.
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
var _parca_btnlar: Dictionary = {}      # ad -> Button

var _durum: Label
var _sayac: Label
var _mod_koy: Button
var _mod_sil: Button
var _sl_olcek: HSlider
var _sl_donme: HSlider
var _sl_yuk: HSlider
var _sl_izgara: HSlider
var _lbl_olcek: Label
var _lbl_donme: Label
var _lbl_yuk: Label
var _lbl_izgara: Label
var _snap_chk: CheckBox
var _grup_alani: LineEdit
var _guncelleniyor: bool = false        # slider geri-besleme döngüsünü engeller

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
		_sayac.text = "Haritadaki parça: %d" % n

func durum_yaz(s: String) -> void:
	if _durum:
		_durum.text = s

# --- Arayüz ---
func _arayuz_olustur() -> void:
	name = "Yerleştirici"
	add_theme_constant_override("separation", 6)

	var baslik := Label.new()
	baslik.text = "🧱  HARİTA YERLEŞTİRİCİ"
	baslik.add_theme_font_size_override("font_size", 15)
	add_child(baslik)

	# Mod düğmeleri
	var mod_sat := HBoxContainer.new()
	mod_sat.add_theme_constant_override("separation", 4)
	add_child(mod_sat)
	_mod_koy = _mod_dugme("🧱 Koy", "koy", mod_sat)
	_mod_sil = _mod_dugme("🗑 Sil", "sil", mod_sat)
	var dur := Button.new()
	dur.text = "✋ Dur"
	dur.custom_minimum_size = Vector2(0, 42)
	dur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dur.pressed.connect(func(): mod_ayarla("yok"))
	mod_sat.add_child(dur)

	_durum = Label.new()
	_durum.text = "Bir parça seç, sahnede sürükle. (R = döndür)"
	_durum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_durum.modulate = Color(0.6, 0.85, 1.0)
	add_child(_durum)

	add_child(HSeparator.new())

	# Ayarlar
	_sl_olcek = _kaydirici("Ölçek", 0.1, 6.0, 0.05, 1.0, func(v): _ayar_yaz("olcek", v))
	_lbl_olcek = _son_lbl
	_sl_donme = _kaydirici("Döndürme (°)", 0.0, 359.0, 1.0, 0.0, func(v): _ayar_yaz("donme", v))
	_lbl_donme = _son_lbl
	# Hızlı döndürme düğmeleri
	var don_sat := HBoxContainer.new()
	add_child(don_sat)
	for a in [0, 90, 180, 270]:
		var db := Button.new()
		db.text = "%d°" % a
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.pressed.connect(donme_ayarla.bind(float(a)))
		don_sat.add_child(db)
	_sl_yuk = _kaydirici("Yükseklik (Y)", -2.0, 12.0, 0.05, 0.0, func(v): _ayar_yaz("yukseklik", v))
	_lbl_yuk = _son_lbl
	_sl_izgara = _kaydirici("Izgara (m)", 0.25, 16.0, 0.25, 4.0, func(v): _ayar_yaz("izgara", v))
	_lbl_izgara = _son_lbl

	_snap_chk = CheckBox.new()
	_snap_chk.text = "Izgaraya yapış (snap)"
	_snap_chk.button_pressed = snap_acik
	_snap_chk.toggled.connect(func(v): snap_acik = v)
	add_child(_snap_chk)

	add_child(HSeparator.new())

	# Parça paleti (kategorili)
	var palet_baslik := HBoxContainer.new()
	add_child(palet_baslik)
	var pl := Label.new()
	pl.text = "Parçalar"
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palet_baslik.add_child(pl)
	var yenile := Button.new()
	yenile.text = "🔄 Yenile"
	yenile.tooltip_text = "parts/ klasörünü tekrar tara"
	yenile.pressed.connect(func(): yenile_istendi.emit())
	palet_baslik.add_child(yenile)

	if _parcalar.is_empty():
		var uyari := Label.new()
		uyari.text = "parts/ klasörüne .tscn parça ekle, sonra 🔄 Yenile'ye bas."
		uyari.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		uyari.modulate = Color(1.0, 0.8, 0.5)
		add_child(uyari)
	else:
		# Kategorilere ayır
		var gruplar: Dictionary = {}
		for ad in _parcalar.keys():
			var k := _kategori(ad)
			if not gruplar.has(k):
				gruplar[k] = []
			gruplar[k].append(ad)
		for kat in KATEGORI_SIRA:
			if not gruplar.has(kat):
				continue
			var kl := Label.new()
			kl.text = "▾ " + kat
			kl.modulate = Color(0.8, 0.85, 0.9)
			add_child(kl)
			var izg := GridContainer.new()
			izg.columns = 2
			add_child(izg)
			var liste: Array = gruplar[kat]
			liste.sort()
			for ad in liste:
				izg.add_child(_parca_dugme(ad))

	add_child(HSeparator.new())

	# Harita yönetimi
	var yon_baslik := Label.new()
	yon_baslik.text = "Harita Yönetimi"
	add_child(yon_baslik)
	var grup_sat := HBoxContainer.new()
	add_child(grup_sat)
	var gl := Label.new()
	gl.text = "Grup:"
	grup_sat.add_child(gl)
	_grup_alani = LineEdit.new()
	_grup_alani.text = grup_adi
	_grup_alani.tooltip_text = "Yeni parçalar bu düğüm altında toplanır (oda/kat)"
	_grup_alani.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grup_alani.text_changed.connect(func(t): grup_adi = t.strip_edges() if t.strip_edges() != "" else "Parcalar")
	grup_sat.add_child(_grup_alani)

	_sayac = Label.new()
	_sayac.text = "Haritadaki parça: 0"
	_sayac.modulate = Color(0.7, 0.8, 0.7)
	add_child(_sayac)

	var temiz_sat := HBoxContainer.new()
	add_child(temiz_sat)
	var grup_temiz := Button.new()
	grup_temiz.text = "Grubu Temizle"
	grup_temiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grup_temiz.pressed.connect(func(): grubu_temizle_istendi.emit())
	temiz_sat.add_child(grup_temiz)
	var tum_temiz := Button.new()
	tum_temiz.text = "Tümünü Temizle"
	tum_temiz.modulate = Color(1.0, 0.7, 0.7)
	tum_temiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tum_temiz.pressed.connect(func(): tumunu_temizle_istendi.emit())
	temiz_sat.add_child(tum_temiz)

	var tekrar := Button.new()
	tekrar.text = "⟳ Son parçayı tekrar seç"
	tekrar.pressed.connect(func(): son_parca_istendi.emit())
	add_child(tekrar)

# --- Yardımcılar ---
var _son_lbl: Label   # _kaydirici tarafından doldurulur

func _kaydirici(etiket: String, mn: float, mx: float, adim: float, deger: float, geri: Callable) -> HSlider:
	var kutu := VBoxContainer.new()
	kutu.add_theme_constant_override("separation", 0)
	add_child(kutu)
	var lbl := Label.new()
	lbl.text = "%s: %s" % [etiket, _bicim(deger, adim)]
	kutu.add_child(lbl)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = adim
	s.value = deger
	s.custom_minimum_size = Vector2(0, 24)
	s.value_changed.connect(func(v):
		lbl.text = "%s: %s" % [etiket, _bicim(v, adim)]
		if not _guncelleniyor:
			geri.call(v))
	kutu.add_child(s)
	_son_lbl = lbl
	return s

func _bicim(v: float, adim: float) -> String:
	return str(int(round(v))) if adim >= 1.0 else "%0.2f" % v

func _mod_dugme(metin: String, m: String, ana: Control) -> Button:
	var b := Button.new()
	b.text = metin
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 42)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func(): mod_ayarla(m))
	ana.add_child(b)
	return b

func _parca_dugme(ad: String) -> Button:
	var b := Button.new()
	b.text = ad
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	var ikon: String = _parcalar[ad].get("ikon", "")
	if ikon != "":
		var tex := load(ikon) as Texture2D
		if tex != null:
			b.icon = tex
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 48)
	b.pressed.connect(func(): parca_sec(ad))
	_parca_btnlar[ad] = b
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
	for a in _parca_btnlar:
		_parca_btnlar[a].button_pressed = (a == ad)
	_mod_koy.button_pressed = true
	_mod_sil.button_pressed = false
	_secimi_uygula()
	durum_yaz("→ KOY: %s  (sürükle = seri, R = döndür)" % ad)
	parca_secildi.emit(ad)
	mod_degisti.emit("koy")

func mod_ayarla(m: String) -> void:
	mod = m
	_mod_koy.button_pressed = (m == "koy")
	_mod_sil.button_pressed = (m == "sil")
	if m != "koy":
		for a in _parca_btnlar:
			_parca_btnlar[a].button_pressed = false
	match m:
		"koy": durum_yaz("→ KOY: %s" % (secili_ad if secili_ad != "" else "(parça seç)"))
		"sil": durum_yaz("→ SİL (parçaya dokun / sürükle)")
		_: durum_yaz("(mod: yok)")
	mod_degisti.emit(m)

# Geçerli parçanın ayarlarını sliderlara yansıtır (geri-besleme döngüsü olmadan).
func _secimi_uygula() -> void:
	if _sl_olcek == null:
		return
	var a := _ayar(secili_ad)
	_guncelleniyor = true
	_sl_olcek.value = a.olcek
	_sl_donme.value = a.donme
	_sl_yuk.value = a.yukseklik
	_sl_izgara.value = a.izgara
	_guncelleniyor = false

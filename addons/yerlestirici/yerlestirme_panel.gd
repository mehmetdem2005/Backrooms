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
signal kir_sac_istendi()
signal kir_temizle_istendi()
signal leke_secildi(yol: String)

const KATEGORI_SIRA := ["Zeminler", "Duvarlar", "Tavanlar", "Diğer"]

var mod: String = "yok"
var secili_ad: String = ""
var snap_acik: bool = true
var grup_adi: String = "Parcalar"

# --- Leke (decal) ---
var secili_leke: String = ""
var leke_boyut: float = 0.8
var leke_rastgele: bool = false
const LEKE_KLASORU := "res://textures/lekeler/"
var _leke_yollari: Array[String] = []
var _leke_index: int = 0
var _leke_onizleme: Button
var _leke_sayac: Label

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

	# --- LEKE (tıklayarak çıkartma yapıştır) ---
	add_child(HSeparator.new())
	var leke_baslik := Label.new()
	leke_baslik.text = "🩸 Leke (tıkla → yapıştır)"
	leke_baslik.add_theme_font_size_override("font_size", 14)
	add_child(leke_baslik)
	var leke_aciklama := Label.new()
	leke_aciklama.text = "Bir leke seç, sonra sahnede istediğin yüzeye dokun → leke oraya yapışır."
	leke_aciklama.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	leke_aciklama.modulate = Color(0.7, 0.78, 0.7)
	add_child(leke_aciklama)
	_kaydirici("Leke boyutu (m)", 0.1, 2.5, 0.05, leke_boyut, func(v): leke_boyut = v)
	var lr := CheckBox.new()
	lr.text = "Rastgele döndür/boyut"
	lr.button_pressed = leke_rastgele
	lr.toggled.connect(func(v): leke_rastgele = v)
	add_child(lr)
	# Leke carousel: tek büyük önizleme + ◀ ▶ ile kaydırarak seç
	_leke_yollari = _leke_tara()
	if _leke_yollari.is_empty():
		var u := Label.new()
		u.text = "textures/lekeler/ boş — PNG ekle."
		u.modulate = Color(1.0, 0.8, 0.5)
		add_child(u)
	else:
		# Büyük önizleme (panel genişliğine uyumlu kare çerçeve). Basınca da seçer.
		_leke_onizleme = Button.new()
		_leke_onizleme.custom_minimum_size = Vector2(0, 200)
		_leke_onizleme.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_leke_onizleme.expand_icon = true
		_leke_onizleme.add_theme_constant_override("icon_max_width", 196)
		_leke_onizleme.tooltip_text = "Bu lekeyi seç (sonra yüzeye dokun)"
		_leke_onizleme.pressed.connect(func(): _leke_sec_index())
		add_child(_leke_onizleme)
		# ◀  sayaç  ▶
		var ok_sat := HBoxContainer.new()
		ok_sat.add_theme_constant_override("separation", 6)
		add_child(ok_sat)
		var sol := Button.new()
		sol.text = "◀"
		sol.custom_minimum_size = Vector2(0, 46)
		sol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sol.pressed.connect(_leke_git.bind(-1))
		ok_sat.add_child(sol)
		_leke_sayac = Label.new()
		_leke_sayac.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_leke_sayac.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_leke_sayac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ok_sat.add_child(_leke_sayac)
		var sag := Button.new()
		sag.text = "▶"
		sag.custom_minimum_size = Vector2(0, 46)
		sag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sag.pressed.connect(_leke_git.bind(1))
		ok_sat.add_child(sag)
		_leke_onizleme_guncelle()
	var leke_dur := Button.new()
	leke_dur.text = "✋ Leke modundan çık"
	leke_dur.pressed.connect(func(): mod_ayarla("yok"))
	add_child(leke_dur)

	add_child(HSeparator.new())
	var aaa := Label.new()
	aaa.text = "✨ AAA Kir (Decal)"
	aaa.modulate = Color(0.8, 0.85, 0.9)
	add_child(aaa)
	var kir_btn := Button.new()
	kir_btn.text = "Zemine kir saç"
	kir_btn.tooltip_text = "Yerleşik zeminlerin üstüne benzersiz çamur decal'ları saçar (MultiMesh, tek draw call)"
	kir_btn.custom_minimum_size = Vector2(0, 40)
	kir_btn.pressed.connect(func(): kir_sac_istendi.emit())
	add_child(kir_btn)
	var kir_temiz := Button.new()
	kir_temiz.text = "Kiri temizle"
	kir_temiz.modulate = Color(1.0, 0.8, 0.8)
	kir_temiz.pressed.connect(func(): kir_temizle_istendi.emit())
	add_child(kir_temiz)

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
		"leke": durum_yaz("→ LEKE: yüzeye dokun → yapışır")
		_: durum_yaz("(mod: yok)")
	mod_degisti.emit(m)

# --- Leke (decal) yardımcıları ---
func _leke_tara() -> Array[String]:
	var liste: Array[String] = []
	var d := DirAccess.open(LEKE_KLASORU)
	if d == null:
		return liste
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir() and f.get_extension().to_lower() == "png":
			liste.append(LEKE_KLASORU + f)
		f = d.get_next()
	d.list_dir_end()
	liste.sort()
	return liste

# ◀ ▶ ile leke değiştir (kaydırarak seç). Değiştirince o lekeyi seçer + leke moduna girer.
func _leke_git(yon: int) -> void:
	if _leke_yollari.is_empty():
		return
	_leke_index = (_leke_index + yon + _leke_yollari.size()) % _leke_yollari.size()
	_leke_onizleme_guncelle()
	_leke_sec_index()

func _leke_sec_index() -> void:
	if _leke_yollari.is_empty():
		return
	secili_leke = _leke_yollari[_leke_index]
	mod_ayarla("leke")
	leke_secildi.emit(secili_leke)

func _leke_onizleme_guncelle() -> void:
	if _leke_onizleme == null or _leke_yollari.is_empty():
		return
	_leke_onizleme.icon = load(_leke_yollari[_leke_index]) as Texture2D
	if _leke_sayac:
		_leke_sayac.text = "%d / %d" % [_leke_index + 1, _leke_yollari.size()]

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

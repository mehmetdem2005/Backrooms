@tool
class_name LekeKutuphane
extends RefCounted
## Leke doku kütüphanesi.
## - textures/stains/ klasöründeki tüm PNG'leri otomatik tarar (yenisini atınca otomatik gelir).
## - Lekeler siyah zeminli RGB. Bunları decal/sticker için ALFALI dokuya çevirir
##   (siyah zemin = şeffaf, leke = görünür). Sonuç önbelleğe alınır.

const STAINS_DIR := "res://addons/backrooms_lekeleyici/textures/stains/"
const VARSAYILAN_ESIK := 0.22   # önizlemede kullanılan eşik (panel varsayılanıyla aynı)
const VARSAYILAN_YUM := 0.12

var yollar: Array[String] = []          # bulunan tüm leke png yolları (sıralı)
var _alfa_onbellek: Dictionary = {}     # anahtar -> ImageTexture (alfalı)
var _onizleme_onbellek: Dictionary = {} # yol -> ImageTexture (küçük önizleme)

func _init() -> void:
	tara()

## stains klasörünü tarayıp png yollarını toplar.
func tara() -> void:
	yollar.clear()
	var d := DirAccess.open(STAINS_DIR)
	if d == null:
		push_warning("Lekeleyici: leke klasörü bulunamadı: " + STAINS_DIR)
		return
	d.list_dir_begin()
	var ad := d.get_next()
	while ad != "":
		if not d.current_is_dir():
			var alt := ad.to_lower()
			if alt.ends_with(".png") or alt.ends_with(".jpg") or alt.ends_with(".jpeg") or alt.ends_with(".webp"):
				yollar.append(STAINS_DIR + ad)
		ad = d.get_next()
	d.list_dir_end()
	yollar.sort()

func sayi() -> int:
	return yollar.size()

## Bir lekenin küçük önizleme dokusu (palet düğmeleri için).
## WYSIWYG: önizleme de alfa dönüşümünü uygular, böylece düğmede gördüğün
## leke şekli, sahnede boyadığın leke ile aynıdır (koyu zemin şeffaf görünür).
func onizleme(yol: String, boyut: int = 96) -> Texture2D:
	if _onizleme_onbellek.has(yol):
		return _onizleme_onbellek[yol]
	var img := _goruntu_yukle(yol)
	if img == null:
		return null
	img.resize(boyut, boyut, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGBA8)
	_alfa_uygula(img, VARSAYILAN_ESIK, VARSAYILAN_YUM)
	var tex := ImageTexture.create_from_image(img)
	_onizleme_onbellek[yol] = tex
	return tex

## Lekeyi ALFALI dokuya çevirir (koyu zemin -> şeffaf). Önbellekli.
## esik: bu (normalize edilmiş) parlaklığın altı şeffaf. yumusaklik: kenar geçişi.
func alfa_doku(yol: String, esik: float, yumusaklik: float, boyut: int = 512) -> Texture2D:
	var anahtar := "%s|%0.3f|%0.3f|%d" % [yol, esik, yumusaklik, boyut]
	if _alfa_onbellek.has(anahtar):
		return _alfa_onbellek[anahtar]
	var img := _goruntu_yukle(yol)
	if img == null:
		return null
	if img.get_width() > boyut or img.get_height() > boyut:
		img.resize(boyut, boyut, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGBA8)
	_alfa_uygula(img, esik, yumusaklik)
	var tex := ImageTexture.create_from_image(img)
	_alfa_onbellek[anahtar] = tex
	return tex

## Görüntüye alfa kanalı yazar. Parlaklık, GÖRÜNTÜNÜN EN PARLAK pikseline göre
## normalize edilir. Böylece eşik sonuna kadar açılsa bile en parlak leke izi
## görünür kalır (boyama asla "yok olmaz") ve koyu grunge zemini eşikle kesilerek
## tüm yüzeyi kaplayan kir yerine ayrık leke izleri elde edilir.
func _alfa_uygula(img: Image, esik: float, yumusaklik: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	# 1) En parlak pikseli bul (normalize referansı)
	var maks_lum := 0.001
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			if lum > maks_lum:
				maks_lum = lum
	# 2) Normalize parlaklığa göre alfa.
	#    olcek_a = en parlak pikselin (lum=1) alacağı alfa. Tüm alfaları buna bölerek
	#    en parlak iz DAİMA tam görünür olur -> eşik/yumuşaklık sonuna kadar açılsa
	#    bile boyama asla yok olmaz; eşik yalnızca kaplama yoğunluğunu azaltır.
	var e := clampf(esik, 0.0, 0.95)
	var ust := e + maxf(yumusaklik, 0.0001)
	var olcek_a := maxf(smoothstep(e, ust, 1.0), 0.001)
	# Dairesel yumuşak kenar (radial falloff): kare sınırı yok edilir, böylece üst
	# üste binen damgalar görünür dikiş olmadan SÜREKLİ kire dönüşür (referans gibi).
	var cx := (w - 1) * 0.5
	var cy := (h - 1) * 0.5
	var maks_r := maxf(minf(cx, cy), 1.0)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var lum := (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) / maks_lum
			var a := clampf(smoothstep(e, ust, lum) / olcek_a, 0.0, 1.0)
			var dx := (x - cx) / maks_r
			var dy := (y - cy) / maks_r
			var rr := sqrt(dx * dx + dy * dy)
			a *= 1.0 - smoothstep(0.72, 1.08, rr)
			c.a = a
			img.set_pixel(x, y, c)

func _goruntu_yukle(yol: String) -> Image:
	# Editör eklentisi: kaynak PNG her zaman diskte mevcut. Import sistemine
	# bağlı kalmadan DOĞRUDAN diskten yükle. Böylece projenin ilk açılışında
	# (henüz import bitmemişken) bile çalışır ve "Failed loading resource"
	# hatası üretmez.
	var img := Image.new()
	var mutlak := ProjectSettings.globalize_path(yol)
	if img.load(mutlak) == OK:
		return img
	# Yedek 1: res:// yolundan Image.load
	if img.load(yol) == OK:
		return img
	# Yedek 2: import edilmiş Texture2D
	var t := load(yol) as Texture2D
	if t != null:
		var ti := t.get_image()
		if ti != null:
			return ti.duplicate()
	push_warning("Lekeleyici: doku yüklenemedi: " + yol)
	return null

func onbellegi_temizle() -> void:
	_alfa_onbellek.clear()
	_onizleme_onbellek.clear()

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
var _taban_onbellek: Dictionary = {}    # "yol|boyut" -> Image (yüklenip resize'lı; kalıcı)

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
	var taban := _taban_goruntu(yol, boyut)
	if taban == null:
		return null
	var tex := ImageTexture.create_from_image(_alfa_uygula(taban, VARSAYILAN_ESIK, VARSAYILAN_YUM))
	_onizleme_onbellek[yol] = tex
	return tex

## PNG'yi yükleyip çalışma boyutuna indirir; sonucu KALICI önbelleğe alır.
## Eşik/yumuşaklık değişince (alfa önbelleği temizlenince) bu KORUNUR, böylece
## pahalı disk okuma + resize tekrar yapılmaz; sadece hızlı alfa döngüsü çalışır.
func _taban_goruntu(yol: String, boyut: int) -> Image:
	var k := "%s|%d" % [yol, boyut]
	if _taban_onbellek.has(k):
		return _taban_onbellek[k]
	var img := _goruntu_yukle(yol)
	if img == null:
		return null
	if img.get_width() > boyut or img.get_height() > boyut:
		img.resize(boyut, boyut, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGBA8)
	_taban_onbellek[k] = img
	return img

## Lekeyi ALFALI dokuya çevirir (koyu zemin -> şeffaf). Önbellekli.
## esik: bu (normalize edilmiş) parlaklığın altı şeffaf. yumusaklik: kenar geçişi.
func alfa_doku(yol: String, esik: float, yumusaklik: float, boyut: int = 256) -> Texture2D:
	var anahtar := "%s|%0.3f|%0.3f|%d" % [yol, esik, yumusaklik, boyut]
	if _alfa_onbellek.has(anahtar):
		return _alfa_onbellek[anahtar]
	var taban := _taban_goruntu(yol, boyut)
	if taban == null:
		return null
	# _alfa_uygula girdiyi DEĞİŞTİRMEZ (yeni görüntü döndürür) -> taban güvende.
	var tex := ImageTexture.create_from_image(_alfa_uygula(taban, esik, yumusaklik))
	_alfa_onbellek[anahtar] = tex
	return tex

## Görüntüye alfa kanalı yazar ve YENİ görüntü döndürür. Parlaklık, görüntünün EN
## PARLAK pikseline göre normalize edilir (eşik sonuna açılsa bile en parlak iz
## görünür kalır). Dairesel yumuşak kenar uygulanır (damgalar dikişsiz birleşir).
## HIZ: piksel piksel get/set_pixel yerine HAM BAYT tamponu işlenir (10-50× hızlı)
## -> boyarken kasma olmaz.
func _alfa_uygula(img: Image, esik: float, yumusaklik: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()   # PackedByteArray, RGBA8 (4 bayt/piksel)
	var n := w * h
	# 1) En parlak piksel (0..255)
	var maks_lum := 1.0
	for i in n:
		var b := i * 4
		var lum := data[b] * 0.299 + data[b + 1] * 0.587 + data[b + 2] * 0.114
		if lum > maks_lum:
			maks_lum = lum
	# 2) Normalize + dairesel kenar
	var e := clampf(esik, 0.0, 0.95)
	var ust := e + maxf(yumusaklik, 0.0001)
	var olcek_a := maxf(smoothstep(e, ust, 1.0), 0.001)
	var cx := (w - 1) * 0.5
	var cy := (h - 1) * 0.5
	var maks_r := maxf(minf(cx, cy), 1.0)
	for i in n:
		var b := i * 4
		var lum := (data[b] * 0.299 + data[b + 1] * 0.587 + data[b + 2] * 0.114) / maks_lum
		var a := clampf(smoothstep(e, ust, lum) / olcek_a, 0.0, 1.0)
		var px := i % w
		@warning_ignore("integer_division")
		var py := i / w
		var dx := (px - cx) / maks_r
		var dy := (py - cy) / maks_r
		var rr := sqrt(dx * dx + dy * dy)
		a *= 1.0 - smoothstep(0.72, 1.08, rr)
		data[b + 3] = int(a * 255.0)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)

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

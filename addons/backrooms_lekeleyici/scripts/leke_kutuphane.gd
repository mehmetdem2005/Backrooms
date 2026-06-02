@tool
class_name LekeKutuphane
extends RefCounted
## Leke doku kütüphanesi.
## - textures/stains/ klasöründeki tüm PNG'leri otomatik tarar (yenisini atınca otomatik gelir).
## - Lekeler siyah zeminli RGB. Bunları decal/sticker için ALFALI dokuya çevirir
##   (siyah zemin = şeffaf, leke = görünür). Sonuç önbelleğe alınır.

const STAINS_DIR := "res://addons/backrooms_lekeleyici/textures/stains/"

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
func onizleme(yol: String, boyut: int = 96) -> Texture2D:
	if _onizleme_onbellek.has(yol):
		return _onizleme_onbellek[yol]
	var img := _goruntu_yukle(yol)
	if img == null:
		return null
	img.resize(boyut, boyut, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_onizleme_onbellek[yol] = tex
	return tex

## Lekeyi ALFALI dokuya çevirir (siyah zemin -> şeffaf). Önbellekli.
## esik: bu parlaklığın altı tamamen şeffaf. yumusaklik: kenar geçiş yumuşaklığı.
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
	var w := img.get_width()
	var h := img.get_height()
	var ust := maxf(esik + maxf(yumusaklik, 0.0001), esik + 0.0001)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var a := smoothstep(esik, ust, lum)
			c.a = a
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_alfa_onbellek[anahtar] = tex
	return tex

func _goruntu_yukle(yol: String) -> Image:
	# Önce import edilmiş Texture2D'den dene (editörde en güvenilir), olmazsa diskten.
	var t := load(yol) as Texture2D
	if t != null:
		var img := t.get_image()
		if img != null:
			return img.duplicate()
	var disk := Image.new()
	var hata := disk.load(yol)
	if hata == OK:
		return disk
	return null

func onbellegi_temizle() -> void:
	_alfa_onbellek.clear()
	_onizleme_onbellek.clear()

extends Node
## OYUN DURUMU (autoload) - oyuncu/canavar referanslari, alarm durumu, girdi haritasi.
## Faz 3: nefes/kalp/kosu/egilme/stamina + alarm + canavar aksiyonu burdan koordine edilir.
## Faz 4+: KONUM/DURUM/ISIK/ALARM duyarli ic-ses altyazilari (canavarin DEGIL).

signal alarm_basladi
signal alarm_bitti
signal yakalandi_sinyal

const Bolge = preload("res://bolge_veri.gd")

var oyuncu: Node3D = null
var canavar: Node3D = null
var nav: Node = null               # NavIzgara (yol bulma)
var alarm: bool = false
var av_modu: bool = false          # sinematik sonrasi aktif av (canavar avlar)
var sinematik: bool = false        # acilis sinematigi sirasinda oyuncu kontrolu kilitli
var ses_yaricapi: float = 4.0      # oyuncu gurultu yaricapi (mod'a gore; canavar algisi icin)
var son_ses_konum: Vector3 = Vector3.ZERO
var son_ses_zaman: float = -999.0

# ---- IC SES havuzlari (CANAVAR DEGIL: oyuncunun ic sesi / mekanin fisiltisi) -----
# Konuma gore (oda adi -> repliker). Bulunmayan oda GENEL havuzu kullanir.
const KONUM := {
	"Resepsiyon": ["Burada birini karsiliyorlardi. Coktan gittiler.", "Defterde son imza... bugunun tarihi."],
	"Acik Ofis": ["Ekranlar hala acikti. Kimse yazmiyor ama.", "Sandalyeler hala sicak. Daha yeni kalkmislar."],
	"Arsiv": ["Dosyalarda senin adin da var. Bakma.", "Klasorlerden biri iceriden tirmalanmis."],
	"Bakim / Jenerator": ["Jenerator bir seyi besliyor. Isiklari degil.", "Aletler yerli yerinde. Cok fazla yerli yerinde."],
	"Kazan Dairesi": ["Asagidan bir nefes geliyor. Senin degil.", "Borular sicak. Bu kati kimse isitmiyor."],
	"Toplanti": ["Masanin etrafinda on iki sandalye. On uc tabak.", "Tahtada tek kelime: KACMAYIN."],
	"Otopark / Depo": ["Arabalar burada. Surenler nerede?", "Bir bagaj iceriden tirmalanmis."],
	"Yaratigin Ini": ["Burasi onun yeri. Bunu kemiklerinde hissediyorsun.", "Duvarlar et kokuyor. Kac."],
	"CIKIS": ["Tabela CIKIS diyor. Yalan soyluyor.", "Kapi var. Ardinda baska bir kapi var."],
	"Ikinci Lobi": ["Bu lobiyi daha once gordun. Ya da o seni.", "Saat durmus. Akrep hala titriyor."],
	"Sunucu Odasi": ["Makineler bir seyi besliyor. Soru sorma.", "Ekranlarda tek satir: o uyandi."],
	"Laboratuvar": ["Buradaki deneyler... bitmedi.", "Kavanozlardan biri ici bos. Capak taze."],
	"Revir": ["Yataklarda hala sicak izler var.", "Bir kartta yaziyor: hasta kacti. Cok ucti yani."],
	"Yemekhane": ["Tabaklarda yemek var. Hala buhari tutuyor.", "Birileri aceleyle kalkmis. Catallar yerde."],
	"Kontrol Odasi": ["Kameralar bos koridorlari gosteriyor. Birinde sen varsin.", "Dugmelerin hepsi kirmizi."],
	"Karantina": ["Kapiyi disaridan kapatmislar. Bir sebebi vardi.", "Camda el izleri. Iceriden."],
	"Ambar": ["Kutular tavana kadar. Birinden tiklama geliyor.", "Etiketlerde tek sey yaziyor: numune."],
	"Sizinti Odasi": ["Tavandan bir sey damliyor. Su degil.", "Zemin yapis yapis. Bakma asagi."],
	"Morg": ["Cekmecelerden biri iceriden kilitlenmis.", "Isimlerden biri seninki. Tarih: yarin."],
	"Atik Isleme": ["Burada bir seyleri yok ediyorlardi. Bitiremezler.", "Ogutucu hala donuyor. Bos degil."],
}
# Karanlik koridor isimleri zaten 'GENEL'e duser.
const GENEL := ["Ayni koridordan ucuncu kez geciyorsun.", "Duvarlar nefes aliyor.",
	"Bu isiklar bir seyi gizliyor.", "Geri donme. Arkanda bir sey degisti.",
	"Saatler geri gidiyor.", "Burasi bos degil. Hic olmadi."]
# Karanlikta (fener kapali): isiga duyarli
const KARANLIK := ["Karanlik nefes aliyor.", "Gozlerin yalan soyluyor.",
	"Karanlikta yalniz degilsin.", "Isigi ac. Ya da acma. Ikisi de ayni."]
const ISIK_TITRER := ["Isiklar onun geldigini biliyor.", "Lambalar cirpiniyor. Saklan."]
const PIL_AZ := ["Pil bitiyor. Karanlikta kalma sakin.", "Birazdan hicbir sey goremeyeceksin."]
const ALARM_DUS := ["Ciglik senin degildi. Kac.", "Alarm. Demek seni buldu.",
	"Siktir et cikisi, cikis zaten yok. Sadece kos.", "Kalbin kulaklarinda. Iyi. Onunki de oyle."]
const AV_DUS := ["Arkani donme.", "Nefesini tut. Cok yakin.",
	"Bu et artik senin degil.", "Kosmak ise yariyor mu? Hayir. Yine de kos.",
	"Onu duyuyorsun degil mi. Hayir, o sensin. Belki."]
const DEHSET := ["Burada. Hemen burada. Kipirdama.", "Sicak nefesi ensende.",
	"Gozlerini kapat. Belki gecer. Gecmez."]

var _alt_t := 6.0
var _son_kod := ""

func _ready() -> void:
	# Girdi haritasi (project.godot'a yazmak yerine kodla) - fiziksel tuslar
	_ekle("ileri", [KEY_W, KEY_UP])
	_ekle("geri",  [KEY_S, KEY_DOWN])
	_ekle("sol",   [KEY_A, KEY_LEFT])
	_ekle("sag",   [KEY_D, KEY_RIGHT])
	_ekle("atla",  [KEY_SPACE])
	_ekle("kos",   [KEY_SHIFT])
	_ekle("egil",  [KEY_CTRL, KEY_C])
	_ekle("sessiz",[KEY_ALT])
	_ekle("alarm", [KEY_G])
	_ekle("etkilesim", [KEY_E])
	_ekle("fener", [KEY_F])

func _process(delta: float) -> void:
	if sinematik or oyuncu == null: return
	_alt_t -= delta
	if _alt_t > 0.0: return
	var alt := get_node_or_null("/root/Altyazi")
	if alt == null: return
	var metin := _ic_ses_sec()
	if metin != "":
		alt.call("cevre", metin, 4.2)
	# Pacing: av/alarmda daha sik, sakinde seyrek
	var gergin: bool = av_modu or alarm or _canavar_yakin(12.0)
	_alt_t = randf_range(7.0, 12.0) if gergin else randf_range(16.0, 30.0)

## Onceligine gore ic-ses secer (durum > konum). Canavar repligi DEGIL.
func _ic_ses_sec() -> String:
	var p: Vector3 = oyuncu.global_position
	# 1) Canavar cok yakin -> dehset
	if (av_modu or alarm) and _canavar_yakin(9.0):
		return DEHSET[randi() % DEHSET.size()]
	# 2) Alarm
	if alarm:
		return ALARM_DUS[randi() % ALARM_DUS.size()]
	# 3) Av modu (kovalaniyor)
	if av_modu:
		return AV_DUS[randi() % AV_DUS.size()]
	# 4) Isik/pil durumu (ara sira)
	var fener_acik: bool = bool(oyuncu.get("_fener_acik"))
	var pil: float = float(oyuncu.get("_fener_sarj"))
	if not fener_acik and pil < 22.0 and randf() < 0.5:
		return PIL_AZ[randi() % PIL_AZ.size()]
	if not fener_acik and randf() < 0.35:
		return KARANLIK[randi() % KARANLIK.size()]
	# 5) Konuma ozel (oda adi) - oda her degistiginde oncelik
	var kod := Bolge.oda_kodu(p)
	var ad: String = Bolge.ODA.get(kod, "")
	if KONUM.has(ad):
		# yeni odaya girince oda repligi sansi yuksek
		var liste: Array = KONUM[ad]
		if kod != _son_kod:
			_son_kod = kod
			return liste[randi() % liste.size()]
		if randf() < 0.5:
			return liste[randi() % liste.size()]
	_son_kod = kod
	# 6) Genel
	return GENEL[randi() % GENEL.size()]

func _canavar_yakin(menzil: float) -> bool:
	if canavar == null or oyuncu == null: return false
	return oyuncu.global_position.distance_to((canavar as Node3D).global_position) < menzil

func _ekle(ad: String, tuslar: Array) -> void:
	if InputMap.has_action(ad):
		return
	InputMap.add_action(ad)
	for k in tuslar:
		var e := InputEventKey.new(); e.physical_keycode = k
		InputMap.action_add_event(ad, e)

func alarmi_baslat() -> void:
	if alarm: return
	alarm = true
	emit_signal("alarm_basladi")

func alarmi_durdur() -> void:
	if not alarm: return
	alarm = false
	emit_signal("alarm_bitti")

func yakalandi() -> void:
	emit_signal("yakalandi_sinyal")

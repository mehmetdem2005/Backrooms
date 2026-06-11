extends RefCounted
## OTOMATIK URETILDI (tools/ses_uretici degil; bolge verisi) - degistirme.
## Dunya izgarasi + oda adlari; dunya konumundan oda adi cozer (konum-bazli altyazi).

const CELL := 4.0
const NR := 44
const NC := 82

const GRID := [
	"..................................................................................",
	"..RRRRRRRR...OOOOOOOOO.......................GGGGGGGGGG.SSSSSSSSSS.LLLLLLLLL......",
	"..RRRRRRRR...OOOOOOOOO.......................GGGGGGGGGG.SSSSSSSSSS.LLLLLLLLL......",
	"..RRRRRRRR...OOOOOOOOO.......................GGGGGGGGGG.SSSSSSSSSS.LLLLLLLLL......",
	"..RRRRRRRR...OOOOOOOOO.......................GGGGGGGGGG.SSSSSSSSSS.LLLLLLLLL......",
	"..RRRRRRRR...OOOOOOOOO.......................GGGGGGGGGG.SSSSSSSSSS.LLLLLLLLL......",
	"...aaaaaaaaaaaaaaaaaaaaa.....................GGGGGGGGGG.SSSSSSSSSS.LLLLLLLLL......",
	"...aaaaaaaaaaaaaaaaaaaaa.....................GGGGGGGGGG.SSSSSSSSSS.LLLLLLLLL......",
	"..AAAAAAA.......bb...........................GGGGGGGGGG.SSSSSSSSSS.LLLLLLLLL......",
	"..AAAAAAA.......bbVVVVVVVVVZZZZZZZZZ.........eeppppppppppppppppppppppppppprr......",
	"..AAAAAAA.......bbVVVVVVVVVZZZZZZZZZ.........eeppppppppppppppppppppppppppprr......",
	"..AAAAAAA.......bbVVVVVVVVVZZZZZZZZZ.........eeYYYYYYYYY.UUUUUUUUU.CCCCCCCrr......",
	"..AAAAAAA.......bbVVVVVVVVVZZZZZZZZZ.........eeYYYYYYYYY.UUUUUUUUU.CCCCCCCrr......",
	"..AAAAAAA.......bbVVVVVVVVVZZZZZZZZZ.........eeYYYYYYYYY.UUUUUUUUU.CCCCCCCrr......",
	"..AAAAAAA.......bbVVVVVVVVVZZZZZZZZZ.........eeYYYYYYYYY.UUUUUUUUU.CCCCCCCrr......",
	"..AAAAAAA.......bbVVVVVVVVVZZZZZZZZZ.........eeYYYYYYYYY.UUUUUUUUU.CCCCCCCrr......",
	"................bb...........................eeYYYYYYYYY.UUUUUUUUU.CCCCCCCrr......",
	"................bb...........................eeYYYYYYYYY.UUUUUUUUU.CCCCCCCrr......",
	"................bb...........................eeYYYYYYYYY.UUUUUUUUU.CCCCCCCrr......",
	"................bb...........................eeYYYYYYYYY.UUUUUUUUU.CCCCCCCrr......",
	"...ccccccccccccccccccccccccccccccccMMMMMMMMMMMeqqqqqqqqqqqqqqqqqqqqqqqqqqqrr......",
	"...ccccccccccccccccccccccccccccccccMMMMMMMMMMMeqqqqqqqqqqqqqqqqqqqqqqqqqqqrr......",
	"..TTTTTTTTT.....WWWWWPPPPPPPPPPPPP...........eeQQQQQQQQQ.XXXXXXXXX.IIIIIIIrr......",
	"..TTTTTTTTT.....WWWWWPPPPPPPPPPPPP...........eeQQQQQQQQQ.XXXXXXXXX.IIIIIIIrr......",
	"..TTTTTTTTT.....WWWWWPPPPPPPPPPPPP...........eeQQQQQQQQQ.XXXXXXXXX.IIIIIIIrr......",
	"..TTTTTTTTT.....WWWWWPPPPPPPPPPPPP...........eeQQQQQQQQQ.XXXXXXXXX.IIIIIIIrr......",
	"..TTTTTTTTT.....WWWWWPPPPPPPPPPPPP...........eeQQQQQQQQQ.XXXXXXXXX.IIIIIIIrr......",
	"..TTTTTTTTT.....WWWWWPPPPPPPPPPPPP...........eeQQQQQQQQQ.XXXXXXXXX.IIIIIIIrr......",
	"................WWWWWPPPPPPPPPPPPP...........eeQQQQQQQQQ.XXXXXXXXX.IIIIIIIrr......",
	"................WWWWWPPPPPPPPPPPPP...........eeQQQQQQQQQ.XXXXXXXXX.IIIIIIIrr......",
	"................WWWWWPPPPPPPPPPPPP...........eeQQQQQQQQQ.XXXXXXXXX.IIIIIIIrr......",
	".........dddddddddddddddddddddd..............eesssssssssssssssssssssssssssrr......",
	".........dddddddddddddddddddddd..............eesssssssssssssssssssssssssssrr......",
	"...........NNNNNNNNNNNNNNEEEEEEEE............JJJJJJJJJJJJJJ.KKKKKKKKKKKKKKKK......",
	"...........NNNNNNNNNNNNNNEEEEEEEE............JJJJJJJJJJJJJJ.KKKKKKKKKKKKKKKK......",
	"...........NNNNNNNNNNNNNNEEEEEEEE............JJJJJJJJJJJJJJ.KKKKKKKKKKKKKKKK......",
	"...........NNNNNNNNNNNNNNEEEEEEEE............JJJJJJJJJJJJJJ.KKKKKKKKKKKKKKKK......",
	"...........NNNNNNNNNNNNNNEEEEEEEE............JJJJJJJJJJJJJJ.KKKKKKKKKKKKKKKK......",
	"...........NNNNNNNNNNNNNNEEEEEEEE............JJJJJJJJJJJJJJ.KKKKKKKKKKKKKKKK......",
	"...........NNNNNNNNNNNNNNEEEEEEEE............JJJJJJJJJJJJJJ.KKKKKKKKKKKKKKKK......",
	"...........NNNNNNNNNNNNNN....................JJJJJJJJJJJJJJ.KKKKKKKKKKKKKKKK......",
	"..................................................................................",
	"..................................................................................",
	"..................................................................................",
]

const ODA := {
	"R": "Resepsiyon",
	"O": "Acik Ofis",
	"a": "Kuzey Koridor",
	"A": "Arsiv",
	"b": "Dikey Koridor",
	"V": "Bakim / Jenerator",
	"Z": "Kazan Dairesi",
	"c": "Orta Koridor",
	"T": "Toplanti",
	"W": "Islak Koridor",
	"P": "Otopark / Depo",
	"d": "Guney Koridor",
	"N": "Yaratigin Ini",
	"E": "CIKIS",
	"G": "Ikinci Lobi",
	"S": "Sunucu Odasi",
	"L": "Laboratuvar",
	"Y": "Revir",
	"U": "Yemekhane",
	"C": "Kontrol Odasi",
	"Q": "Karantina",
	"X": "Ambar",
	"I": "Sizinti Odasi",
	"J": "Morg",
	"K": "Atik Isleme",
	"p": "B-Kuzey Koridor",
	"q": "B-Orta Koridor",
	"s": "B-Guney Koridor",
	"e": "Bati Koridor",
	"r": "Dogu Koridor",
	"M": "Gecit Koridoru",
}

static func oda_kodu(pos: Vector3) -> String:
	var i := int(round(pos.z / CELL))
	var j := int(round(pos.x / CELL))
	if i < 0 or i >= NR or j < 0 or j >= NC: return ""
	var satir: String = GRID[i]
	if j >= satir.length(): return ""
	return satir[j]

static func oda_adi(pos: Vector3) -> String:
	return ODA.get(oda_kodu(pos), "")

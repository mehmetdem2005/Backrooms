#!/usr/bin/env python3
"""Backrooms DOKU ÜRETİCİ  (AI tabanlı, iki aşamalı)
====================================================
Akış senin istediğin gibi:

  1) AŞAMA 'albedo'   : AI YALNIZCA albedo (renk) üretir. Sen bakar, beğenirsin.
  2) AŞAMA 'haritalar': Beğendiğin albedo'yu AI'ya geri verip diğer haritaları
                        (normal / roughness / ao / height) ONA ürettirir.
                        (Yerel/heuristik türetme varsayılan DEĞİL; istersen
                         --harita-yontem yerel ile açılır.)

Sağlayıcı (provider):
  nano-banana-pro   Google Gemini (Nano Banana Pro, 4K)   [GEMINI_API_KEY]
  nano-banana       Google Gemini (Nano Banana, hızlı)    [GEMINI_API_KEY]
  gpt-image         OpenAI GPT-image                       [OPENAI_API_KEY]

Örnek
-----
# 1) Önce sadece albedo:
python doku_uretici.py --asama albedo --provider nano-banana-pro --ad kirli_fayans \
    --prompt "dirty wet bathroom floor tiles, brown grime in grout, muddy patches" --seamless

# (albedo'yu beğendin) 2) AI diğer haritaları üretsin + Godot parçası:
python doku_uretici.py --asama haritalar --provider nano-banana-pro --ad kirli_fayans --tur zemin
"""
from __future__ import annotations
import argparse
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

SEAMLESS_EK = (", seamless tileable texture, no visible seams, flat even diffuse "
			   "lighting, orthographic top-down, base color / albedo only, no baked "
			   "shadows, no highlights, ultra detailed, high resolution")

# AI'ya her harita için ne ürettireceğini anlatan yönergeler. Albedo referans
# görsel olarak verilir; bu sayede hizalama (aynı düzen) korunur.
HARITA_PROMPTLARI = {
	"normal": (
		"Generate the TANGENT-SPACE NORMAL MAP of this exact texture. Output a "
		"blue/purple normal map, OpenGL convention (+Y up), encoding the surface "
		"relief of THIS image with identical layout, scale and alignment. Flat "
		"areas must be the neutral blue (128,128,255). Seamless and tileable. "
		"Output ONLY the normal map image, nothing else."),
	"roughness": (
		"Generate the grayscale ROUGHNESS MAP of this exact texture. White = rough "
		"/ matte, black = smooth / glossy (wet). Same layout, scale and alignment. "
		"Seamless and tileable. Output ONLY the grayscale map."),
	"ao": (
		"Generate the grayscale AMBIENT OCCLUSION (AO) MAP of this exact texture. "
		"White = exposed surface, dark gray = crevices, grout lines and contact "
		"shadows. Same layout and alignment. Seamless and tileable. Output ONLY "
		"the grayscale map."),
	"height": (
		"Generate the grayscale HEIGHT / DISPLACEMENT MAP of this exact texture. "
		"White = highest, black = lowest. Same layout and alignment. Seamless and "
		"tileable. Output ONLY the grayscale map."),
}

PARCA_BOYUT = {
	"zemin": (4.0, 0.12, 4.0),
	"tavan": (4.0, 0.12, 4.0),
	"duvar": (4.0, 3.0, 0.2),
}


def _ms(x: float) -> str:
	return repr(round(x, 4))


def parca_tscn_yaz(parca_yol: str, ad: str, tur: str, doku_yollari: dict) -> None:
	"""Godot 4 uyumlu parts/<ad>.tscn (BoxMesh + StandardMaterial3D)."""
	sx, sy, sz = PARCA_BOYUT[tur]

	def res(p):
		p = p.replace("\\", "/")
		i = p.find("textures/")
		return "res://" + p[i:] if i >= 0 else "res://" + os.path.basename(p)

	ext, id_map, sira = [], {}, 1
	for anahtar in ("albedo", "roughness", "normal", "ao"):
		if anahtar in doku_yollari and os.path.exists(doku_yollari[anahtar]):
			rid = f"{sira}_{anahtar}"
			id_map[anahtar] = rid
			ext.append(f'[ext_resource type="Texture2D" path="{res(doku_yollari[anahtar])}" id="{rid}"]')
			sira += 1

	mat = ['[sub_resource type="StandardMaterial3D" id="Mat_x"]']
	if "albedo" in id_map:
		mat.append(f'albedo_texture = ExtResource("{id_map["albedo"]}")')
	if "roughness" in id_map:
		mat.append(f'roughness_texture = ExtResource("{id_map["roughness"]}")')
	if "normal" in id_map:
		mat.append('normal_enabled = true')
		mat.append(f'normal_texture = ExtResource("{id_map["normal"]}")')
	if "ao" in id_map:
		mat.append('ao_enabled = true')
		mat.append(f'ao_texture = ExtResource("{id_map["ao"]}")')

	govde = (
		"[gd_scene format=3]\n\n"
		+ "\n".join(ext) + "\n\n"
		+ f'[sub_resource type="BoxMesh" id="BoxMesh_x"]\nsize = Vector3({_ms(sx)}, {_ms(sy)}, {_ms(sz)})\n\n'
		+ "\n".join(mat) + "\n\n"
		+ f'[node name="{ad}" type="MeshInstance3D"]\n'
		+ 'mesh = SubResource("BoxMesh_x")\n'
		+ 'surface_material_override/0 = SubResource("Mat_x")\n'
	)
	os.makedirs(os.path.dirname(parca_yol), exist_ok=True)
	with open(parca_yol, "w", encoding="utf-8") as f:
		f.write(govde)


def _kaydet_gorsel(ham_bytes, yol, boyut, gri=False):
	from PIL import Image
	img = Image.open(io.BytesIO(ham_bytes)).convert("RGB")
	if boyut:
		img = img.resize((boyut, boyut), Image.LANCZOS)
	if gri:
		img = img.convert("L")
	img.save(yol)


def asama_albedo(args) -> str:
	import saglayicilar
	os.makedirs(args.cikti, exist_ok=True)
	albedo_yol = os.path.join(args.cikti, f"{args.ad}_albedo.png")
	prompt = args.prompt + (SEAMLESS_EK if args.seamless else "")
	print(f"• Albedo üretiliyor [{args.provider}] …")
	sag = saglayicilar.fabrika(args.provider, args.model, args.api_key)
	ham = sag.uret(prompt, args.boyut, args.referans or None)
	_kaydet_gorsel(ham, albedo_yol, args.boyut)
	print(f"✓ Albedo: {albedo_yol}")
	print(f"\nBeğendiysen diğer haritaları AI'ya ürettir:\n"
		  f"  python {os.path.basename(__file__)} --asama haritalar "
		  f"--provider {args.provider} --ad {args.ad}"
		  + (f" --tur {args.tur}" if args.tur else " --tur zemin"))
	return albedo_yol


def asama_haritalar(args) -> None:
	albedo_yol = os.path.join(args.cikti, f"{args.ad}_albedo.png")
	if not os.path.exists(albedo_yol):
		raise SystemExit(f"Albedo yok: {albedo_yol}\nÖnce: --asama albedo")
	dokular = {"albedo": albedo_yol}

	if args.harita_yontem == "yerel":
		import pbr
		taban = os.path.join(args.cikti, args.ad)
		dokular.update(pbr.uret_haritalar(
			albedo_yol, taban, tileable=not args.no_tileable))
		for k, v in dokular.items():
			if k != "albedo":
				print(f"• {k:9s}: {v}  (yerel/heuristik)")
	else:
		import saglayicilar
		sag = saglayicilar.fabrika(args.provider, args.model, args.api_key)
		for tip in args.harita:
			yol = os.path.join(args.cikti, f"{args.ad}_{tip}.png")
			print(f"• {tip} üretiliyor (AI, albedo referanslı) …")
			ham = sag.uret(HARITA_PROMPTLARI[tip], args.boyut, [albedo_yol])
			_kaydet_gorsel(ham, yol, args.boyut, gri=(tip != "normal"))
			dokular[tip] = yol
			print(f"  ✓ {yol}")

	if args.tur:
		parca_yol = os.path.join(args.parts, f"{args.ad}.tscn")
		parca_tscn_yaz(parca_yol, args.ad, args.tur, dokular)
		print(f"• Godot parçası: {parca_yol}  → Yerleştirici'de 🔄 Yenile")
	print("✓ Bitti.")


def main() -> int:
	import saglayicilar
	ap = argparse.ArgumentParser(description="Backrooms doku üretici (AI, iki aşamalı).")
	ap.add_argument("--asama", choices=["albedo", "haritalar", "hepsi"], default="albedo",
					help="albedo: yalnız renk · haritalar: AI diğer haritaları · hepsi: ikisi")
	ap.add_argument("--ad", required=True, help="Çıktı dosya tabanı (ör. kirli_fayans)")
	ap.add_argument("--provider", choices=list(saglayicilar.VARSAYILAN_MODELLER),
					help="Görsel sağlayıcı")
	ap.add_argument("--prompt", help="Albedo üretim metni ('albedo'/'hepsi' için)")
	ap.add_argument("--model", help="Model kimliğini elle ver")
	ap.add_argument("--referans", nargs="*", default=[], help="Albedo için stil referansları")
	ap.add_argument("--seamless", action="store_true", help="Albedo'ya dikişsiz/tileable yönergesi ekle")
	ap.add_argument("--harita", nargs="*", default=["normal", "roughness", "ao"],
					choices=list(HARITA_PROMPTLARI), help="AI'ya ürettirilecek haritalar")
	ap.add_argument("--harita-yontem", choices=["ai", "yerel"], default="ai",
					help="ai: haritaları AI üretir (varsayılan) · yerel: numpy heuristik")
	ap.add_argument("--boyut", type=int, default=1024, help="Kenar pikseli (varsayılan 1024)")
	ap.add_argument("--cikti", default="textures", help="Doku klasörü (varsayılan textures/)")
	ap.add_argument("--tur", choices=list(PARCA_BOYUT), help="Verilirse parts/<ad>.tscn yazılır")
	ap.add_argument("--parts", default="parts", help="Parça klasörü")
	ap.add_argument("--no-tileable", action="store_true", help="(yerel) haritaları sarmadan üret")
	ap.add_argument("--api-key", help="API anahtarını elle ver")
	args = ap.parse_args()

	if args.asama in ("albedo", "hepsi"):
		if not args.provider or not args.prompt:
			ap.error("'albedo'/'hepsi' için --provider ve --prompt gerekli.")
		asama_albedo(args)
	if args.asama in ("haritalar", "hepsi"):
		if args.harita_yontem == "ai" and not args.provider:
			ap.error("'haritalar' (AI) için --provider gerekli.")
		asama_haritalar(args)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())

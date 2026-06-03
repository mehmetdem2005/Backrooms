#!/usr/bin/env python3
"""Backrooms DOKU ÜRETİCİ
=========================
AI ile albedo üretir, ardından AO / normal / roughness / height PNG'lerini
otomatik türetir. İsteğe bağlı olarak doğrudan bir Godot `parts/*.tscn` parçası
yazıp Yerleştirici paletine hazır hale getirir.

Sağlayıcı (provider) seçilebilir:
  nano-banana-pro   Google Gemini (Nano Banana Pro, 4K)   [GEMINI_API_KEY]
  nano-banana       Google Gemini (Nano Banana, hızlı)    [GEMINI_API_KEY]
  gpt-image         OpenAI GPT-image                       [OPENAI_API_KEY]

Örnekler
--------
# Üret + PBR + parça (kirli ıslak zemin):
python doku_uretici.py --provider nano-banana-pro --ad kirli_fayans --tur zemin \
    --prompt "dirty wet bathroom floor tiles, grime in grout, muddy" --seamless

# Var olan bir albedo'dan SADECE PBR haritaları türet (AI çağrısı yok):
python doku_uretici.py --girdi textures/floor_albedo.png --ad floor
"""
from __future__ import annotations
import argparse
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pbr  # noqa: E402

SEAMLESS_EK = (", seamless tileable texture, no visible seams, flat even diffuse "
			   "lighting, orthographic top-down, PBR albedo / base color only, no "
			   "baked shadows, no highlights, ultra detailed, high resolution")

# tur -> (BoxMesh boyutu, kategori notu)
PARCA_BOYUT = {
	"zemin": (4.0, 0.12, 4.0),
	"tavan": (4.0, 0.12, 4.0),
	"duvar": (4.0, 3.0, 0.2),
}


def _ms(x: float) -> str:
	return repr(round(x, 4))


def parca_tscn_yaz(parca_yol: str, ad: str, tur: str, doku_yollari: dict) -> None:
	"""Godot 4 uyumlu parts/<ad>.tscn üretir (BoxMesh + StandardMaterial3D)."""
	sx, sy, sz = PARCA_BOYUT[tur]
	# res:// göreli yollar
	def res(p):
		p = p.replace("\\", "/")
		i = p.find("textures/")
		return "res://" + p[i:] if i >= 0 else "res://" + os.path.basename(p)

	ext = []
	id_map = {}
	sira = 1
	for anahtar in ("albedo", "roughness", "normal", "ao"):
		if anahtar in doku_yollari:
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


def main() -> int:
	ap = argparse.ArgumentParser(description="Backrooms doku üretici (AI + PBR).")
	ap.add_argument("--ad", required=True, help="Çıktı dosya tabanı (ör. kirli_fayans)")
	ap.add_argument("--provider", choices=list(__import__("saglayicilar").VARSAYILAN_MODELLER),
					help="Görsel sağlayıcı. --girdi verilirse gerekmez.")
	ap.add_argument("--prompt", help="Üretim metni (provider ile birlikte)")
	ap.add_argument("--girdi", help="AI yerine var olan albedo PNG'sinden başla (sadece PBR)")
	ap.add_argument("--model", help="Model kimliğini elle ver (varsayılanı ezer)")
	ap.add_argument("--referans", nargs="*", default=[], help="Stil için referans görseller")
	ap.add_argument("--seamless", action="store_true", help="Prompt'a dikişsiz/tileable yönergesi ekle")
	ap.add_argument("--boyut", type=int, default=1024, help="Albedo kenar pikseli (varsayılan 1024)")
	ap.add_argument("--cikti", default="textures", help="Doku çıktı klasörü (varsayılan textures/)")
	ap.add_argument("--tur", choices=list(PARCA_BOYUT), help="Verilirse parts/<ad>.tscn de yazılır")
	ap.add_argument("--parts", default="parts", help="Parça klasörü (varsayılan parts/)")
	ap.add_argument("--no-pbr", action="store_true", help="Sadece albedo (harita türetme)")
	ap.add_argument("--no-tileable", action="store_true", help="Haritaları sarmadan (wrap) üret")
	ap.add_argument("--normal-guc", type=float, default=2.5)
	ap.add_argument("--rough-min", type=float, default=0.3)
	ap.add_argument("--rough-max", type=float, default=0.92)
	ap.add_argument("--api-key", help="API anahtarını elle ver (ortam değişkeni yerine)")
	args = ap.parse_args()

	from PIL import Image
	os.makedirs(args.cikti, exist_ok=True)
	albedo_yol = os.path.join(args.cikti, f"{args.ad}_albedo.png")

	# 1) Albedo: ya AI üret ya da var olandan al
	if args.girdi:
		img = Image.open(args.girdi).convert("RGB")
		if args.boyut and img.size != (args.boyut, args.boyut):
			img = img.resize((args.boyut, args.boyut), Image.LANCZOS)
		img.save(albedo_yol)
		print(f"• Albedo (girdiden): {albedo_yol}")
	else:
		if not args.provider or not args.prompt:
			ap.error("AI üretimi için --provider ve --prompt gerekli (ya da --girdi ver).")
		import saglayicilar
		prompt = args.prompt + (SEAMLESS_EK if args.seamless else "")
		print(f"• Üretiliyor [{args.provider}] …")
		sag = saglayicilar.fabrika(args.provider, args.model, args.api_key)
		ham = sag.uret(prompt, args.boyut, args.referans or None)
		img = Image.open(io.BytesIO(ham)).convert("RGB")
		if args.boyut:
			img = img.resize((args.boyut, args.boyut), Image.LANCZOS)
		img.save(albedo_yol)
		print(f"• Albedo: {albedo_yol}")

	dokular = {"albedo": albedo_yol}

	# 2) PBR haritaları
	if not args.no_pbr:
		taban = os.path.join(args.cikti, args.ad)
		harita = pbr.uret_haritalar(
			albedo_yol, taban,
			tileable=not args.no_tileable,
			normal_guc=args.normal_guc,
			rough_min=args.rough_min, rough_max=args.rough_max,
		)
		dokular.update(harita)
		for k, v in harita.items():
			print(f"• {k:9s}: {v}")

	# 3) İsteğe bağlı Godot parçası
	if args.tur:
		parca_yol = os.path.join(args.parts, f"{args.ad}.tscn")
		parca_tscn_yaz(parca_yol, args.ad, args.tur, dokular)
		print(f"• Godot parçası: {parca_yol}  → Yerleştirici'de 🔄 Yenile")

	print("✓ Bitti.")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())

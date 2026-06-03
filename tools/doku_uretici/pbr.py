"""PBR harita üretici — tek bir albedo görselinden normal / roughness / AO / height
PNG'leri türetir. Yaklaşık (heuristik) ama stilize Backrooms yüzeyleri için yeterli.

Tileable=True iken tüm gradyan/bulanıklık işlemleri kenarlarda SARILARAK (wrap)
hesaplanır; böylece türetilen haritalar da dikişsiz döşenir.

Bağımlılık: numpy, Pillow.
"""
from __future__ import annotations
import numpy as np
from PIL import Image, ImageFilter


# ----------------------------------------------------------------- yardımcı G/Ç
def yukle_rgb(yol: str) -> np.ndarray:
	"""PNG/JPG -> float32 RGB dizi [0,1], boyut (H, W, 3)."""
	img = Image.open(yol).convert("RGB")
	return np.asarray(img, dtype=np.float32) / 255.0


def kaydet(arr: np.ndarray, yol: str) -> None:
	"""float [0,1] (H,W) gri ya da (H,W,3) RGB diziyi 8-bit PNG yapar."""
	a = np.clip(arr, 0.0, 1.0)
	a = (a * 255.0 + 0.5).astype(np.uint8)
	Image.fromarray(a).save(yol)


def luminans(rgb: np.ndarray) -> np.ndarray:
	return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


# ----------------------------------------------------------------- height
def yukseklik(rgb: np.ndarray, kontrast: float = 1.15) -> np.ndarray:
	"""Albedo parlaklığından yükseklik (height) alanı. Açık = yüksek."""
	h = luminans(rgb)
	ort = float(h.mean())
	h = (h - ort) * kontrast + ort
	# yumuşak normalize
	mn, mx = float(h.min()), float(h.max())
	if mx - mn > 1e-6:
		h = (h - mn) / (mx - mn)
	return np.clip(h, 0.0, 1.0)


# ----------------------------------------------------------------- gradyan/bulanıklık (tileable)
def _gradyan(h: np.ndarray, tileable: bool):
	if tileable:
		dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
		dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
	else:
		dy, dx = np.gradient(h)
	return dx, dy


def _bulanik(h: np.ndarray, yaricap: float, tileable: bool) -> np.ndarray:
	"""Gauss bulanıklık. Tileable ise 3x döşeyip ortayı kırparak sarılı bulanıklık."""
	img = Image.fromarray((np.clip(h, 0, 1) * 255).astype(np.uint8))
	if tileable:
		H, W = h.shape
		buyuk = Image.new("L", (W * 3, H * 3))
		for gx in range(3):
			for gy in range(3):
				buyuk.paste(img, (gx * W, gy * H))
		buyuk = buyuk.filter(ImageFilter.GaussianBlur(yaricap))
		buyuk = buyuk.crop((W, H, W * 2, H * 2))
		return np.asarray(buyuk, dtype=np.float32) / 255.0
	img = img.filter(ImageFilter.GaussianBlur(yaricap))
	return np.asarray(img, dtype=np.float32) / 255.0


# ----------------------------------------------------------------- normal
def normal(h: np.ndarray, guc: float = 2.5, tileable: bool = True) -> np.ndarray:
	"""Height -> tanjant-uzay normal haritası (OpenGL/Godot, Y yukarı)."""
	dx, dy = _gradyan(h, tileable)
	nx = -dx * guc
	ny = dy * guc          # Godot normal: yeşil yukarı (+Y)
	nz = np.ones_like(h)
	uz = np.sqrt(nx * nx + ny * ny + nz * nz)
	nx, ny, nz = nx / uz, ny / uz, nz / uz
	return np.stack([nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5], axis=-1)


# ----------------------------------------------------------------- roughness
def roughness(rgb: np.ndarray, r_min: float = 0.3, r_max: float = 0.92,
			  parlak_duzgun: bool = True, detay: float = 0.15) -> np.ndarray:
	"""Albedo'dan roughness. parlak_duzgun=True: açık bölgeler daha pürüzsüz
	(ıslak/parlak), koyu bölgeler daha pürüzlü (kuru kir). detay: yüksek-frekans katkı."""
	L = luminans(rgb)
	t = L if parlak_duzgun else (1.0 - L)
	r = r_max + (r_min - r_max) * t           # t=1 -> r_min
	if detay > 0.0:
		hp = L - _bulanik(L, 4.0, True)       # yüksek geçiren
		r = r + hp * detay
	return np.clip(r, 0.0, 1.0)


# ----------------------------------------------------------------- ambient occlusion
def ao(h: np.ndarray, yaricap: float = 10.0, guc: float = 1.4,
	   tileable: bool = True) -> np.ndarray:
	"""Yükseklikten kavite-tabanlı AO. Çevresine göre çukur olan yerler kararır."""
	b = _bulanik(h, yaricap, tileable)
	occ = np.clip((b - h) * guc, 0.0, 1.0)
	# çok ince temas gölgesi için ikinci, dar ölçek
	b2 = _bulanik(h, max(yaricap * 0.35, 2.0), tileable)
	occ = np.maximum(occ, np.clip((b2 - h) * guc * 0.8, 0.0, 1.0))
	return np.clip(1.0 - occ, 0.0, 1.0)


# ----------------------------------------------------------------- ana akış
def uret_haritalar(albedo_yol: str, cikti_taban: str, *, tileable: bool = True,
				   normal_guc: float = 2.5, rough_min: float = 0.3,
				   rough_max: float = 0.92, ao_yaricap: float | None = None,
				   height_de: bool = True) -> dict:
	"""albedo_yol'dan haritaları üretip '<cikti_taban>_normal.png' vb. kaydeder.
	Dönen: üretilen dosya yolları sözlüğü."""
	rgb = yukle_rgb(albedo_yol)
	H, W = rgb.shape[:2]
	if ao_yaricap is None:
		ao_yaricap = max(min(H, W) / 100.0, 4.0)

	h = yukseklik(rgb)
	cikti = {}

	n = normal(h, guc=normal_guc, tileable=tileable)
	kaydet(n, f"{cikti_taban}_normal.png");      cikti["normal"] = f"{cikti_taban}_normal.png"
	r = roughness(rgb, r_min=rough_min, r_max=rough_max)
	kaydet(r, f"{cikti_taban}_roughness.png");   cikti["roughness"] = f"{cikti_taban}_roughness.png"
	a = ao(h, yaricap=ao_yaricap, tileable=tileable)
	kaydet(a, f"{cikti_taban}_ao.png");          cikti["ao"] = f"{cikti_taban}_ao.png"
	if height_de:
		kaydet(h, f"{cikti_taban}_height.png");  cikti["height"] = f"{cikti_taban}_height.png"
	return cikti

"""Görsel üretim sağlayıcıları (provider) — Nano Banana (Google Gemini) ve
GPT-image (OpenAI) arasında seçim. SDK'lar TEMBEL içe aktarılır; sadece o
sağlayıcıyı kullanırken gereklidir (PBR kısmı SDK'sız da çalışır).

Ortam değişkenleri:
  GEMINI_API_KEY (veya GOOGLE_API_KEY)  -> Nano Banana / Nano Banana Pro
  OPENAI_API_KEY                        -> GPT-image
"""
from __future__ import annotations
import os
import base64

# Provider takma adı -> varsayılan model kimliği.
# NOT: Görsel model kimlikleri sık değişir. Çalışmazsa Google AI Studio /
# OpenAI panelindeki güncel model listesinden doğrula ve --model ile geç.
VARSAYILAN_MODELLER = {
	"nano-banana-pro": "gemini-3-pro-image-preview",       # Nano Banana Pro (4K, çok referans)
	"nano-banana":     "gemini-2.5-flash-image-preview",   # Nano Banana (hızlı/ucuz)
	"gpt-image":       "gpt-image-1",                       # OpenAI GPT-image
}


class Saglayici:
	def uret(self, prompt: str, boyut: int, referanslar: list[str] | None = None) -> bytes:
		"""Verilen prompt'tan bir PNG görsel üretir, ham bayt döndürür."""
		raise NotImplementedError


class GeminiSaglayici(Saglayici):
	"""Nano Banana / Nano Banana Pro — Google Gemini görsel modelleri.

	İki mod:
	  • AI Studio (vertex=False): api_key ile. UYARI: $300 krediyi atlayıp
	    KARTTAN çekebilir.
	  • Vertex AI (vertex=True): proje + ADC ile. Kullanım Vertex AI'ye yazılır,
	    böylece $300 Free Trial kredisinden düşer. (gcloud ADC gerekir.)
	"""
	def __init__(self, model: str, api_key: str | None = None,
				 vertex: bool = False, proje: str | None = None,
				 lokasyon: str = "us-central1"):
		try:
			from google import genai
		except ImportError as e:
			raise SystemExit(
				"google-genai kurulu değil. Kur:  pip install google-genai") from e
		self._genai = genai
		if vertex:
			proje = proje or os.environ.get("GOOGLE_CLOUD_PROJECT")
			if not proje:
				raise SystemExit("Vertex modu için --proje <PROJE_ID> (ya da "
								 "GOOGLE_CLOUD_PROJECT) gerekli.")
			lokasyon = lokasyon or os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")
			# Kimlik: gcloud auth application-default login (ADC)
			self.client = genai.Client(vertexai=True, project=proje, location=lokasyon)
		else:
			anahtar = api_key or os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
			if not anahtar:
				raise SystemExit("GEMINI_API_KEY (veya GOOGLE_API_KEY) tanımlı değil.")
			self.client = genai.Client(api_key=anahtar)
		self.model = model

	def uret(self, prompt, boyut, referanslar=None):
		from PIL import Image
		icerik: list = [prompt]
		for r in (referanslar or []):
			icerik.append(Image.open(r))
		yanit = self.client.models.generate_content(model=self.model, contents=icerik)
		for cand in (yanit.candidates or []):
			parts = getattr(getattr(cand, "content", None), "parts", None) or []
			for part in parts:
				inline = getattr(part, "inline_data", None)
				if inline and getattr(inline, "data", None):
					return inline.data
		raise RuntimeError(
			"Gemini görsel döndürmedi. Model erişimini/kimliğini kontrol et: %s" % self.model)


class OpenAISaglayici(Saglayici):
	"""GPT-image — OpenAI görsel modeli."""
	def __init__(self, model: str, api_key: str | None = None):
		try:
			from openai import OpenAI
		except ImportError as e:
			raise SystemExit("openai kurulu değil. Kur:  pip install openai") from e
		anahtar = api_key or os.environ.get("OPENAI_API_KEY")
		if not anahtar:
			raise SystemExit("OPENAI_API_KEY tanımlı değil.")
		self.client = OpenAI(api_key=anahtar)
		self.model = model

	def uret(self, prompt, boyut, referanslar=None):
		# GPT-image kare boyutları: 1024 / 1536. Güvenli taraf: 1024 kare.
		kenar = 1024 if boyut <= 1024 else 1536
		olcu = f"{kenar}x{kenar}"
		if referanslar:
			dosyalar = [open(r, "rb") for r in referanslar]
			try:
				yanit = self.client.images.edit(
					model=self.model, image=dosyalar, prompt=prompt, size=olcu)
			finally:
				for f in dosyalar:
					f.close()
		else:
			yanit = self.client.images.generate(
				model=self.model, prompt=prompt, size=olcu, n=1)
		b64 = yanit.data[0].b64_json
		return base64.b64decode(b64)


def fabrika(provider: str, model: str | None = None, api_key: str | None = None,
			vertex: bool = False, proje: str | None = None,
			lokasyon: str = "us-central1") -> Saglayici:
	m = model or VARSAYILAN_MODELLER.get(provider)
	if m is None:
		raise SystemExit("Bilinmeyen provider: %s (seçenekler: %s)"
						 % (provider, ", ".join(VARSAYILAN_MODELLER)))
	if provider in ("nano-banana-pro", "nano-banana"):
		return GeminiSaglayici(m, api_key, vertex=vertex, proje=proje, lokasyon=lokasyon)
	if provider == "gpt-image":
		return OpenAISaglayici(m, api_key)
	raise SystemExit("Bilinmeyen provider: %s" % provider)

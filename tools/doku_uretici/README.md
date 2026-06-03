# Backrooms Doku Üretici

AI ile **albedo** üretir, sonra **AO / normal / roughness / height** PNG'lerini
otomatik türetir. İstersen doğrudan bir Godot `parts/<ad>.tscn` parçası yazıp
**Yerleştirici** paletine hazırlar.

İki sağlayıcı arasında seçim yaparsın:

| Provider | Model | Anahtar |
|---|---|---|
| `nano-banana-pro` | Google Gemini (Nano Banana Pro, 4K) | `GEMINI_API_KEY` |
| `nano-banana` | Google Gemini (Nano Banana, hızlı/ucuz) | `GEMINI_API_KEY` |
| `gpt-image` | OpenAI GPT-image | `OPENAI_API_KEY` |

## Kurulum
```bash
cd tools/doku_uretici
pip install -r requirements.txt   # sadece kullanacağın provider'ın SDK'sı şart
```

## API anahtarını alma

### Google (Nano Banana / Nano Banana Pro)
1. https://aistudio.google.com → **Get API key** → **Create API key**.
2. (Ücretli/yüksek kota için) Anahtarın projesini Google Cloud'da **$300 kredili
   faturalandırma hesabına** bağla. Ücretsiz katman küçük üretim için yeter.
3. ```bash
   export GEMINI_API_KEY="AIza..."
   ```
> Not: Görsel model kimlikleri değişebilir. `nano-banana-pro` çalışmazsa AI
> Studio'daki güncel görsel modeli `--model <id>` ile geç.

### OpenAI (GPT-image)
1. https://platform.openai.com → **API keys** → **Create new secret key**.
2. **Billing** → ödeme yöntemi ekle (GPT-image ücretlidir, ücretsiz katmanı yok).
3. ```bash
   export OPENAI_API_KEY="sk-..."
   ```

## Kullanım — iki aşamalı (önce albedo, beğenince devamı)

```bash
# 1) ÖNCE SADECE ALBEDO — bak, beğen:
python doku_uretici.py --asama albedo --provider nano-banana-pro --ad kirli_fayans \
    --prompt "dirty wet bathroom floor tiles, brown grime in the grout, muddy patches" \
    --seamless

# 2) BEĞENDİYSEN — diğer haritaları AI ürretsin + Godot parçası:
python doku_uretici.py --asama haritalar --provider nano-banana-pro --ad kirli_fayans --tur zemin

# (İstersen tek seferde ikisi):
python doku_uretici.py --asama hepsi --provider nano-banana-pro --ad kirli_fayans --tur zemin \
    --prompt "..." --seamless
```

1. aşama `textures/kirli_fayans_albedo.png` üretir.
2. aşama beğendiğin albedo'yu **AI'ya referans verip** `_normal/_roughness/_ao` haritalarını
   **AI'ya** ürettirir (aynı hizada, tileable) ve `--tur` ile `parts/<ad>.tscn` yazar →
   Godot'ta Yerleştirici'de **🔄 Yenile**.

## Önemli bayraklar
| Bayrak | İş |
|---|---|
| `--asama` | `albedo` (yalnız renk) · `haritalar` (AI diğer haritalar) · `hepsi` |
| `--provider` | `nano-banana-pro` / `nano-banana` / `gpt-image` |
| `--prompt` | Albedo üretim metni |
| `--seamless` | Albedo'ya dikişsiz/tileable + düz ışık yönergesi ekler |
| `--harita` | AI'ya ürettirilecek haritalar (vars. `normal roughness ao`) |
| `--harita-yontem` | `ai` (varsayılan) · `yerel` (numpy heuristik, ücretsiz/offline) |
| `--tur` | `zemin` / `duvar` / `tavan` → `parts/.tscn` yazar |
| `--referans …` | Albedo için stil referansları (few-shot) |
| `--boyut` | Kenar pikseli (varsayılan 1024) |
| `--model` | Model kimliğini elle ezer |

## Dürüst notlar
- **Haritaları artık AI üretiyor** (varsayılan). Görsel modeller gerçek bir normal-map
  *hesaplamaz*; albedo'ya bakıp normal-map'e **benzeyen** bir görsel boyar — yani bu da
  yaklaşıktır, ama modelin malzeme bilgisi sayesinde basit parlaklık türetmesinden
  genelde daha tutarlıdır. Sonucu **sen onaylarsın** (önce albedo, sonra haritalar).
- `--harita-yontem yerel`: API harcamadan, numpy ile **heuristik** türetme (parlaklık→
  kabartma). Hızlı/bedava ama renk≠derinlik olan yerlerde sahte kabartma yapar.
- **Tileable**: albedo için mutlaka `--seamless` kullan.
- Maliyet: birkaç doku = sentler. $300 kredi bu iş için kat kat fazlasıyla yeter.

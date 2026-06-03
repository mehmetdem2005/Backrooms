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

## Kullanım

```bash
# Üret + PBR + Godot parçası (kirli ıslak zemin):
python doku_uretici.py --provider nano-banana-pro --ad kirli_fayans --tur zemin \
    --prompt "dirty wet bathroom floor tiles, brown grime in the grout, muddy patches" \
    --seamless

# Stil tutarlılığı için referans görselle:
python doku_uretici.py --provider nano-banana-pro --ad pis_duvar --tur duvar \
    --prompt "grimy stained wall tiles, water streaks" --seamless \
    --referans textures/gray_tile_wall_clean_albedo.png

# AI YOK — var olan bir albedo'dan sadece PBR haritaları:
python doku_uretici.py --girdi textures/floor_albedo.png --ad floor
```

Çıktılar `textures/<ad>_albedo|normal|roughness|ao|height.png`. `--tur` verirsen
`parts/<ad>.tscn` de yazılır → Godot'ta Yerleştirici panelinde **🔄 Yenile**.

## Önemli bayraklar
| Bayrak | İş |
|---|---|
| `--provider` | `nano-banana-pro` / `nano-banana` / `gpt-image` |
| `--prompt` | Üretim metni |
| `--seamless` | Prompt'a dikişsiz/tileable + düz ışık yönergesi ekler |
| `--girdi <png>` | AI yerine var olan albedo'dan başla (yalnız PBR) |
| `--tur` | `zemin` / `duvar` / `tavan` → `parts/.tscn` yazar |
| `--referans …` | Stil için referans görseller (few-shot) |
| `--boyut` | Albedo kenar pikseli (varsayılan 1024) |
| `--model` | Model kimliğini elle ezer |
| `--normal-guc`, `--rough-min`, `--rough-max` | PBR ince ayar |
| `--no-pbr`, `--no-tileable` | Harita türetmeyi / sarmayı kapat |

## Notlar
- **Tileable** üretirken prompt'a mutlaka dikişsizlik iste (`--seamless`). Türetilen
  haritalar zaten kenarlarda sarılarak (wrap) hesaplandığı için dikişsiz döşenir.
- PBR haritaları tek albedo'dan **yaklaşık** türetilir; foto-gerçek PBR taraması
  değildir ama stilize Backrooms yüzeyleri için fazlasıyla yeterlidir.
- Maliyet: birkaç doku = sentler. $300 kredi bu iş için kat kat fazlasıyla yeter.

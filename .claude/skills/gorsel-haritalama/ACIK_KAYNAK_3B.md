# Tek görsel → 3B: açık kaynak önceki çalışmalar (prior art)

Bu işi (tek görselden 3B model) zaten yapan açık kaynak projeler. Yeniden icat
etmeden bunları kullan. (Araştırma: Haz 2026.)

## A) Tek görsel → 3B MESH (tam obje, arka dahil)
| Proje | Kalite | Donanım | Bizde? |
|---|---|---|---|
| **TRELLIS 2** (Microsoft) | En iyi, gerçek PBR | ~24GB VRAM | GPU yok ❌ |
| **Hunyuan3D 2.1** | Yüksek doku | ~6GB VRAM | GPU yok ❌ |
| **Stable Fast 3D** | <1 sn, hızlı | GPU | GPU yok ❌ |
| **InstantMesh** | Hızlı mesh | GPU | GPU yok ❌ |
| **TripoSR** (VAST-AI/Stability) | Orta, hızlı | **CPU çalışır** | ✅ uygun |

Mimari (2026 baskın): çok-görünüm difüzyon + ileri-besleme rekonstrüksiyon
(Hunyuan3D, TRELLIS, InstantMesh). Tek görünüm transformer: TripoSR.
- TripoSR kod: https://github.com/VAST-AI-Research/TripoSR  (CPU: `--device cpu
  --tsr-chunk-size 8192`). Ağırlık: HF `stabilityai/TripoSR`.
- Not: TripoSR Objaverse'te eğitildi; KAPI gibi düz/ince objelerde şişkin/yuvarlak
  çıkabilir. Düz objelerde "derinlik+displace" (B) daha sadık olabilir.

## B) Tek görsel → DERINLIK → kabartılı mesh (düz/levha objeler için sadık)
Monoküler derinlik modeli ön yüzün gerçek kabartısını çıkarır; foto doku korunur.
| Model | Özellik | Bizde |
|---|---|---|
| **Depth Pro** (Apple) | EN keskin kenar, yüksek-res, metrik | ✅ (büyük, CPU yavaş) |
| **Depth Anything V2 - Large** | Hız/doğruluk dengesi en iyi (DA-2K %97.1) | ✅ |
| **Depth Anything V2 - Small** | En hızlı | ✅ |
| Marigold (difüzyon) | İnce sınır, ama gürültülü + yavaş | ✅ ama yavaş |
- HF transformers `pipeline("depth-estimation", model=...)`:
  `apple/DepthPro-hf`, `depth-anything/Depth-Anything-V2-Large-hf`.

## Bizim boru hattı (CPU, genel, deterministik)
`tools/gorsel_model/`:
1. `analiz.py` (skill) → rembg silüet + perspektif oran + rectified foto + outline
2. `derinlik.py` → **Depth Pro / DA-V2-Large** ile gerçek kabartı (detrend) → depth16
3. `insa.py` → yoğun grid'i depth16 ile displace + foto doku → glb (ve/veya TripoSR)

## Kaynaklar
- TripoSR: https://github.com/VAST-AI-Research/TripoSR
- Depth Pro: https://github.com/apple/ml-depth-pro , https://arxiv.org/pdf/2410.02073
- Depth Anything V2: https://depth-anything-v2.github.io/
- TRELLIS/Hunyuan3D/SF3D: HF model kartları (GPU)

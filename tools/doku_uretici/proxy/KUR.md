# Vertex Proxy Kurulumu (telefondan, $300 krediyle)

Bu proxy'i **bir kez** kurarsın; sonra HTML uygulaman tamamen **$300 Vertex kredinden** çalışır (karttan değil). Hepsi telefondaki tarayıcıdan **Cloud Shell** ile yapılır, PC/terminal gerekmez.

## Adımlar (Cloud Shell — tarayıcı)

1. Telefonda aç: **https://shell.cloud.google.com** → Google ile gir (Cloud Shell açılır, gcloud hazır gelir).

2. Projeyi seç (kredine bağlı proje kimliğini yaz):
   ```
   gcloud config set project PROJE_ID
   ```

3. Gerekli servisleri aç:
   ```
   gcloud services enable aiplatform.googleapis.com run.googleapis.com cloudbuild.googleapis.com
   ```

4. Proxy kodunu al:
   ```
   git clone -b claude/asset-painting-plugin-wGWcn https://github.com/mehmetdem2005/backrooms
   cd backrooms/tools/doku_uretici/proxy
   ```

5. Çalıştıran servis hesabına Vertex izni ver:
   ```
   PN=$(gcloud projects describe PROJE_ID --format='value(projectNumber)')
   gcloud projects add-iam-policy-binding PROJE_ID \
     --member="serviceAccount:${PN}-compute@developer.gserviceaccount.com" \
     --role="roles/aiplatform.user"
   ```

6. Deploy et (kendi gizli kodunu `PROXY_SECRET`'e yaz):
   ```
   gcloud run deploy doku-proxy --source . --region us-central1 \
     --allow-unauthenticated \
     --set-env-vars PROXY_SECRET=gizli123,PROJECT=PROJE_ID
   ```
   Bitince bir **Service URL** verir, örn:
   `https://doku-proxy-xxxxx-uc.a.run.app`  → **bunu kopyala.**

## HTML uygulamasına bağla
Uygulamada **⚙️ → Mod: "Vertex proxy ($300 kredi)"** seç ve gir:
- **Proxy URL**: yukarıdaki Service URL
- **Proje**: PROJE_ID
- **Bölge**: `us-central1` (Pro model bölgede yoksa `global` dene)
- **Gizli kod**: `gizli123` (deploy'da yazdığın)
- **Model**: istediğin (ör. `gemini-3-pro-image-preview`)

Artık üretim **krediden** gider. Doğrula: **Billing → Reports → Vertex AI** + Credits düşüşü.

## Notlar
- Maliyet düşük; ama proxy `--allow-unauthenticated` olduğu için URL'i + gizli kodu **paylaşma** (gizli kod kötüye kullanımı engeller).
- Model bölgede yoksa proxy Vertex'in hatasını aynen döndürür (uygulamada görürsün) → bölgeyi `global` yap ya da modeli değiştir.
- Durdurmak istersen: `gcloud run services delete doku-proxy --region us-central1`.

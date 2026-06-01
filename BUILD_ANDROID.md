# Android APK Build — Backrooms Premium Mobile V3

Bu doküman, `game_src/` içindeki Godot projesinin nasıl imzalı bir Android APK'ya
dönüştürüldüğünü açıklar. Büyük ikili dosyalar (Godot editörü, export template'leri,
Android SDK, üretilen APK, keystore) bilerek repoya dahil edilmez (bkz. `.gitignore`);
aşağıdaki adımlarla derleme anında elde edilir.

## Gereksinimler
- Godot **4.6.3-stable** (Linux editörü) + aynı sürüm export template'leri
- JDK 21 (keystore üretimi ve `apksigner` için)
- Android SDK build-tools (`apksigner`, `zipalign`) — prebuilt template export'u için yeterli

## Adımlar

```bash
# 1) Godot 4.6.3 editörü
curl -L -o godot_editor.zip \
  https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip
unzip godot_editor.zip && mv Godot_v4.6.3-stable_linux.x86_64 godot && chmod +x godot

# 2) Export template'leri
curl -L -o templates.tpz \
  https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates/4.6.3.stable
unzip -o templates.tpz -d /tmp/tpz && cp /tmp/tpz/templates/* ~/.local/share/godot/export_templates/4.6.3.stable/

# 3) Android build-tools (apksigner + zipalign)
curl -L -o build-tools.zip https://dl.google.com/android/repository/build-tools_r36_linux.zip
unzip build-tools.zip -d /tmp/bt
mkdir -p android-sdk/build-tools && mv /tmp/bt/android-16 android-sdk/build-tools/36.0.0

# 4) Debug keystore
keytool -keyalg RSA -genkeypair -alias androiddebugkey \
  -keypass android -keystore debug.keystore -storepass android \
  -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12

# 5) Godot editör ayarlarını yapılandır (~/.config/godot/editor_settings-4.6.tres):
#   export/android/android_sdk_path  = "<repo>/android-sdk"
#   export/android/debug_keystore    = "<repo>/debug.keystore"
#   export/android/debug_keystore_pass = "android"

# 6) Import + export
./godot --headless --path game_src --import
./godot --headless --path game_src --export-debug "Android" export/BackroomsPremiumV3.apk
```

## Çıktı
| Özellik | Değer |
|---|---|
| Paket | `com.example.backrooms.premium` |
| Sürüm | 3.0 (code 1) |
| Min Android | 7.0 (API 24) |
| Mimariler | arm64-v8a, armeabi-v7a, x86_64 |
| İmza | APK Signature Scheme v2 + v3 (debug) |

> Not: Üretilen APK **debug-imzalıdır**; yan yükleme (sideload) ile test cihazlarına
> kurulabilir. Play Store yayını için ayrı bir **release keystore** ile imzalanmalıdır.
> Bu durumda `export_presets.cfg` içindeki release keystore alanları ve
> `--export-release` kullanılır.

Android export ayarları `game_src/export_presets.cfg` dosyasında tanımlıdır.

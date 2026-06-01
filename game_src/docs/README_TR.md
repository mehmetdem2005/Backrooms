# Backrooms Premium Mobile V2 - Godot 4.6.3

Bu paket **üst seviye / pahalı telefonlar** için hazırlanmış daha kaliteli Backrooms prototipidir. Düşük telefon hedefi değildir.

## V2 yenilikleri

- Ses katmanı eklendi: floresan uğultusu, oda tonu, boru gürültüsü, ayak sesi, kalp atışı, metal vurma, ışık patlaması, varlık nefesi ve kovalamaca sesi.
- `AudioDirector.gd` eklendi: 2D ambience katmanları + 3D rastgele korku sesleri + canavar durumuna göre müzik/kalp atışı.
- Canavar daha akıllı oldu: görme, duyma, son bilinen konuma gitme, arama, kovalamaca ve pusu kurma durumları var.
- Koşmak artık gürültü üretir; canavar oyuncuyu duyabilir.
- Fener az da olsa oyuncuyu ele verir; stres arttıkça fener titrer.
- Harita 35x35 yerine 49x49 oldu.
- Oda sayısı ve görsel detay yoğunluğu artırıldı.
- Haritaya kolonlar, yanlış çıkış tabelaları, kâğıtlar, küf lekeleri, tavan boruları ve eksik tavan panelleri eklendi.
- Işık yöneticisine korku olayları sırasında bölgesel flicker ve kısa blackout eklendi.
- HUD'a ses seviyesi ve canavar durumu göstergesi eklendi.

## Açma

1. ZIP'i çıkar.
2. Godot 4.6.3 ile `project.godot` dosyasını aç.
3. Ana sahne: `scenes/Main.tscn`.
4. Play'e bas.

## Kontroller

- Mobil: sol joystick hareket, sağ taraf kamera bakışı, koşma/fener butonları.
- PC test: WASD, mouse, Shift, F.

## Performans

Bu sürüm güçlü telefon içindir. FPS düşerse `scripts/PremiumGameRoot.gd` içindeki:

```gdscript
@export var premium_mode: bool = true
```

satırını `false` yap. Bu volumetric fog, reflection probe ve dust parçacıklarını kapatır.

## Ses sistemi

Ses dosyaları `audio/` klasöründedir. Hepsi runtime yüklenir. Godot import ettikten sonra otomatik çalışır.

Önemli dosyalar:

- `scripts/horror/AudioDirector.gd`
- `scripts/horror/ShadowStalker.gd`
- `scripts/horror/SmartFluorescentLightManager.gd`
- `scripts/level/PremiumBackroomsBuilder.gd`
- `scripts/player/PremiumFpsPlayer.gd`
- `scripts/ui/PremiumHud.gd`

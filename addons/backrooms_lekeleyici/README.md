# Backrooms Lekeleyici 🖌️

Godot 4.6 için **gelişmiş leke / boya / çamur** eklentisi. "Parça Yerleştirici"
(yerlestirici) eklentisiyle koyduğun **duvar, zemin, tavan** parçalarının üzerine
fırça ile leke basar.

> **Neden Decal değil?** Proje **Mobile renderer** kullanıyor ve Godot'ta `Decal`
> node'u Mobile backend'de çizilmez. Bu yüzden eklenti, yüzeye hizalanmış şeffaf
> **sticker mesh** (QuadMesh + StandardMaterial3D) basar — Mobile dahil **her**
> render motorunda çalışır.

## Kurulum

1. `addons/backrooms_lekeleyici/` klasörünü Godot projenin `addons/` klasörüne kopyala.
2. **Proje → Proje Ayarları → Eklentiler** menüsünden **Backrooms Lekeleyici**'yi etkinleştir.
3. Sağ tarafta **Lekeleyici** paneli açılır.

## Kullanım

1. `Harita.tscn` sahnesini aç.
2. Sağ paneldeki **🖌 Boya** düğmesine bas.
3. 3B sahnede bir parçanın üstüne **sol tıkla ve sürükle** → lekeler basılır.
4. Silmek için **🧽 Sil** → silmek istediğin lekeye dokun.
5. **✋** ile modu kapat (normal düzenlemeye dön).

> Tüm lekeler sahne kökünde **`Lekeler`** adlı bir düğüm altında toplanır ve
> sahneyle birlikte kaydedilir. Tam **Geri Al / Yinele (Ctrl+Z / Ctrl+Y)** desteklidir.

## Gelişmiş Özellikler

| Özellik | Açıklama |
|---|---|
| **Leke Paleti** | 17 leke dokusu. İstediklerini seç → fırça bunlar arasından rastgele seçer. `textures/stains/` içine yeni PNG atarsan otomatik gelir. |
| **Hazır Ayarlar** | Çamur, Kir/Toz, Su Lekesi, Kan, Yağ/Petrol, Küf, Boya Sıçraması — tek tıkla renk/opaklık/ıslaklık ayarı. |
| **Boyut Min/Max** | Her lekeye rastgele boyut (m). |
| **Opaklık Min/Max** | Her lekeye rastgele saydamlık. |
| **Saçılma Adedi + Yarıçapı** | Tek dokunuşta birden çok leke saçar (sprey etkisi). |
| **Sürükleme Aralığı** | Sürüklerken lekeler arası mesafe. |
| **Renk Tonu** | Lekeyi istediğin renge boyar (dokuyu çarpar). |
| **Kenar Eşiği / Yumuşaklığı** | Siyah zeminden alfa üretimini ayarlar (lekenin kenar geçişi). |
| **Yüzey Filtresi** | Sadece **Zemin / Duvar / Tavan** ya da **Hepsi**. Normal yönüne göre süzer. |
| **Rastgele Döndür** | Her leke rastgele açıyla basılır (tekrar görünmesin diye). |
| **Islak / Parlak** | Metalik + düşük pürüzlülük (su, kan, yağ için). |
| **Kendinden Işıklı** | Unshaded — sahne ışığından etkilenmez (boya sıçraması için). |
| **Yüzeyden Uzaklık** | Z-fighting'i önleyen yüzey ofseti. |

## Teknik Notlar

- Işın atma collision/StaticBody gerektirmez; parça mesh'lerine **üçgen bazlı**
  (Möller–Trumbore) çarpışma yapar (`leke_isin.gd`).
- Siyah zeminli RGB lekeler, parlaklıktan **alfa kanalı** üretilerek şeffaflaştırılır
  ve önbelleğe alınır (`leke_kutuphane.gd`).
- Lekeler `MeshInstance3D` + `material_override`; `meta "leke"=true` ile işaretlenir,
  ışın atmada ve toplu silmede bu işaret kullanılır.

## Dosyalar

```
addons/backrooms_lekeleyici/
├── plugin.cfg
├── lekeleyici.gd          # EditorPlugin: toolbar, dock, 3B fırça, yerleştirme/silme, undo
├── scripts/
│   ├── leke_panel.gd      # Sağ panel (tüm gelişmiş ayarlar)
│   ├── leke_kutuphane.gd  # Doku tarama + alfa üretimi + önizleme
│   └── leke_isin.gd       # Kameradan mesh'e ışın (raycast)
├── icons/leke_icon.svg
└── textures/stains/       # 17 leke PNG (leke_01..leke_17)
```

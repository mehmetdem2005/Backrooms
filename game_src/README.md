# Backrooms Premium Mobile V3 Fixed

Godot 4.6.3 Mobile renderer hedefli premium telefon Backrooms prototipi.

V3 düzeltmeleri:
- Debugger spam riski oluşturan runtime renderer setting satırları sadeleştirildi.
- Environment/ReflectionProbe gibi sürüme göre değişebilen property atamaları güvenli hale getirildi.
- Signal bağlantıları Callable formatına çevrildi.
- Dictionary içinden typed Vector3/float alma hataları kaldırıldı.
- BFS/pathfinding tarafında Variant döndüren pop_front yerine güvenli index/remove_at kullanıldı.
- Canavar görselinde riskli SphereMesh height ataması kaldırıldı.
- Custom class tip bağımlılığı azaltıldı; bir script hatası diğerlerini zincirleme bozmasın.

Kontroller:
- PC: WASD, Mouse, Shift, F
- Mobil: Sol joystick, sağ ekran bakış, KOŞ, FENER

Ana sahne: scenes/Main.tscn

@tool
class_name YerlestirmeAyari
extends Resource
## Bir parçanın yerleştirme ayarları — Inspector'da düzenlenir.

@export var olcek: float = 1.0            # ölçek (1 = normal)
@export_range(-180.0, 180.0, 1.0) var donme_y: float = 0.0   # Y ekseninde döndürme (derece)
@export var yukseklik: float = 0.0        # yerleştirme yüksekliği (Y)
@export var izgara: float = 4.0           # ızgara adımı (snap)
@export var kalinlik: float = 0.2         # parça kalınlığı (zemin: yükseklik, duvar: derinlik)

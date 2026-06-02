extends Area3D
class_name BatteryPickup

# Basit pil bataryası: oyuncu üstünden geçince fener şarjı verir ve kaybolur.
var hud
var _amount: float = 0.35
var _bob: float = 0.0
var _mesh: MeshInstance3D

func _ready() -> void:
    collision_layer = 0
    collision_mask = 0xFFFFF     # tüm katmanlar; gerçek filtre _on_body_entered'da (add_flashlight_battery)
    monitoring = true
    var col: CollisionShape3D = CollisionShape3D.new()
    var shape: SphereShape3D = SphereShape3D.new()
    shape.radius = 0.8
    col.shape = shape
    add_child(col)

    _mesh = MeshInstance3D.new()
    var bm: BoxMesh = BoxMesh.new()
    bm.size = Vector3(0.11, 0.27, 0.11)
    _mesh.mesh = bm
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = Color(0.10, 0.55, 0.28, 1.0)
    m.emission_enabled = true
    m.emission = Color(0.25, 1.0, 0.55, 1.0)
    m.emission_energy_multiplier = 2.6
    _mesh.material_override = m
    _mesh.position = Vector3(0.0, 0.3, 0.0)
    add_child(_mesh)

    var l: OmniLight3D = OmniLight3D.new()
    l.light_color = Color(0.4, 1.0, 0.6, 1.0)
    l.light_energy = 0.7
    l.omni_range = 2.4
    l.shadow_enabled = false
    l.position = Vector3(0.0, 0.4, 0.0)
    add_child(l)

    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    _bob += delta
    if _mesh != null:
        _mesh.position.y = 0.3 + sin(_bob * 2.2) * 0.06
        _mesh.rotation.y += delta * 1.6

func _on_body_entered(body: Node3D) -> void:
    if body.has_method("add_flashlight_battery"):
        body.add_flashlight_battery(_amount)
        if hud != null and hud.has_method("set_hint"):
            hud.set_hint("Pil buldun  •  fener şarj edildi (+%d%%)" % int(_amount * 100.0))
        queue_free()

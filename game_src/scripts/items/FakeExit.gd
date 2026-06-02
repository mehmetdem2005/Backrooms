extends Node3D
class_name FakeExit

# Sahte çıkış: çıkış gibi parlayan yeşil EXIT tabelası. Yaklaşınca tuzak:
# ışıklar kararır, tabela kırmızıya döner, HUD uyarısı. Bir süre sonra resetlenir.
var hud
var light_manager
var _sign_mat: StandardMaterial3D
var _light: OmniLight3D
var _triggered: bool = false
var _reset_timer: float = 0.0

func _ready() -> void:
    var panel: MeshInstance3D = MeshInstance3D.new()
    var bm: BoxMesh = BoxMesh.new()
    bm.size = Vector3(0.92, 0.34, 0.06)
    panel.mesh = bm
    _sign_mat = StandardMaterial3D.new()
    _sign_mat.albedo_color = Color(0.10, 0.7, 0.35, 1.0)
    _sign_mat.emission_enabled = true
    _sign_mat.emission = Color(0.15, 1.0, 0.45, 1.0)
    _sign_mat.emission_energy_multiplier = 3.4
    panel.material_override = _sign_mat
    add_child(panel)

    _light = OmniLight3D.new()
    _light.light_color = Color(0.3, 1.0, 0.5, 1.0)
    _light.light_energy = 1.4
    _light.omni_range = 4.5
    _light.shadow_enabled = false
    _light.position = Vector3(0.0, 0.0, 0.35)
    add_child(_light)

    var area: Area3D = Area3D.new()
    area.collision_layer = 0
    area.collision_mask = 0xFFFFF
    area.monitoring = true
    var col: CollisionShape3D = CollisionShape3D.new()
    var sh: SphereShape3D = SphereShape3D.new()
    sh.radius = 2.8
    col.shape = sh
    area.add_child(col)
    add_child(area)
    area.body_entered.connect(_on_enter)

func _process(delta: float) -> void:
    if _triggered:
        _reset_timer -= delta
        if _reset_timer <= 0.0:
            _restore()

func _on_enter(body: Node3D) -> void:
    if _triggered or not body.has_method("add_flashlight_battery"):
        return
    _triggered = true
    _reset_timer = 8.0
    _sign_mat.emission = Color(1.0, 0.10, 0.05, 1.0)
    _sign_mat.emission_energy_multiplier = 1.2
    _light.light_color = Color(1.0, 0.2, 0.1, 1.0)
    _light.light_energy = 0.7
    if light_manager != null and light_manager.has_method("trigger_blackout"):
        light_manager.trigger_blackout(1.1)
    if hud != null and hud.has_method("set_hint"):
        hud.set_hint("ÇIKIŞ… değil. Burası seni kandırıyor.")

func _restore() -> void:
    _triggered = false
    _sign_mat.emission = Color(0.15, 1.0, 0.45, 1.0)
    _sign_mat.emission_energy_multiplier = 3.4
    _light.light_color = Color(0.3, 1.0, 0.5, 1.0)
    _light.light_energy = 1.4

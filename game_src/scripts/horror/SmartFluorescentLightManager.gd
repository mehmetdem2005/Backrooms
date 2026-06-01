extends Node
class_name SmartFluorescentLightManager

@export var max_active_lights: int = 8
@export var enable_near_shadows: bool = true

var player: Node3D
var fixture_positions: Array[Vector3] = []

var _lights: Array[OmniLight3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0
var _disturbance_position: Vector3 = Vector3.ZERO
var _disturbance_timer: float = 0.0
var _disturbance_strength: float = 0.0
var _blackout_timer: float = 0.0
var _active_positions: Array[Vector3] = []
var _select_timer: float = 0.0

func _ready() -> void:
    _rng.seed = 890133
    max_active_lights = clamp(max_active_lights, 1, 8)
    _create_light_pool()

func _process(delta: float) -> void:
    _time += delta
    _disturbance_timer = max(0.0, _disturbance_timer - delta)
    _blackout_timer = max(0.0, _blackout_timer - delta)
    _select_timer -= delta
    if player == null or fixture_positions.size() == 0:
        return
    # En yakın fikstürleri her karede DEĞİL, periyodik seç (oyuncu hızlı hareket etmez).
    # Eski kod her karede tüm listeyi script-callable ile sıralıyordu → mobilde ana darboğaz.
    if _select_timer <= 0.0:
        _select_timer = 0.25
        _select_nearest_fixtures()
    _update_light_visuals()

func trigger_disturbance(world_position: Vector3, duration: float = 2.6, strength: float = 1.0) -> void:
    _disturbance_position = world_position
    _disturbance_timer = max(_disturbance_timer, duration)
    _disturbance_strength = clamp(strength, 0.0, 2.0)

func trigger_blackout(duration: float = 0.65) -> void:
    _blackout_timer = max(_blackout_timer, duration)

func _create_light_pool() -> void:
    for index: int in range(max_active_lights):
        var light: OmniLight3D = OmniLight3D.new()
        light.name = "PooledFluorescentLight_%02d" % index
        # Hastalıklı floresan beyazı (hafif sarımsı-soğuk), backrooms uğultusu hissi
        light.light_color = Color(1.0, 0.96, 0.80, 1.0)
        light.light_energy = 1.9
        light.omni_range = 7.4
        light.omni_attenuation = 1.35
        light.shadow_enabled = enable_near_shadows and index < 2
        light.shadow_bias = 0.055
        light.visible = false
        _lights.append(light)
        add_child(light)

func _select_nearest_fixtures() -> void:
    # Callable'sız, O(n*K) en yakın K fikstür seçimi (K = ışık sayısı, ~8).
    var pp: Vector3 = player.global_position
    var count: int = _lights.size()
    _active_positions.clear()
    var used: Dictionary = {}
    for _slot: int in range(count):
        var best_index: int = -1
        var best_distance: float = INF
        for i: int in range(fixture_positions.size()):
            if used.has(i):
                continue
            var d: float = pp.distance_squared_to(fixture_positions[i])
            if d < best_distance:
                best_distance = d
                best_index = i
        if best_index == -1:
            break
        used[best_index] = true
        _active_positions.append(fixture_positions[best_index])
    # seçilen ışıkların konumlarını sabitle
    for index: int in range(_lights.size()):
        if index < _active_positions.size():
            _lights[index].global_position = _active_positions[index] + Vector3(0.0, -0.22, 0.0)

func _update_light_visuals() -> void:
    for index: int in range(_lights.size()):
        var light: OmniLight3D = _lights[index]
        if index >= _active_positions.size():
            light.visible = false
            continue
        var light_position: Vector3 = _active_positions[index]
        var distance_squared: float = player.global_position.distance_squared_to(light_position)
        light.visible = distance_squared < 1150.0
        if not light.visible:
            continue
        var phase: float = float(index) * 2.17 + _time * (4.0 + float(index % 3))
        # Lamba "sağlığı" konuma bağlı sabit → belirli tavan lambaları sürekli vızıldar/arızalıdır
        var health: float = abs(sin(light_position.x * 12.9898 + light_position.z * 78.233))
        var failing: bool = health > 0.80
        var flicker: float = 0.86 + sin(phase) * 0.06
        if failing:
            # arızalı tüp: hızlı vızıltı + ara ara tamamen sönme
            flicker *= 0.55 + abs(sin(_time * 26.0 + health * 30.0)) * 0.5
            if int(_time * 11.0 + health * 50.0) % 17 == 0:
                flicker *= 0.12
        elif int(_time * 9.0 + float(index * 7)) % 41 == 0:
            flicker *= 0.5
        if _disturbance_timer > 0.0:
            var disturbance_distance: float = light_position.distance_to(_disturbance_position)
            var disturbance: float = clamp(1.0 - disturbance_distance / 18.0, 0.0, 1.0) * _disturbance_strength
            flicker *= lerp(1.0, 0.12 + abs(sin(_time * 24.0 + float(index))) * 0.80, disturbance)
        if _blackout_timer > 0.0:
            flicker *= 0.08 + abs(sin(_time * 40.0)) * 0.12
        light.light_energy = 2.05 * flicker
        # parlakken hafif soğuk-beyaz, kısıkken sarıya kayan floresan rengi
        light.light_color = Color(1.0, 0.93, 0.74, 1.0).lerp(Color(1.0, 0.98, 0.86, 1.0), clamp(flicker, 0.0, 1.0))
        light.omni_range = 7.2 + sin(phase * 0.37) * 0.4
        light.shadow_enabled = enable_near_shadows and index < 2

# Verilen konumdaki floresan aydınlatma seviyesi (0..1). Karanlık mekaniği için kullanılır.
func get_illumination(world_position: Vector3) -> float:
    var best: float = 0.0
    for light: OmniLight3D in _lights:
        if not light.visible:
            continue
        var d: float = light.global_position.distance_to(world_position)
        var falloff: float = clamp(1.0 - d / max(0.1, light.omni_range), 0.0, 1.0)
        var contribution: float = falloff * clamp(light.light_energy / 1.8, 0.0, 1.0)
        best = max(best, contribution)
    return clamp(best, 0.0, 1.0)

extends Node3D
class_name DustVolume

var player: Node3D
var _particles: GPUParticles3D

func _ready() -> void:
    _build_particles()

func _process(_delta: float) -> void:
    if player != null:
        global_position = player.global_position + Vector3(0.0, 1.4, 0.0)

func _build_particles() -> void:
    _particles = GPUParticles3D.new()
    _particles.name = "FloatingDustParticles"
    _particles.amount = 240
    _particles.lifetime = 9.0
    _particles.preprocess = 8.0
    _particles.local_coords = true
    _particles.visibility_aabb = AABB(Vector3(-18.0, -3.0, -18.0), Vector3(36.0, 7.0, 36.0))

    var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    material.emission_box_extents = Vector3(14.0, 2.6, 14.0)
    material.gravity = Vector3(0.0, -0.005, 0.0)
    material.initial_velocity_min = 0.015
    material.initial_velocity_max = 0.055
    material.angular_velocity_min = -0.15
    material.angular_velocity_max = 0.15
    material.scale_min = 0.018
    material.scale_max = 0.055
    material.color = Color(1.0, 0.87, 0.52, 0.18)
    _particles.process_material = material

    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2(0.028, 0.028)
    _particles.draw_pass_1 = quad
    add_child(_particles)

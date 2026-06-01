extends Node3D
class_name ChunkStreamer

# Yalnızca oyuncuya yakın chunk'ları görünür + çarpışır tutar; uzaktakileri kapatır.
# Tüm geometri tek seferde kurulur (oynarken kurma takılması olmaz), sonra mesafeye göre kültür edilir.

var player: Node3D
var entity: Node3D = null
var chunks: Array[Node3D] = []
var view_distance: float = 80.0
var entity_distance: float = 48.0

var _accumulator: float = 0.0
var _interval: float = 0.2

func setup(target_player: Node3D, chunk_list: Array[Node3D], distance: float) -> void:
    player = target_player
    chunks = chunk_list
    view_distance = distance
    _apply_culling()

func set_entity(target_entity: Node3D, collision_distance: float) -> void:
    # Canavarı çarpışma yayınına dahil eder: altındaki/etrafındaki chunk'lar çarpışır kalır.
    entity = target_entity
    entity_distance = collision_distance
    _apply_culling()

func _process(delta: float) -> void:
    if player == null or chunks.is_empty():
        return
    _accumulator += delta
    if _accumulator < _interval:
        return
    _accumulator = 0.0
    _apply_culling()

func _apply_culling() -> void:
    var player_position: Vector3 = player.global_position
    var has_entity: bool = entity != null and is_instance_valid(entity)
    var entity_position: Vector3 = entity.global_position if has_entity else Vector3.ZERO
    for chunk: Node3D in chunks:
        if chunk == null:
            continue
        var center: Vector3 = chunk.get_meta("center", Vector3.ZERO)
        var cull_radius: float = float(chunk.get_meta("cull_radius", 0.0))
        # GÖRÜNÜRLÜK: yalnızca oyuncuya yakınsa çizilir
        var view_threshold: float = view_distance + cull_radius
        var is_visible: bool = player_position.distance_squared_to(center) <= view_threshold * view_threshold
        if chunk.visible != is_visible:
            chunk.visible = is_visible
        # ÇARPIŞMA: oyuncuya VEYA canavara yakın chunk'larda açık (ikisi de zeminden düşmez),
        # uzaktakiler fizik dışı → performans korunur.
        var should_collide: bool = is_visible
        if not should_collide and has_entity:
            var entity_threshold: float = entity_distance + cull_radius
            should_collide = entity_position.distance_squared_to(center) <= entity_threshold * entity_threshold
        var body: Node = chunk.get_node_or_null("ChunkCollision")
        if body != null and body is StaticBody3D:
            var static_body: StaticBody3D = body as StaticBody3D
            var target_layer: int = 1 if should_collide else 0
            if static_body.collision_layer != target_layer:
                static_body.collision_layer = target_layer

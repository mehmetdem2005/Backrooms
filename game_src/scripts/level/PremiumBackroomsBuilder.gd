extends Node3D
class_name PremiumBackroomsBuilder

@export var world_seed: int = 463063
@export var grid_width: int = 35
@export var grid_height: int = 35
@export var cell_size: float = 4.0
@export var wall_height: float = 3.05
@export var ceiling_height: float = 3.02
@export var room_count: int = 15
@export var detail_density: float = 1.0
@export var chunk_size: int = 12

var start_cell: Vector2i = Vector2i(1, 1)
var exit_cell: Vector2i = Vector2i(1, 1)
var enemy_cell: Vector2i = Vector2i(1, 1)
var start_world_position: Vector3 = Vector3.ZERO
var exit_world_position: Vector3 = Vector3.ZERO
var enemy_world_position: Vector3 = Vector3.ZERO
var fixture_positions: Array[Vector3] = []
var chunks: Array[Node3D] = []
var exit_area: Area3D

var _grid: Array[PackedByteArray] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _box_mesh_shared: BoxMesh
var _cylinder_mesh_shared: CylinderMesh
var _wall_material: Material
var _floor_material: Material
var _ceiling_material: Material
var _trim_material: Material
var _stain_material: Material
var _wire_material: Material
var _vent_material: Material
var _exit_material: Material
var _emissive_material: Material
var _dark_material: Material
var _warning_material: Material
var _mold_material: Material
var _metal_material: Material
var _concrete_material: Material
var _ceiling_grid_material: Material
var _paper_material: Material
var event_positions: Array[Vector3] = []
var hiding_spot_positions: Array[Vector3] = []
var dead_end_cells: Array[Vector2i] = []
var _open_cells: Array[Vector2i] = []

func generate() -> void:
    _rng.seed = world_seed
    grid_width = _force_odd(max(grid_width, 11))
    grid_height = _force_odd(max(grid_height, 11))
    _create_materials()
    _build_grid()
    _generate_open_backrooms()
    _pick_special_cells()
    _collect_tactical_cells()
    _build_geometry()
    _build_exit_area()

func _generate_open_backrooms() -> void:
    # 1) Tüm iç alanı aç (geniş, açık "backrooms" hissi). Kenarlar duvar kalır.
    for y_index: int in range(1, grid_height - 1):
        for x_index: int in range(1, grid_width - 1):
            _set_cell(Vector2i(x_index, y_index), 0)

    start_cell = Vector2i(2, 2)

    # 2) Bölme duvarları (kapı boşluklu) → düzensiz odalar ve geniş koridorlar
    var partition_count: int = int(float(grid_width * grid_height) / 50.0)
    for _i: int in range(partition_count):
        _add_partition()

    # 3) Büyük açık holler → görkemli geniş backrooms alanları (içlerine kolon ızgarası gelir)
    var hall_count: int = _rng.randi_range(3, 5)
    for _h: int in range(hall_count):
        _carve_hall()

    # 4) Dağınık dolu bloklar / kolon kümeleri (kapanma + örtü)
    var block_count: int = int(float(grid_width * grid_height) / 85.0)
    for _b: int in range(block_count):
        _add_block()

    # 4) Başlangıç çevresini garanti aç
    _open_region(start_cell, 2)

    # 5) Bağlantı garantisi: başlangıçtan erişilemeyen açık hücreleri doldur
    _enforce_connectivity()

func _carve_hall() -> void:
    var hw: int = _rng.randi_range(6, 12)
    var hh: int = _rng.randi_range(5, 9)
    var hx: int = _rng.randi_range(2, max(2, grid_width - 2 - hw))
    var hy: int = _rng.randi_range(2, max(2, grid_height - 2 - hh))
    for dy: int in range(hh):
        for dx: int in range(hw):
            _set_cell(Vector2i(hx + dx, hy + dy), 0)

func _add_partition() -> void:
    var horizontal: bool = _rng.randf() < 0.5
    var span: int = _rng.randi_range(5, 16)
    var gaps: int = _rng.randi_range(1, 3)
    if horizontal:
        var py: int = _rng.randi_range(3, grid_height - 4)
        var px: int = _rng.randi_range(1, max(1, grid_width - 2 - span))
        var gap_set: Dictionary = {}
        for _g: int in range(gaps):
            gap_set[_rng.randi_range(0, span)] = true
        for offset: int in range(span):
            if gap_set.has(offset):
                continue
            _set_cell(Vector2i(px + offset, py), 1)
    else:
        var qx: int = _rng.randi_range(3, grid_width - 4)
        var qy: int = _rng.randi_range(1, max(1, grid_height - 2 - span))
        var gap_set2: Dictionary = {}
        for _g2: int in range(gaps):
            gap_set2[_rng.randi_range(0, span)] = true
        for offset2: int in range(span):
            if gap_set2.has(offset2):
                continue
            _set_cell(Vector2i(qx, qy + offset2), 1)

func _add_block() -> void:
    var bw: int = _rng.randi_range(1, 3)
    var bh: int = _rng.randi_range(1, 2)
    var bx: int = _rng.randi_range(2, max(2, grid_width - 2 - bw))
    var by: int = _rng.randi_range(2, max(2, grid_height - 2 - bh))
    for dy: int in range(bh):
        for dx: int in range(bw):
            var cell: Vector2i = Vector2i(bx + dx, by + dy)
            if Vector2(cell).distance_to(Vector2(start_cell)) < 4.0:
                continue
            _set_cell(cell, 1)

func _open_region(center: Vector2i, radius: int) -> void:
    for dy: int in range(-radius, radius + 1):
        for dx: int in range(-radius, radius + 1):
            var cell: Vector2i = Vector2i(center.x + dx, center.y + dy)
            if cell.x >= 1 and cell.y >= 1 and cell.x < grid_width - 1 and cell.y < grid_height - 1:
                _set_cell(cell, 0)

func _enforce_connectivity() -> void:
    var reachable: Dictionary = _bfs_distances(start_cell)
    for y_index: int in range(grid_height):
        for x_index: int in range(grid_width):
            var cell: Vector2i = Vector2i(x_index, y_index)
            if is_open_cell(cell) and not reachable.has(cell):
                _set_cell(cell, 1)

func is_open_cell(cell: Vector2i) -> bool:
    if cell.x < 0 or cell.y < 0 or cell.x >= grid_width or cell.y >= grid_height:
        return false
    return _get_cell(cell) == 0

func world_to_grid(world_position: Vector3) -> Vector2i:
    var x_value: int = int(round(world_position.x / cell_size + float(grid_width - 1) * 0.5))
    var y_value: int = int(round(world_position.z / cell_size + float(grid_height - 1) * 0.5))
    return Vector2i(clamp(x_value, 0, grid_width - 1), clamp(y_value, 0, grid_height - 1))

func grid_to_world(cell: Vector2i, y_height: float = 0.0) -> Vector3:
    var x_pos: float = (float(cell.x) - float(grid_width - 1) * 0.5) * cell_size
    var z_pos: float = (float(cell.y) - float(grid_height - 1) * 0.5) * cell_size
    return Vector3(x_pos, y_height, z_pos)

func get_open_neighbors(cell: Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    for direction: Vector2i in directions:
        var next_cell: Vector2i = cell + direction
        if is_open_cell(next_cell):
            result.append(next_cell)
    return result

func get_grid_path(start: Vector2i, goal: Vector2i, max_steps: int = 2200) -> Array[Vector2i]:
    var path: Array[Vector2i] = []
    if not is_open_cell(start):
        return path
    if not is_open_cell(goal):
        goal = _nearest_open_cell(goal)
        if goal.x < 0:
            return path
    if start == goal:
        return path

    var frontier: Array[Vector2i] = [start]
    var head: int = 0
    var came_from: Dictionary = {}
    came_from[start] = start
    var steps: int = 0

    # Kuyruk için indeks işaretçisi (remove_at(0) O(n) idi → açık haritada O(n^2) lag yapıyordu)
    while head < frontier.size() and steps < max_steps:
        steps += 1
        var current: Vector2i = frontier[head]
        head += 1
        if current == goal:
            break
        for next_cell: Vector2i in get_open_neighbors(current):
            if not came_from.has(next_cell):
                came_from[next_cell] = current
                frontier.append(next_cell)

    if not came_from.has(goal):
        return path

    var trace: Vector2i = goal
    while trace != start:
        path.push_front(trace)
        trace = Vector2i(came_from[trace])
    return path

func _nearest_open_cell(cell: Vector2i) -> Vector2i:
    if is_open_cell(cell):
        return cell
    for radius: int in range(1, 6):
        for dy: int in range(-radius, radius + 1):
            for dx: int in range(-radius, radius + 1):
                var candidate: Vector2i = Vector2i(cell.x + dx, cell.y + dy)
                if is_open_cell(candidate):
                    return candidate
    return Vector2i(-1, -1)

func _force_odd(value: int) -> int:
    if value % 2 == 0:
        return value + 1
    return value

func _build_grid() -> void:
    _grid.clear()
    for y_index: int in range(grid_height):
        var row: PackedByteArray = PackedByteArray()
        row.resize(grid_width)
        for x_index: int in range(grid_width):
            row[x_index] = 1
        _grid.append(row)

func _get_cell(cell: Vector2i) -> int:
    var row: PackedByteArray = _grid[cell.y]
    return int(row[cell.x])

func _set_cell(cell: Vector2i, value: int) -> void:
    if cell.x < 0 or cell.y < 0 or cell.x >= grid_width or cell.y >= grid_height:
        return
    var row: PackedByteArray = _grid[cell.y]
    row[cell.x] = value
    _grid[cell.y] = row

func _pick_special_cells() -> void:
    # Başlangıçtan BFS ile gerçek (koridor) mesafeleri hesapla → çıkış garanti ulaşılabilir olur.
    var dist_from_start: Dictionary = _bfs_distances(start_cell)

    var farthest: Vector2i = start_cell
    var farthest_distance: int = -1
    for key: Vector2i in dist_from_start:
        var d: int = int(dist_from_start[key])
        if d > farthest_distance:
            farthest_distance = d
            farthest = key
    exit_cell = farthest

    # Düşman: hem başlangıca hem çıkışa koridor mesafesi yüksek bir orta nokta (ikisinin de min'i maks).
    var dist_from_exit: Dictionary = _bfs_distances(exit_cell)
    var best_score: int = -1
    var enemy_candidate: Vector2i = exit_cell
    for key: Vector2i in dist_from_start:
        if not dist_from_exit.has(key):
            continue
        var score: int = min(int(dist_from_start[key]), int(dist_from_exit[key]))
        if score > best_score:
            best_score = score
            enemy_candidate = key
    enemy_cell = enemy_candidate

    start_world_position = grid_to_world(start_cell, 0.0)
    exit_world_position = grid_to_world(exit_cell, 0.0)
    enemy_world_position = grid_to_world(enemy_cell, 0.0)

func _bfs_distances(origin: Vector2i) -> Dictionary:
    var distances: Dictionary = {}
    if not is_open_cell(origin):
        return distances
    var frontier: Array[Vector2i] = [origin]
    distances[origin] = 0
    var head: int = 0
    while head < frontier.size():
        var current: Vector2i = frontier[head]
        head += 1
        var current_distance: int = int(distances[current])
        for neighbor: Vector2i in get_open_neighbors(current):
            if not distances.has(neighbor):
                distances[neighbor] = current_distance + 1
                frontier.append(neighbor)
    return distances


func _cell_distance_squared(a: Vector2i, b: Vector2i) -> float:
    var dx: int = a.x - b.x
    var dy: int = a.y - b.y
    return float(dx * dx + dy * dy)


func get_open_cells() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for cell: Vector2i in _open_cells:
        result.append(cell)
    return result

func get_random_open_cell_far_from(reference_cell: Vector2i, minimum_distance_squared: float, random: RandomNumberGenerator) -> Vector2i:
    var candidates: Array[Vector2i] = []
    for cell: Vector2i in _open_cells:
        if _cell_distance_squared(cell, reference_cell) >= minimum_distance_squared:
            candidates.append(cell)
    if candidates.size() == 0:
        return reference_cell
    return candidates[random.randi_range(0, candidates.size() - 1)]

func get_random_open_cell_near(reference_cell: Vector2i, min_distance: int, max_distance: int, random: RandomNumberGenerator) -> Vector2i:
    var candidates: Array[Vector2i] = []
    var min_sq: float = float(min_distance * min_distance)
    var max_sq: float = float(max_distance * max_distance)
    for cell: Vector2i in _open_cells:
        var distance_sq: float = _cell_distance_squared(cell, reference_cell)
        if distance_sq >= min_sq and distance_sq <= max_sq:
            candidates.append(cell)
    if candidates.size() == 0:
        return reference_cell
    return candidates[random.randi_range(0, candidates.size() - 1)]

func get_ambush_cell_around(target_cell: Vector2i, random: RandomNumberGenerator) -> Vector2i:
    # Tek O(n) tarama; eskiden her aday için yol bulma yapılıyordu (yaklaşırken lag yapıyordu).
    var candidate: Vector2i = get_random_open_cell_near(target_cell, 4, 11, random)
    if candidate == target_cell:
        return get_random_open_cell_near(target_cell, 2, 8, random)
    return candidate

func has_grid_line_of_sight(start: Vector2i, goal: Vector2i, max_cells: int = 14) -> bool:
    if not is_open_cell(start) or not is_open_cell(goal):
        return false
    var delta: Vector2i = goal - start
    var steps: int = max(abs(delta.x), abs(delta.y))
    if steps > max_cells:
        return false
    if steps <= 0:
        return true
    for step: int in range(1, steps + 1):
        var t: float = float(step) / float(steps)
        var cell: Vector2i = Vector2i(int(round(lerp(float(start.x), float(goal.x), t))), int(round(lerp(float(start.y), float(goal.y), t))))
        if not is_open_cell(cell):
            return false
    return true

func _collect_tactical_cells() -> void:
    _open_cells.clear()
    dead_end_cells.clear()
    event_positions.clear()
    hiding_spot_positions.clear()
    for y_index: int in range(grid_height):
        for x_index: int in range(grid_width):
            var cell: Vector2i = Vector2i(x_index, y_index)
            if is_open_cell(cell):
                _open_cells.append(cell)
                var neighbors: Array[Vector2i] = get_open_neighbors(cell)
                if neighbors.size() <= 1 and cell != start_cell and cell != exit_cell:
                    dead_end_cells.append(cell)
                    event_positions.append(grid_to_world(cell, 1.1))
                if neighbors.size() >= 3 and _should_place_hiding_spot(cell):
                    hiding_spot_positions.append(grid_to_world(cell, 0.0))

func _should_place_hiding_spot(cell: Vector2i) -> bool:
    var hash_value: int = abs(cell.x * 15485863 ^ cell.y * 32452843 ^ world_seed)
    return hash_value % 11 == 0

func _build_geometry() -> void:
    fixture_positions.clear()
    chunks.clear()
    # Hücreler chunk'lara göre kovalanır; her chunk kendi multimesh + çarpışma gövdesini alır.
    var buckets: Dictionary = {}

    for y_index: int in range(grid_height):
        for x_index: int in range(grid_width):
            var cell: Vector2i = Vector2i(x_index, y_index)
            var center: Vector3 = grid_to_world(cell, 0.0)
            var bucket: Dictionary = _get_bucket(buckets, cell)
            if is_open_cell(cell):
                _bpush(bucket, "floor", _scaled_transform(Vector3(cell_size, 0.10, cell_size), center + Vector3(0.0, -0.055, 0.0)))
                _bpush(bucket, "ceiling", _scaled_transform(Vector3(cell_size, 0.12, cell_size), center + Vector3(0.0, ceiling_height, 0.0)))
                var grid_y: float = ceiling_height - 0.07
                _bpush(bucket, "grid", _scaled_transform(Vector3(cell_size, 0.05, 0.07), center + Vector3(0.0, grid_y, 0.0)))
                _bpush(bucket, "grid", _scaled_transform(Vector3(0.07, 0.05, cell_size), center + Vector3(0.0, grid_y, 0.0)))
                var trim_tmp: Array[Transform3D] = []
                _append_trims_for_cell(cell, center, trim_tmp)
                for trim_xform: Transform3D in trim_tmp:
                    _bpush(bucket, "trim", trim_xform)
                if _should_place_fixture(cell):
                    var fixture_pos: Vector3 = center + Vector3(0.0, ceiling_height - 0.075, 0.0)
                    fixture_positions.append(fixture_pos)
                    # Gerçekçi gömme floresan (troffer): geniş metal kasa + İKİ parlak tüp
                    _bpush(bucket, "housing", _scaled_transform(Vector3(cell_size * 0.76, 0.14, 0.64), fixture_pos + Vector3(0.0, 0.05, 0.0)))
                    _bpush(bucket, "fixture", _scaled_transform(Vector3(cell_size * 0.60, 0.05, 0.13), fixture_pos + Vector3(0.0, 0.0, -0.135)))
                    _bpush(bucket, "fixture", _scaled_transform(Vector3(cell_size * 0.60, 0.05, 0.13), fixture_pos + Vector3(0.0, 0.0, 0.135)))
                if _should_place_stain(cell):
                    var stain_scale: float = _rng.randf_range(0.35, 0.92)
                    var stain_position: Vector3 = center + Vector3(_rng.randf_range(-1.0, 1.0), 0.012, _rng.randf_range(-1.0, 1.0))
                    _bpush(bucket, "stain", _rotated_scaled_transform(Vector3(cell_size * stain_scale, 0.018, cell_size * _rng.randf_range(0.18, 0.44)), stain_position, Vector3.UP, _rng.randf_range(0.0, TAU)))
                if _should_place_vent(cell):
                    _bpush(bucket, "vent", _scaled_transform(Vector3(cell_size * 0.42, 0.055, cell_size * 0.25), center + Vector3(0.0, ceiling_height - 0.13, 0.0)))
                if _should_place_wire(cell):
                    var wire_pos: Vector3 = center + Vector3(0.0, ceiling_height - 0.24, 0.0)
                    if is_open_cell(cell + Vector2i(1, 0)) and is_open_cell(cell + Vector2i(-1, 0)):
                        _bpush(bucket, "wire_x", _cylinder_x_transform(cell_size, 0.024, wire_pos))
                    elif is_open_cell(cell + Vector2i(0, 1)) and is_open_cell(cell + Vector2i(0, -1)):
                        _bpush(bucket, "wire_z", _cylinder_z_transform(cell_size, 0.024, wire_pos))
                if _should_place_column(cell):
                    var column_offset: Vector3 = Vector3(cell_size * 0.30, wall_height * 0.5, cell_size * 0.30)
                    _bpush(bucket, "column", _scaled_transform(Vector3(0.55, wall_height, 0.55), center + column_offset))
                if _should_place_sign(cell):
                    var sign_dir: Vector2i = _wall_neighbor_dir(cell)
                    if sign_dir != Vector2i.ZERO:
                        var sign_y: float = _rng.randf_range(1.45, 1.95)
                        var wall_off: float = cell_size * 0.5 - 0.06
                        if sign_dir.x != 0:
                            _bpush(bucket, "sign", _scaled_transform(Vector3(0.05, 0.40, 0.74), center + Vector3(float(sign_dir.x) * wall_off, sign_y, _rng.randf_range(-0.6, 0.6))))
                        else:
                            _bpush(bucket, "sign", _scaled_transform(Vector3(0.74, 0.40, 0.05), center + Vector3(_rng.randf_range(-0.6, 0.6), sign_y, float(sign_dir.y) * wall_off)))
                        event_positions.append(center + Vector3(0.0, 1.05, 0.0))
                if _should_place_paper(cell):
                    _bpush(bucket, "paper", _rotated_scaled_transform(Vector3(0.36, 0.012, 0.48), center + Vector3(_rng.randf_range(-1.2, 1.2), 0.018, _rng.randf_range(-1.2, 1.2)), Vector3.UP, _rng.randf_range(0.0, TAU)))
                if _should_place_mold(cell):
                    _bpush(bucket, "mold", _rotated_scaled_transform(Vector3(cell_size * _rng.randf_range(0.25, 0.62), 0.024, cell_size * _rng.randf_range(0.18, 0.48)), center + Vector3(_rng.randf_range(-1.4, 1.4), 0.018, _rng.randf_range(-1.4, 1.4)), Vector3.UP, _rng.randf_range(0.0, TAU)))
                if _should_place_pipe(cell):
                    var pipe_pos: Vector3 = center + Vector3(0.0, ceiling_height - 0.34, 0.0)
                    if is_open_cell(cell + Vector2i(1, 0)) and is_open_cell(cell + Vector2i(-1, 0)):
                        _bpush(bucket, "pipe_x", _cylinder_x_transform(cell_size, 0.055, pipe_pos))
                    elif is_open_cell(cell + Vector2i(0, 1)) and is_open_cell(cell + Vector2i(0, -1)):
                        _bpush(bucket, "pipe_z", _cylinder_z_transform(cell_size, 0.055, pipe_pos))
                if _should_place_ceiling_gap(cell):
                    _bpush(bucket, "gap", _scaled_transform(Vector3(cell_size * 0.52, 0.035, cell_size * 0.36), center + Vector3(0.0, ceiling_height - 0.18, 0.0)))
            else:
                _bpush(bucket, "wall", _scaled_transform(Vector3(cell_size, wall_height, cell_size), center + Vector3(0.0, wall_height * 0.5, 0.0)))
                if not bucket.has("_walls"):
                    bucket["_walls"] = []
                bucket["_walls"].append(center)

    for key: Vector2i in buckets.keys():
        _build_chunk(key, buckets[key])

func _wall_neighbor_dir(cell: Vector2i) -> Vector2i:
    var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    for direction: Vector2i in directions:
        if not is_open_cell(cell + direction):
            return direction
    return Vector2i.ZERO

func _get_bucket(buckets: Dictionary, cell: Vector2i) -> Dictionary:
    var key: Vector2i = Vector2i(cell.x / chunk_size, cell.y / chunk_size)
    if not buckets.has(key):
        buckets[key] = {}
    return buckets[key]

func _bpush(bucket: Dictionary, type_name: String, xform: Transform3D) -> void:
    if not bucket.has(type_name):
        bucket[type_name] = []
    bucket[type_name].append(xform)

func _chunk_type_info(type_name: String) -> Array:
    match type_name:
        "wall": return [false, _wall_material]
        "floor": return [false, _floor_material]
        "ceiling": return [false, _ceiling_material]
        "trim": return [false, _trim_material]
        "fixture": return [false, _emissive_material]
        "housing": return [false, _metal_material]
        "stain": return [false, _stain_material]
        "vent": return [false, _vent_material]
        "wire_x": return [true, _wire_material]
        "wire_z": return [true, _wire_material]
        "column": return [false, _concrete_material]
        "grid": return [false, _ceiling_grid_material]
        "sign": return [false, _warning_material]
        "paper": return [false, _paper_material]
        "mold": return [false, _mold_material]
        "pipe_x": return [true, _metal_material]
        "pipe_z": return [true, _metal_material]
        "gap": return [false, _dark_material]
    return [false, _wall_material]

func _build_chunk(key: Vector2i, bucket: Dictionary) -> void:
    var chunk: Node3D = Node3D.new()
    chunk.name = "Chunk_%d_%d" % [key.x, key.y]
    add_child(chunk)

    for type_name: String in bucket.keys():
        if type_name == "_walls":
            continue
        var info: Array = _chunk_type_info(type_name)
        var mesh: Mesh = _cylinder_mesh() if bool(info[0]) else _box_mesh()
        _create_chunk_multimesh(chunk, type_name, mesh, bucket[type_name], info[1] as Material)

    # Chunk hücre aralığı → çarpışma gövdesi (zemin kutusu + duvar kutuları)
    var cx0: int = key.x * chunk_size
    var cy0: int = key.y * chunk_size
    var cx1: int = min(cx0 + chunk_size, grid_width)
    var cy1: int = min(cy0 + chunk_size, grid_height)
    var w0: Vector3 = grid_to_world(Vector2i(cx0, cy0), 0.0)
    var w1: Vector3 = grid_to_world(Vector2i(cx1 - 1, cy1 - 1), 0.0)
    var center_world: Vector3 = (w0 + w1) * 0.5
    var span_x: float = float(cx1 - cx0) * cell_size
    var span_z: float = float(cy1 - cy0) * cell_size

    var body: StaticBody3D = StaticBody3D.new()
    body.name = "ChunkCollision"
    chunk.add_child(body)

    var floor_shape: BoxShape3D = BoxShape3D.new()
    floor_shape.size = Vector3(span_x, 0.22, span_z)
    var floor_collision: CollisionShape3D = CollisionShape3D.new()
    floor_collision.shape = floor_shape
    floor_collision.position = center_world + Vector3(0.0, -0.14, 0.0)
    body.add_child(floor_collision)

    if bucket.has("_walls"):
        for wall_center: Vector3 in bucket["_walls"]:
            var wall_shape: BoxShape3D = BoxShape3D.new()
            wall_shape.size = Vector3(cell_size, wall_height, cell_size)
            var wall_collision: CollisionShape3D = CollisionShape3D.new()
            wall_collision.shape = wall_shape
            wall_collision.position = wall_center + Vector3(0.0, wall_height * 0.5, 0.0)
            body.add_child(wall_collision)

    var cull_radius: float = sqrt(span_x * span_x + span_z * span_z) * 0.5 + cell_size
    chunk.set_meta("center", center_world)
    chunk.set_meta("cull_radius", cull_radius)
    chunks.append(chunk)

func _create_chunk_multimesh(parent: Node3D, node_name: String, mesh: Mesh, transforms: Array, material: Material) -> void:
    if transforms.size() == 0:
        return
    var multi_mesh: MultiMesh = MultiMesh.new()
    multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
    multi_mesh.mesh = mesh
    multi_mesh.instance_count = transforms.size()
    for index: int in range(transforms.size()):
        multi_mesh.set_instance_transform(index, transforms[index])
    var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
    instance.name = node_name
    instance.multimesh = multi_mesh
    instance.material_override = material
    parent.add_child(instance)

func _append_trims_for_cell(cell: Vector2i, center: Vector3, output: Array[Transform3D]) -> void:
    var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    for direction: Vector2i in directions:
        var neighbor: Vector2i = cell + direction
        if not is_open_cell(neighbor):
            if direction.x != 0:
                var x_offset: float = float(direction.x) * cell_size * 0.5
                output.append(_scaled_transform(Vector3(0.12, 0.20, cell_size), center + Vector3(x_offset, 0.17, 0.0)))
                output.append(_scaled_transform(Vector3(0.10, 0.16, cell_size), center + Vector3(x_offset, ceiling_height - 0.20, 0.0)))
            else:
                var z_offset: float = float(direction.y) * cell_size * 0.5
                output.append(_scaled_transform(Vector3(cell_size, 0.20, 0.12), center + Vector3(0.0, 0.17, z_offset)))
                output.append(_scaled_transform(Vector3(cell_size, 0.16, 0.10), center + Vector3(0.0, ceiling_height - 0.20, z_offset)))

func _should_place_fixture(cell: Vector2i) -> bool:
    if cell == start_cell or cell == exit_cell:
        return true
    var hash_value: int = abs(cell.x * 73856093 ^ cell.y * 19349663 ^ world_seed)
    return hash_value % 4 == 0

func _should_place_stain(cell: Vector2i) -> bool:
    var hash_value: int = abs(cell.x * 83492791 ^ cell.y * 297121507 ^ world_seed)
    return hash_value % int(max(3.0, 8.0 - detail_density * 3.0)) == 0

func _should_place_vent(cell: Vector2i) -> bool:
    var hash_value: int = abs(cell.x * 1999993 ^ cell.y * 54059 ^ world_seed)
    return hash_value % 17 == 0

func _should_place_wire(cell: Vector2i) -> bool:
    var hash_value: int = abs(cell.x * 104729 ^ cell.y * 13007 ^ world_seed)
    return hash_value % 13 == 0

func _should_place_column(cell: Vector2i) -> bool:
    var hash_value: int = abs(cell.x * 49979687 ^ cell.y * 86028121 ^ world_seed)
    # Yalnızca oda iç hücreleri (dört yanı açık) → koridor ortasında rastgele kolon olmaz
    return get_open_neighbors(cell).size() == 4 and hash_value % 5 == 0

func _should_place_sign(cell: Vector2i) -> bool:
    var hash_value: int = abs(cell.x * 67867967 ^ cell.y * 982451653 ^ world_seed)
    return hash_value % 19 == 0

func _should_place_paper(cell: Vector2i) -> bool:
    var hash_value: int = abs(cell.x * 961748927 ^ cell.y * 982451653 ^ world_seed)
    return hash_value % 9 == 0

func _should_place_mold(cell: Vector2i) -> bool:
    var hash_value: int = abs(cell.x * 32452843 ^ cell.y * 49979687 ^ world_seed)
    return hash_value % 12 == 0

func _should_place_pipe(cell: Vector2i) -> bool:
    var hash_value: int = abs(cell.x * 86028121 ^ cell.y * 104395303 ^ world_seed)
    return hash_value % 10 == 0

func _should_place_ceiling_gap(cell: Vector2i) -> bool:
    var hash_value: int = abs(cell.x * 15485863 ^ cell.y * 67867967 ^ world_seed)
    return hash_value % 14 == 0



func _box_mesh() -> BoxMesh:
    # Tüm chunk'lar TEK paylaşılan box mesh kullanır (her tip için yeni kaynak yaratmaz).
    if _box_mesh_shared == null:
        _box_mesh_shared = BoxMesh.new()
        _box_mesh_shared.size = Vector3.ONE
    return _box_mesh_shared

func _cylinder_mesh() -> CylinderMesh:
    if _cylinder_mesh_shared == null:
        _cylinder_mesh_shared = CylinderMesh.new()
        _cylinder_mesh_shared.top_radius = 1.0
        _cylinder_mesh_shared.bottom_radius = 1.0
        _cylinder_mesh_shared.height = 1.0
        _cylinder_mesh_shared.radial_segments = 8
        _cylinder_mesh_shared.rings = 1
    return _cylinder_mesh_shared

func _scaled_transform(scale_vector: Vector3, origin: Vector3) -> Transform3D:
    var transform_basis: Basis = Basis()
    transform_basis = transform_basis.scaled(scale_vector)
    return Transform3D(transform_basis, origin)

func _rotated_scaled_transform(scale_vector: Vector3, origin: Vector3, axis: Vector3, angle: float) -> Transform3D:
    var transform_basis: Basis = Basis().rotated(axis, angle)
    transform_basis = transform_basis.scaled(scale_vector)
    return Transform3D(transform_basis, origin)

func _cylinder_x_transform(length: float, radius: float, origin: Vector3) -> Transform3D:
    var transform_basis: Basis = Basis().rotated(Vector3.FORWARD, PI * 0.5)
    transform_basis = transform_basis.scaled(Vector3(radius, length, radius))
    return Transform3D(transform_basis, origin)

func _cylinder_z_transform(length: float, radius: float, origin: Vector3) -> Transform3D:
    var transform_basis: Basis = Basis().rotated(Vector3.RIGHT, PI * 0.5)
    transform_basis = transform_basis.scaled(Vector3(radius, length, radius))
    return Transform3D(transform_basis, origin)


func _build_exit_area() -> void:
    exit_area = Area3D.new()
    exit_area.name = "ExitArea"
    exit_area.position = exit_world_position + Vector3(0.0, 1.05, 0.0)
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(cell_size * 0.82, 2.10, cell_size * 0.82)
    var collision: CollisionShape3D = CollisionShape3D.new()
    collision.shape = shape
    exit_area.add_child(collision)
    add_child(exit_area)

    var door: MeshInstance3D = MeshInstance3D.new()
    door.name = "GlowingExitDoor"
    var door_mesh: BoxMesh = BoxMesh.new()
    door_mesh.size = Vector3(cell_size * 0.72, 2.25, 0.10)
    door.mesh = door_mesh
    door.material_override = _exit_material
    door.position = exit_world_position + Vector3(0.0, 1.10, 0.0)
    add_child(door)

    var door_light: OmniLight3D = OmniLight3D.new()
    door_light.name = "ExitDoorGlow"
    door_light.position = exit_world_position + Vector3(0.0, 1.35, 0.0)
    door_light.light_color = Color(0.38, 1.0, 0.78, 1.0)
    door_light.light_energy = 1.9
    door_light.omni_range = 8.0
    door_light.shadow_enabled = false
    add_child(door_light)

func _create_materials() -> void:
    # AAA PBR doku setleri (albedo + normal + roughness), dünya-uzayı triplanar →
    # büyük multimesh kutularında gerilme olmaz, normal harita gerçek yüzey kabartması verir.
    # Sarı kirli Backrooms duvar kâğıdı: albedo + normal (mat). Roughness/height KAPALI
    # (fenerde gereksiz parlamayı önler + mobilde çok daha hafif). uv ölçeği büyütüldü → daha az tekrar.
    _wall_material = _make_pbr_material("wall_yellow_dirty", Color(1.0, 0.99, 0.95, 1.0), 0.0, 0.96, Vector3(1.6, 1.22, 1.0), false, true, false, false)
    # Eski kirli Backrooms halısı: albedo + normal (mat). Kuru halı → roughness/height KAPALI.
    _floor_material = _make_pbr_material("carpet_old_dirty", Color(1.0, 0.99, 0.95, 1.0), 0.0, 0.95, Vector3(2.0, 2.0, 1.0), false, true, false, false)
    _ceiling_material = _make_pbr_material("ceiling", Color(1.0, 0.98, 0.92, 1.0), 0.0, 0.85, Vector3(1.5, 1.5, 1.0), false, false)
    _metal_material = _make_pbr_material("metal", Color(0.82, 0.83, 0.86, 1.0), 0.92, 0.5, Vector3(1.0, 1.0, 1.0), false, true)
    _concrete_material = _make_pbr_material("concrete", Color(0.93, 0.91, 0.86, 1.0), 0.0, 0.82, Vector3(1.0, 1.0, 1.0), false, true)

    _trim_material = _make_flat_material(Color(0.40, 0.33, 0.18, 1.0), 0.7)
    _stain_material = _make_flat_material(Color(0.105, 0.085, 0.055, 1.0), 1.0)
    _wire_material = _make_flat_material(Color(0.025, 0.022, 0.018, 1.0), 0.78)
    _vent_material = _metal_material
    _dark_material = _make_flat_material(Color(0.016, 0.013, 0.009, 1.0), 1.0)
    _warning_material = _make_flat_material(Color(0.82, 0.58, 0.18, 1.0), 0.66)
    _mold_material = _make_flat_material(Color(0.025, 0.055, 0.035, 1.0), 1.0)
    _paper_material = _make_flat_material(Color(0.70, 0.62, 0.42, 1.0), 0.96)
    var grid_material: StandardMaterial3D = _make_flat_material(Color(0.11, 0.11, 0.12, 1.0), 0.5)
    grid_material.metallic = 0.6
    _ceiling_grid_material = grid_material

    var exit_material: StandardMaterial3D = StandardMaterial3D.new()
    exit_material.albedo_color = Color(0.25, 0.86, 0.64, 1.0)
    exit_material.roughness = 0.42
    exit_material.emission_enabled = true
    exit_material.emission = Color(0.15, 1.0, 0.68, 1.0)
    exit_material.emission_energy_multiplier = 2.7
    _exit_material = exit_material

    var emissive: StandardMaterial3D = StandardMaterial3D.new()
    emissive.albedo_color = Color(1.0, 0.98, 0.90, 1.0)
    emissive.roughness = 0.18
    emissive.emission_enabled = true
    emissive.emission = Color(1.0, 0.95, 0.72, 1.0)
    emissive.emission_energy_multiplier = 4.6
    _emissive_material = emissive

func _make_pbr_material(set_name: String, tint: Color, metallic_value: float, rough_value: float, uv_scale: Vector3, triplanar: bool, use_normal: bool, use_roughness: bool = false, use_height: bool = false) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = tint
    var albedo: Texture2D = _load_tex("res://textures/%s_albedo.png" % set_name)
    if albedo != null:
        material.albedo_texture = albedo
    # Normal harita yalnızca gerektiğinde (triplanar her dokuyu 3× örnekler → mobilde maliyet).
    if use_normal:
        var normal: Texture2D = _load_tex("res://textures/%s_normal.png" % set_name)
        if normal != null:
            material.normal_enabled = true
            material.normal_texture = normal
            material.normal_scale = 1.0
    # Roughness: kaliteli doku varsa onu kullan, yoksa skaler (mobilde hafif)
    if use_roughness:
        var rough_tex: Texture2D = _load_tex("res://textures/%s_roughness.png" % set_name)
        if rough_tex != null:
            material.roughness_texture = rough_tex
            material.roughness = 1.0
        else:
            material.roughness = rough_value
    else:
        material.roughness = rough_value
    # Height: parallax/derinlik haritası (yükseklik hissi)
    if use_height:
        var height_tex: Texture2D = _load_tex("res://textures/%s_height.png" % set_name)
        if height_tex != null:
            material.heightmap_enabled = true
            material.heightmap_texture = height_tex
            material.heightmap_scale = 4.0
            material.heightmap_deep_parallax = false
    material.metallic = metallic_value
    material.uv1_scale = uv_scale
    material.uv1_triplanar = triplanar
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    material.texture_repeat = true
    return material

func _load_tex(path: String) -> Texture2D:
    if not ResourceLoader.exists(path):
        return null
    var resource: Resource = load(path)
    if resource is Texture2D:
        return resource as Texture2D
    return null

func _make_flat_material(color: Color, roughness: float) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = 0.0
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return material

extends Node3D
class_name PremiumBackroomsBuilder

# ÇOK KATLI ODA+KORİDOR LABİRENTİ
# - 2 kat (üst y=0, alt y=-FLOOR_GAP), rampalarla bağlı (yürünebilir eğim).
# - Her kat: dikdörtgen odalar + L-koridorlar + ekstra bağlantılar (kavşak/yol ayrımı) + çıkmazlar.
# - Odalarda düzgün ızgarada sütunlar.
# - Pathfinding kat-farkındalıklı: hücre = Vector3i(x, kat, z). Rampalar katları graf olarak bağlar.

@export var world_seed: int = 463063
@export var grid_width: int = 33
@export var grid_height: int = 33
@export var cell_size: float = 4.0
@export var wall_height: float = 3.0
@export var ceiling_height: float = 3.0
@export var room_count: int = 12
@export var detail_density: float = 1.0
@export var chunk_size: int = 12
@export var floors: int = 2

const FLOOR_GAP: float = 3.9          # katlar arası dikey mesafe
const RAMP_RUN: int = 4               # rampa kaç hücre boyunca iner (eğim = atan(FLOOR_GAP/(RAMP_RUN*cell)))

var start_cell: Vector3i = Vector3i.ZERO
var exit_cell: Vector3i = Vector3i.ZERO
var enemy_cell: Vector3i = Vector3i.ZERO
var start_world_position: Vector3 = Vector3.ZERO
var exit_world_position: Vector3 = Vector3.ZERO
var enemy_world_position: Vector3 = Vector3.ZERO
var fixture_positions: Array[Vector3] = []
var battery_positions: Array[Vector3] = []
var chunks: Array[Node3D] = []
var exit_area: Area3D
var event_positions: Array[Vector3] = []
var hiding_spot_positions: Array[Vector3] = []

var _grids: Array = []                # _grids[f] : Array[PackedByteArray]  (0 açık, 1 duvar)
var _rooms: Array = []                # her eleman: {"floor": int, "rect": Rect2i}
var _links: Dictionary = {}           # Vector3i -> Array[Vector3i]  (rampa graf bağlantıları)
var _ramps: Array = []                # geometri için: {"floor","x","z","dir":Vector2i}
var _open_cells: Array[Vector3i] = []

# Havuz (Poolrooms) — alt katta dev su alanı
var _water_cells: Dictionary = {}
var has_pool: bool = false
var pool_min: Vector3 = Vector3.ZERO
var pool_max: Vector3 = Vector3.ZERO
var pool_water_y: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _box_mesh_shared: BoxMesh
var _cylinder_mesh_shared: CylinderMesh

var _wall_material: Material
var _floor_material: Material
var _ceiling_material: Material
var _trim_material: Material
var _metal_material: Material
var _concrete_material: Material
var _tile_material: Material
var _grate_material: Material
var _ceiling_grid_material: Material
var _emissive_material: Material
var _exit_material: Material
var _ramp_material: Material

# ---------------------------------------------------------------- yaşam döngüsü

func generate() -> void:
    _rng.seed = world_seed
    grid_width = max(grid_width, 15)
    grid_height = max(grid_height, 15)
    floors = clamp(floors, 1, 3)
    _create_materials()
    _build_grids()
    for f: int in range(floors):
        _generate_floor(f)
    _connect_floors()
    _build_pool()
    _pick_special_cells()
    _collect_open_cells()
    _build_geometry()
    # Çıkış yok (döngü harita) → _build_exit_area çağrılmaz. exit_area null kalır.

# ---------------------------------------------------------------- grid temel

func _build_grids() -> void:
    _grids.clear()
    for _f: int in range(floors):
        var floor_grid: Array = []
        for _z: int in range(grid_height):
            var row: PackedByteArray = PackedByteArray()
            row.resize(grid_width)
            for x: int in range(grid_width):
                row[x] = 1
            floor_grid.append(row)
        _grids.append(floor_grid)

func _in_bounds(x: int, z: int) -> bool:
    return x >= 0 and z >= 0 and x < grid_width and z < grid_height

func _get_cell(f: int, x: int, z: int) -> int:
    if f < 0 or f >= floors or not _in_bounds(x, z):
        return 1
    var row: PackedByteArray = _grids[f][z]
    return int(row[x])

func _set_cell(f: int, x: int, z: int, value: int) -> void:
    if f < 0 or f >= floors or not _in_bounds(x, z):
        return
    var row: PackedByteArray = _grids[f][z]
    row[x] = value
    _grids[f][z] = row

# ---------------------------------------------------------------- kat üretimi

func _generate_floor(f: int) -> void:
    var placed: Array = []   # Rect2i listesi
    var target_rooms: int = max(4, room_count)
    var attempts: int = target_rooms * 6
    while placed.size() < target_rooms and attempts > 0:
        attempts -= 1
        var rw: int = _rng.randi_range(4, 8)
        var rh: int = _rng.randi_range(4, 7)
        var rx: int = _rng.randi_range(1, max(1, grid_width - rw - 1))
        var rz: int = _rng.randi_range(1, max(1, grid_height - rh - 1))
        var rect: Rect2i = Rect2i(rx, rz, rw, rh)
        if _overlaps_any(rect, placed, 1):
            continue
        placed.append(rect)
        _carve_room(f, rect)
        _rooms.append({"floor": f, "rect": rect})

    # Odaları sırayla bağla (omurga) → garantili bağlantı.
    for i: int in range(1, placed.size()):
        var a: Vector2i = _room_center(placed[i - 1])
        var b: Vector2i = _room_center(placed[i])
        _carve_corridor(f, a, b)

    # Ekstra bağlantılar → BOL döngü / kavşak / yol ayrımı (labirent hissi).
    var extra: int = placed.size() + 2
    for _e: int in range(extra):
        if placed.size() < 2:
            break
        var a2: Vector2i = _room_center(placed[_rng.randi_range(0, placed.size() - 1)])
        var b2: Vector2i = _room_center(placed[_rng.randi_range(0, placed.size() - 1)])
        if a2 != b2:
            _carve_corridor(f, a2, b2)

    # Çıkmaz koridorlar (keşif/labirent hissi).
    for _d: int in range(6):
        if placed.is_empty():
            break
        var src: Vector2i = _room_center(placed[_rng.randi_range(0, placed.size() - 1)])
        var dir: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][_rng.randi_range(0, 3)]
        var length: int = _rng.randi_range(3, 7)
        var cur: Vector2i = src
        for _s: int in range(length):
            cur += dir
            if not _in_bounds(cur.x, cur.y):
                break
            _set_cell(f, cur.x, cur.y, 0)

func _overlaps_any(rect: Rect2i, placed: Array, margin: int) -> bool:
    var grown: Rect2i = Rect2i(rect.position - Vector2i(margin, margin), rect.size + Vector2i(margin * 2, margin * 2))
    for other: Rect2i in placed:
        if grown.intersects(other):
            return true
    return false

func _carve_room(f: int, rect: Rect2i) -> void:
    for z: int in range(rect.position.y, rect.position.y + rect.size.y):
        for x: int in range(rect.position.x, rect.position.x + rect.size.x):
            _set_cell(f, x, z, 0)

func _room_center(rect: Rect2i) -> Vector2i:
    return Vector2i(rect.position.x + int(rect.size.x / 2), rect.position.y + int(rect.size.y / 2))

func _carve_corridor(f: int, a: Vector2i, b: Vector2i) -> void:
    # L şekilli: önce yatay, sonra dikey. Bazen 2 hücre geniş.
    var wide: bool = _rng.randf() < 0.45
    var x0: int = min(a.x, b.x)
    var x1: int = max(a.x, b.x)
    for x: int in range(x0, x1 + 1):
        _set_cell(f, x, a.y, 0)
        if wide and a.y + 1 < grid_height - 1:
            _set_cell(f, x, a.y + 1, 0)
    var z0: int = min(a.y, b.y)
    var z1: int = max(a.y, b.y)
    for z: int in range(z0, z1 + 1):
        _set_cell(f, b.x, z, 0)
        if wide and b.x + 1 < grid_width - 1:
            _set_cell(f, b.x + 1, z, 0)

# ---------------------------------------------------------------- rampalar (kat bağlantısı)

func _connect_floors() -> void:
    for f: int in range(floors - 1):
        var made: bool = false
        var tries: int = 200
        while not made and tries > 0:
            tries -= 1
            made = _try_place_ramp(f)
        # Güvenlik: rampa kurulamadıysa zorla bir tane aç.
        if not made:
            _force_ramp(f)

func _try_place_ramp(f: int) -> bool:
    var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    var dir: Vector2i = dirs[_rng.randi_range(0, 3)]
    var tx: int = _rng.randi_range(2, grid_width - 3)
    var tz: int = _rng.randi_range(2, grid_height - 3)
    if _get_cell(f, tx, tz) != 0:
        return false
    var bx: int = tx + dir.x * RAMP_RUN
    var bz: int = tz + dir.y * RAMP_RUN
    if not _in_bounds(bx, bz):
        return false
    # Rampa boyunca üst katta hücreleri aç (rampa koridoru).
    for i: int in range(0, RAMP_RUN + 1):
        var cx: int = tx + dir.x * i
        var cz: int = tz + dir.y * i
        if not _in_bounds(cx, cz):
            return false
    _commit_ramp(f, tx, tz, dir)
    return true

func _force_ramp(f: int) -> void:
    # Haritanın ortasından sabit bir rampa.
    var tx: int = int(grid_width / 2)
    var tz: int = int(grid_height / 2)
    var dir: Vector2i = Vector2i(1, 0)
    if tx + RAMP_RUN >= grid_width - 1:
        dir = Vector2i(-1, 0)
    _commit_ramp(f, tx, tz, dir)

func _commit_ramp(f: int, tx: int, tz: int, dir: Vector2i) -> void:
    var bx: int = tx + dir.x * RAMP_RUN
    var bz: int = tz + dir.y * RAMP_RUN
    # Üst kat: rampa ağzı + üstündeki hücreler açık.
    for i: int in range(0, RAMP_RUN + 1):
        _set_cell(f, tx + dir.x * i, tz + dir.y * i, 0)
    # Alt kat: iniş noktası ve etrafını aç, ağ'a bağla.
    _set_cell(f + 1, bx, bz, 0)
    _open_disc(f + 1, bx, bz, 1)
    _connect_to_nearest_room(f + 1, Vector2i(bx, bz))
    # Graf bağlantısı (çift yönlü).
    var top_node: Vector3i = Vector3i(tx, f, tz)
    var bottom_node: Vector3i = Vector3i(bx, f + 1, bz)
    _add_link(top_node, bottom_node)
    _add_link(bottom_node, top_node)
    _ramps.append({"floor": f, "x": tx, "z": tz, "dir": dir})

func _open_disc(f: int, cx: int, cz: int, r: int) -> void:
    for dz: int in range(-r, r + 1):
        for dx: int in range(-r, r + 1):
            _set_cell(f, cx + dx, cz + dz, 0)

func _connect_to_nearest_room(f: int, from_cell: Vector2i) -> void:
    var best: Vector2i = from_cell
    var best_d: int = 1 << 30
    for entry: Dictionary in _rooms:
        if int(entry["floor"]) != f:
            continue
        var c: Vector2i = _room_center(entry["rect"] as Rect2i)
        var d: int = abs(c.x - from_cell.x) + abs(c.y - from_cell.y)
        if d < best_d:
            best_d = d
            best = c
    if best != from_cell:
        _carve_corridor(f, from_cell, best)

func _add_link(a: Vector3i, b: Vector3i) -> void:
    if not _links.has(a):
        _links[a] = [] as Array[Vector3i]
    var arr: Array = _links[a]
    if not arr.has(b):
        arr.append(b)

# ---------------------------------------------------------------- pathfinding (Vector3i)

func is_open_cell(cell: Vector3i) -> bool:
    return _get_cell(cell.y, cell.x, cell.z) == 0

func get_open_neighbors(cell: Vector3i) -> Array[Vector3i]:
    var result: Array[Vector3i] = []
    var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    for d: Vector2i in dirs:
        var n: Vector3i = Vector3i(cell.x + d.x, cell.y, cell.z + d.y)
        if is_open_cell(n):
            result.append(n)
    if _links.has(cell):
        for linked: Vector3i in _links[cell]:
            if is_open_cell(linked):
                result.append(linked)
    return result

func world_to_grid(world_position: Vector3) -> Vector3i:
    var f: int = clamp(int(round(-world_position.y / FLOOR_GAP)), 0, floors - 1)
    var x_value: int = int(round(world_position.x / cell_size + float(grid_width - 1) * 0.5))
    var z_value: int = int(round(world_position.z / cell_size + float(grid_height - 1) * 0.5))
    return Vector3i(clamp(x_value, 0, grid_width - 1), f, clamp(z_value, 0, grid_height - 1))

func grid_to_world(cell: Vector3i, y_height: float = 0.0) -> Vector3:
    var x_pos: float = (float(cell.x) - float(grid_width - 1) * 0.5) * cell_size
    var z_pos: float = (float(cell.z) - float(grid_height - 1) * 0.5) * cell_size
    var base_y: float = -float(cell.y) * FLOOR_GAP
    return Vector3(x_pos, base_y + y_height, z_pos)

func get_grid_path(start: Vector3i, goal: Vector3i, max_steps: int = 4000) -> Array[Vector3i]:
    var path: Array[Vector3i] = []
    if not is_open_cell(start):
        return path
    if not is_open_cell(goal):
        goal = _nearest_open_cell(goal)
        if goal.x < 0:
            return path
    if start == goal:
        return path
    var frontier: Array[Vector3i] = [start]
    var head: int = 0
    var came_from: Dictionary = {}
    came_from[start] = start
    var steps: int = 0
    while head < frontier.size() and steps < max_steps:
        steps += 1
        var current: Vector3i = frontier[head]
        head += 1
        if current == goal:
            break
        for n: Vector3i in get_open_neighbors(current):
            if not came_from.has(n):
                came_from[n] = current
                frontier.append(n)
    if not came_from.has(goal):
        return path
    var trace: Vector3i = goal
    while trace != start:
        path.push_front(trace)
        trace = came_from[trace]
    return path

func has_grid_line_of_sight(start: Vector3i, goal: Vector3i, max_cells: int = 14) -> bool:
    if start.y != goal.y:
        return false   # farklı kat → görüş yok
    if not is_open_cell(start) or not is_open_cell(goal):
        return false
    var f: int = start.y
    var delta: Vector2i = Vector2i(goal.x - start.x, goal.z - start.z)
    var steps: int = max(abs(delta.x), abs(delta.y))
    if steps > max_cells:
        return false
    if steps <= 0:
        return true
    for step: int in range(1, steps + 1):
        var t: float = float(step) / float(steps)
        var cx: int = int(round(lerp(float(start.x), float(goal.x), t)))
        var cz: int = int(round(lerp(float(start.z), float(goal.z), t)))
        if _get_cell(f, cx, cz) != 0:
            return false
    return true

func _nearest_open_cell(cell: Vector3i) -> Vector3i:
    if is_open_cell(cell):
        return cell
    for radius: int in range(1, 7):
        for dz: int in range(-radius, radius + 1):
            for dx: int in range(-radius, radius + 1):
                var cand: Vector3i = Vector3i(cell.x + dx, cell.y, cell.z + dz)
                if is_open_cell(cand):
                    return cand
    return Vector3i(-1, cell.y, -1)

func _collect_open_cells() -> void:
    _open_cells.clear()
    for f: int in range(floors):
        for z: int in range(grid_height):
            for x: int in range(grid_width):
                if _get_cell(f, x, z) == 0:
                    _open_cells.append(Vector3i(x, f, z))
    _pick_items()

func _pick_items() -> void:
    # Pil bataryaları: başlangıçtan uzak, dağınık açık hücreler (hayatta kalma kaynağı).
    battery_positions.clear()
    if _open_cells.is_empty():
        return
    var want: int = clamp(int(_open_cells.size() / 90), 6, 16)
    var tries: int = want * 12
    var used: Dictionary = {}
    while battery_positions.size() < want and tries > 0:
        tries -= 1
        var cell: Vector3i = _open_cells[_rng.randi_range(0, _open_cells.size() - 1)]
        var keyc: String = "%d:%d:%d" % [cell.y, cell.x, cell.z]
        if used.has(keyc) or cell == start_cell or _water_cells.has(keyc):
            continue
        if _cell_distance_squared(cell, start_cell) < 36.0:
            continue
        used[keyc] = true
        battery_positions.append(grid_to_world(cell, 0.55))

func _cell_distance_squared(a: Vector3i, b: Vector3i) -> float:
    var dx: int = a.x - b.x
    var dz: int = a.z - b.z
    var df: int = (a.y - b.y) * 6   # kat farkı pahalı sayılır
    return float(dx * dx + dz * dz + df * df)

func get_random_open_cell_near(reference_cell: Vector3i, min_distance: int, max_distance: int, random: RandomNumberGenerator) -> Vector3i:
    var candidates: Array[Vector3i] = []
    var min_sq: float = float(min_distance * min_distance)
    var max_sq: float = float(max_distance * max_distance)
    for cell: Vector3i in _open_cells:
        if cell.y != reference_cell.y:
            continue
        var dsq: float = _cell_distance_squared(cell, reference_cell)
        if dsq >= min_sq and dsq <= max_sq:
            candidates.append(cell)
    if candidates.is_empty():
        return reference_cell
    return candidates[random.randi_range(0, candidates.size() - 1)]

func get_ambush_cell_around(target_cell: Vector3i, random: RandomNumberGenerator) -> Vector3i:
    var c: Vector3i = get_random_open_cell_near(target_cell, 4, 11, random)
    if c == target_cell:
        return get_random_open_cell_near(target_cell, 2, 8, random)
    return c

func _bfs_distances(origin: Vector3i) -> Dictionary:
    var distances: Dictionary = {}
    if not is_open_cell(origin):
        return distances
    var frontier: Array[Vector3i] = [origin]
    distances[origin] = 0
    var head: int = 0
    while head < frontier.size():
        var current: Vector3i = frontier[head]
        head += 1
        var cd: int = int(distances[current])
        for n: Vector3i in get_open_neighbors(current):
            if not distances.has(n):
                distances[n] = cd + 1
                frontier.append(n)
    return distances

func _build_pool() -> void:
    # Alt katta DEV havuz: karşıya geçerek kaçabilirsin, canavar arkandan yüzer (yavaşlar).
    if floors < 2:
        return
    var pf: int = floors - 1
    var pw: int = clamp(grid_width - 8, 8, 14)
    var ph: int = clamp(grid_height - 8, 7, 12)
    var px: int = clamp(int(grid_width / 2 - pw / 2), 1, grid_width - pw - 1)
    var pz: int = clamp(int(grid_height / 2 - ph / 2), 1, grid_height - ph - 1)
    for z: int in range(pz, pz + ph):
        for x: int in range(px, px + pw):
            _set_cell(pf, x, z, 0)
            _water_cells["%d:%d:%d" % [pf, x, z]] = true
    # Havuzu kat ağına bağla (kenarlardan koridor)
    _rooms.append({"floor": pf, "rect": Rect2i(px, pz, pw, ph)})
    _connect_to_nearest_room(pf, Vector2i(px - 1, pz + int(ph / 2)))
    _connect_to_nearest_room(pf, Vector2i(px + pw, pz + int(ph / 2)))
    var w0: Vector3 = grid_to_world(Vector3i(px, pf, pz), 0.0)
    var w1: Vector3 = grid_to_world(Vector3i(px + pw - 1, pf, pz + ph - 1), 0.0)
    var half: float = cell_size * 0.5
    pool_min = Vector3(min(w0.x, w1.x) - half, w0.y - 1.0, min(w0.z, w1.z) - half)
    pool_max = Vector3(max(w0.x, w1.x) + half, w0.y + 1.6, max(w0.z, w1.z) + half)
    pool_water_y = w0.y + 0.25
    has_pool = true

func is_in_water(pos: Vector3) -> bool:
    if not has_pool:
        return false
    return pos.x >= pool_min.x and pos.x <= pool_max.x \
        and pos.z >= pool_min.z and pos.z <= pool_max.z \
        and pos.y >= pool_min.y and pos.y <= pool_max.y

func _pick_special_cells() -> void:
    # Başlangıç ORTA kat (üst + alt kat olsun). "Çıkış" yok ama enemy yerleşimi için
    # en uzak hücre yine hesaplanır.
    var mid_floor: int = int(floors / 2)
    var start_room: Rect2i = _first_room_on(mid_floor)
    start_cell = Vector3i(_room_center(start_room).x, mid_floor, _room_center(start_room).y)
    if not is_open_cell(start_cell):
        start_cell = _nearest_open_cell(start_cell)

    var dist: Dictionary = _bfs_distances(start_cell)
    var farthest: Vector3i = start_cell
    var fb: int = -1
    var deepest_floor: int = floors - 1
    for key: Vector3i in dist:
        var d: int = int(dist[key])
        # En alt kata ağırlık ver (oraya inmeyi teşvik).
        var score: int = d + key.y * 40
        if key.y == deepest_floor and score > fb:
            fb = score
            farthest = key
    if fb < 0:
        # alt kata ulaşılamıyorsa sadece en uzak hücre
        for key2: Vector3i in dist:
            var d2: int = int(dist[key2])
            if d2 > fb:
                fb = d2
                farthest = key2
    exit_cell = farthest

    var dist_exit: Dictionary = _bfs_distances(exit_cell)
    var best_score: int = -1
    var enemy_candidate: Vector3i = exit_cell
    for key3: Vector3i in dist:
        if not dist_exit.has(key3):
            continue
        var s: int = min(int(dist[key3]), int(dist_exit[key3]))
        if s > best_score:
            best_score = s
            enemy_candidate = key3
    enemy_cell = enemy_candidate

    start_world_position = grid_to_world(start_cell, 0.0)
    exit_world_position = grid_to_world(exit_cell, 0.0)
    enemy_world_position = grid_to_world(enemy_cell, 0.0)

func _first_room_on(f: int) -> Rect2i:
    for entry: Dictionary in _rooms:
        if int(entry["floor"]) == f:
            return entry["rect"] as Rect2i
    return Rect2i(1, 1, 3, 3)

# ---------------------------------------------------------------- geometri

func _ramp_footprint() -> Dictionary:
    # "f:x:z" -> true  (üst kat zeminini ve alt kat tavanını delmek için)
    var set: Dictionary = {}
    for r: Dictionary in _ramps:
        var f: int = int(r["floor"])
        var x: int = int(r["x"])
        var z: int = int(r["z"])
        var dir: Vector2i = r["dir"]
        for i: int in range(0, RAMP_RUN + 1):
            var cx: int = x + dir.x * i
            var cz: int = z + dir.y * i
            set["%d:%d:%d" % [f, cx, cz]] = true            # üst kat zemini delinir
            set["%d:%d:%d" % [f + 1, cx, cz]] = true        # alt kat tavanı delinir
    return set

func _build_geometry() -> void:
    fixture_positions.clear()
    chunks.clear()
    var holes: Dictionary = _ramp_footprint()
    var buckets: Dictionary = {}

    for f: int in range(floors):
        var base_y: float = -float(f) * FLOOR_GAP
        for z: int in range(grid_height):
            for x: int in range(grid_width):
                var cell: Vector3i = Vector3i(x, f, z)
                var center: Vector3 = Vector3((float(x) - float(grid_width - 1) * 0.5) * cell_size, base_y, (float(z) - float(grid_height - 1) * 0.5) * cell_size)
                var bucket: Dictionary = _get_bucket(buckets, f, x, z)
                var key: String = "%d:%d:%d" % [f, x, z]
                if _get_cell(f, x, z) == 0:
                    var is_water: bool = _water_cells.has(key)
                    if not holes.has(key):
                        # Havuz hücreleri beyaz fayans, diğerleri halı
                        var floor_type: String = "pooltile" if is_water else "floor"
                        _bpush(bucket, floor_type, _scaled_transform(Vector3(cell_size, 0.10, cell_size), center + Vector3(0.0, -0.05, 0.0)))
                    # Tavan (sadece üstünde başka kat yoksa tam tavan; rampa deliği hariç)
                    if not holes.has(key):
                        _bpush(bucket, "ceiling", _scaled_transform(Vector3(cell_size, 0.12, cell_size), center + Vector3(0.0, ceiling_height, 0.0)))
                        var grid_y: float = ceiling_height - 0.07
                        _bpush(bucket, "grid", _scaled_transform(Vector3(cell_size, 0.05, 0.07), center + Vector3(0.0, grid_y, 0.0)))
                        _bpush(bucket, "grid", _scaled_transform(Vector3(0.07, 0.05, cell_size), center + Vector3(0.0, grid_y, 0.0)))
                    # Duvar süpürgeliği (komşu duvarsa)
                    _append_trims(f, cell, center, bucket)
                    # Tavan armatürü
                    if _should_fixture(cell):
                        var fp: Vector3 = center + Vector3(0.0, ceiling_height - 0.08, 0.0)
                        fixture_positions.append(fp)
                        _bpush(bucket, "housing", _scaled_transform(Vector3(cell_size * 0.72, 0.13, 0.60), fp + Vector3(0.0, 0.05, 0.0)))
                        _bpush(bucket, "fixture", _scaled_transform(Vector3(cell_size * 0.58, 0.05, 0.12), fp + Vector3(0.0, 0.0, -0.13)))
                        _bpush(bucket, "fixture", _scaled_transform(Vector3(cell_size * 0.58, 0.05, 0.12), fp + Vector3(0.0, 0.0, 0.13)))
                    # Tavan havalandırma ızgarası (paslı metal grate)
                    if not is_water and _should_vent(cell):
                        _bpush(bucket, "vent", _scaled_transform(Vector3(cell_size * 0.5, 0.04, cell_size * 0.3), center + Vector3(0.0, ceiling_height - 0.10, 0.0)))
                else:
                    _bpush(bucket, "wall", _scaled_transform(Vector3(cell_size, wall_height, cell_size), center + Vector3(0.0, wall_height * 0.5, 0.0)))
                    if not bucket.has("_walls"):
                        bucket["_walls"] = []
                    bucket["_walls"].append(center)

    _place_columns(buckets)
    _build_ramp_geometry(buckets)

    for key2: Vector3i in buckets.keys():
        _build_chunk(key2, buckets[key2])

    _build_water_surface()

func _build_water_surface() -> void:
    if not has_pool:
        return
    var water: MeshInstance3D = MeshInstance3D.new()
    water.name = "PoolWater"
    var pm: PlaneMesh = PlaneMesh.new()
    pm.size = Vector2(pool_max.x - pool_min.x, pool_max.z - pool_min.z)
    water.mesh = pm
    water.position = Vector3((pool_min.x + pool_max.x) * 0.5, pool_water_y, (pool_min.z + pool_max.z) * 0.5)
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = Color(0.05, 0.17, 0.22, 0.6)
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.roughness = 0.06
    m.metallic = 0.25
    m.emission_enabled = true
    m.emission = Color(0.02, 0.09, 0.11, 1.0)
    m.emission_energy_multiplier = 0.5
    water.material_override = m
    add_child(water)

func _append_trims(f: int, cell: Vector3i, center: Vector3, bucket: Dictionary) -> void:
    var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    for d: Vector2i in dirs:
        if _get_cell(f, cell.x + d.x, cell.z + d.y) != 0:
            if d.x != 0:
                var xo: float = float(d.x) * cell_size * 0.5
                _bpush(bucket, "trim", _scaled_transform(Vector3(0.12, 0.22, cell_size), center + Vector3(xo, 0.18, 0.0)))
            else:
                var zo: float = float(d.y) * cell_size * 0.5
                _bpush(bucket, "trim", _scaled_transform(Vector3(cell_size, 0.22, 0.12), center + Vector3(0.0, 0.18, zo)))

func _place_columns(buckets: Dictionary) -> void:
    # Sadece GENİŞ odalara, kenardan 2 boşluk içeride, DÜZENLİ ızgarada sütun.
    # Lamba (armatür) hücrelerine ASLA sütun konmaz (lambanın ortasından geçme sorunu).
    for entry: Dictionary in _rooms:
        var f: int = int(entry["floor"])
        var rect: Rect2i = entry["rect"] as Rect2i
        if rect.size.x < 7 or rect.size.y < 7:
            continue
        var base_y: float = -float(f) * FLOOR_GAP
        var z: int = rect.position.y + 2
        while z <= rect.position.y + rect.size.y - 3:
            var x: int = rect.position.x + 2
            while x <= rect.position.x + rect.size.x - 3:
                var cell: Vector3i = Vector3i(x, f, z)
                # açık hücre + lamba değil + başlangıç/çıkış değil
                if _get_cell(f, x, z) == 0 and not _should_fixture(cell) and cell != start_cell and cell != exit_cell and not _water_cells.has("%d:%d:%d" % [f, x, z]):
                    var c: Vector3 = Vector3((float(x) - float(grid_width - 1) * 0.5) * cell_size, base_y, (float(z) - float(grid_height - 1) * 0.5) * cell_size)
                    var bucket: Dictionary = _get_bucket(buckets, f, x, z)
                    _bpush(bucket, "column", _scaled_transform(Vector3(0.55, wall_height, 0.55), c + Vector3(0.0, wall_height * 0.5, 0.0)))
                    if not bucket.has("_columns"):
                        bucket["_columns"] = []
                    bucket["_columns"].append(c)
                x += 3
            z += 3

func _build_ramp_geometry(buckets: Dictionary) -> void:
    for r: Dictionary in _ramps:
        var f: int = int(r["floor"])
        var x: int = int(r["x"])
        var z: int = int(r["z"])
        var dir: Vector2i = r["dir"]
        var top_center: Vector3 = grid_to_world(Vector3i(x, f, z), 0.0)
        var bottom_center: Vector3 = grid_to_world(Vector3i(x + dir.x * RAMP_RUN, f + 1, z + dir.y * RAMP_RUN), 0.0)
        var run_world: float = float(RAMP_RUN) * cell_size
        var drop: float = FLOOR_GAP
        var length: float = sqrt(run_world * run_world + drop * drop)
        var angle: float = atan2(drop, run_world)
        var mid: Vector3 = (top_center + bottom_center) * 0.5
        var horizontal: Vector3 = Vector3(float(dir.x), 0.0, float(dir.y))
        var bucket: Dictionary = _get_bucket(buckets, f, x, z)

        # Eğik zemin (rampa yüzeyi). Yön: dir ekseninde uzun, eğimli.
        var ramp_basis: Basis = Basis()
        if dir.x != 0:
            ramp_basis = Basis(Vector3(0, 0, 1), -float(dir.x) * angle)
            ramp_basis = ramp_basis.scaled(Vector3(length, 0.18, cell_size))
        else:
            ramp_basis = Basis(Vector3(1, 0, 0), float(dir.y) * angle)
            ramp_basis = ramp_basis.scaled(Vector3(cell_size, 0.18, length))
        _bpush(bucket, "ramp", Transform3D(ramp_basis, mid + Vector3(0.0, -0.04, 0.0)))

        # Rampa çarpışması + yan duvarlar bilgisi (çarpışma _build_chunk'ta eklenir).
        if not bucket.has("_ramps"):
            bucket["_ramps"] = []
        bucket["_ramps"].append({"mid": mid, "angle": angle, "dir": dir, "length": length})

        # Görsel basamaklar (merdiven hissi) — rampanın üstüne ince kutular.
        var steps: int = 6
        for s: int in range(steps):
            var t: float = (float(s) + 0.5) / float(steps)
            var p: Vector3 = top_center.lerp(bottom_center, t)
            _bpush(bucket, "trim", _scaled_transform(Vector3(cell_size * 0.9, 0.06, cell_size * 0.22), p + horizontal * 0.0 + Vector3(0.0, 0.10, 0.0)))

# ---------------------------------------------------------------- chunk inşa

func _get_bucket(buckets: Dictionary, f: int, x: int, z: int) -> Dictionary:
    var key: Vector3i = Vector3i(int(x / chunk_size), f, int(z / chunk_size))
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
        "grid": return [false, _ceiling_grid_material]
        "trim": return [false, _trim_material]
        "column": return [false, _concrete_material]
        "pooltile": return [false, _tile_material]
        "vent": return [false, _grate_material]
        "housing": return [false, _metal_material]
        "fixture": return [false, _emissive_material]
        "ramp": return [false, _ramp_material]
    return [false, _wall_material]

func _build_chunk(key: Vector3i, bucket: Dictionary) -> void:
    var chunk: Node3D = Node3D.new()
    chunk.name = "Chunk_%d_%d_%d" % [key.y, key.x, key.z]
    add_child(chunk)

    for type_name: String in bucket.keys():
        if type_name.begins_with("_"):
            continue
        var info: Array = _chunk_type_info(type_name)
        var mesh: Mesh = _box_mesh()
        _create_chunk_multimesh(chunk, type_name, mesh, bucket[type_name], info[1] as Material)

    # Çarpışma gövdesi
    var f: int = key.y
    var base_y: float = -float(f) * FLOOR_GAP
    var cx0: int = key.x * chunk_size
    var cz0: int = key.z * chunk_size
    var cx1: int = min(cx0 + chunk_size, grid_width)
    var cz1: int = min(cz0 + chunk_size, grid_height)
    var span_x: float = float(cx1 - cx0) * cell_size
    var span_z: float = float(cz1 - cz0) * cell_size
    var wx: float = (float(cx0) - float(grid_width - 1) * 0.5) * cell_size
    var wz: float = (float(cz0) - float(grid_height - 1) * 0.5) * cell_size
    var ex: float = (float(cx1 - 1) - float(grid_width - 1) * 0.5) * cell_size
    var ez: float = (float(cz1 - 1) - float(grid_height - 1) * 0.5) * cell_size
    var center_world: Vector3 = Vector3((wx + ex) * 0.5, base_y, (wz + ez) * 0.5)

    var body: StaticBody3D = StaticBody3D.new()
    body.name = "ChunkCollision"
    chunk.add_child(body)

    var floor_shape: BoxShape3D = BoxShape3D.new()
    floor_shape.size = Vector3(span_x, 0.22, span_z)
    var floor_col: CollisionShape3D = CollisionShape3D.new()
    floor_col.shape = floor_shape
    floor_col.position = center_world + Vector3(0.0, -0.12, 0.0)
    body.add_child(floor_col)

    if bucket.has("_walls"):
        for wc: Vector3 in bucket["_walls"]:
            var ws: BoxShape3D = BoxShape3D.new()
            ws.size = Vector3(cell_size, wall_height, cell_size)
            var wcol: CollisionShape3D = CollisionShape3D.new()
            wcol.shape = ws
            wcol.position = wc + Vector3(0.0, wall_height * 0.5, 0.0)
            body.add_child(wcol)

    if bucket.has("_columns"):
        for cc: Vector3 in bucket["_columns"]:
            var cs: BoxShape3D = BoxShape3D.new()
            cs.size = Vector3(0.5, wall_height, 0.5)
            var ccol: CollisionShape3D = CollisionShape3D.new()
            ccol.shape = cs
            ccol.position = cc + Vector3(0.0, wall_height * 0.5, 0.0)
            body.add_child(ccol)

    if bucket.has("_ramps"):
        for rr: Dictionary in bucket["_ramps"]:
            var rs: BoxShape3D = BoxShape3D.new()
            var dir: Vector2i = rr["dir"]
            var length: float = float(rr["length"])
            var angle: float = float(rr["angle"])
            var rb: Basis = Basis()
            if dir.x != 0:
                rb = Basis(Vector3(0, 0, 1), -float(dir.x) * angle)
                rs.size = Vector3(length, 0.4, cell_size)
            else:
                rb = Basis(Vector3(1, 0, 0), float(dir.y) * angle)
                rs.size = Vector3(cell_size, 0.4, length)
            var rcol: CollisionShape3D = CollisionShape3D.new()
            rcol.shape = rs
            rcol.transform = Transform3D(rb, (rr["mid"] as Vector3) + Vector3(0.0, -0.1, 0.0))
            body.add_child(rcol)

    var cull_radius: float = sqrt(span_x * span_x + span_z * span_z) * 0.5 + cell_size
    chunk.set_meta("center", center_world)
    chunk.set_meta("cull_radius", cull_radius)
    chunks.append(chunk)

func _create_chunk_multimesh(parent: Node3D, node_name: String, mesh: Mesh, transforms: Array, material: Material) -> void:
    if transforms.is_empty():
        return
    var mm: MultiMesh = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = transforms.size()
    for index: int in range(transforms.size()):
        mm.set_instance_transform(index, transforms[index])
    var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
    inst.name = node_name
    inst.multimesh = mm
    inst.material_override = material
    parent.add_child(inst)

# ---------------------------------------------------------------- yardımcılar

func _should_fixture(cell: Vector3i) -> bool:
    if cell == start_cell or cell == exit_cell:
        return true
    var h: int = abs(cell.x * 73856093 ^ cell.z * 19349663 ^ (world_seed + cell.y * 7))
    return h % 4 == 0

func _should_vent(cell: Vector3i) -> bool:
    var h: int = abs(cell.x * 19349663 ^ cell.z * 83492791 ^ (world_seed + cell.y * 11))
    return h % 13 == 0

func _box_mesh() -> BoxMesh:
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
    var b: Basis = Basis().scaled(scale_vector)
    return Transform3D(b, origin)

func _rotated_scaled_transform(scale_vector: Vector3, origin: Vector3, axis: Vector3, angle: float) -> Transform3D:
    var b: Basis = Basis().rotated(axis, angle).scaled(scale_vector)
    return Transform3D(b, origin)

# ---------------------------------------------------------------- çıkış

func _build_exit_area() -> void:
    exit_area = Area3D.new()
    exit_area.name = "ExitArea"
    exit_area.position = exit_world_position + Vector3(0.0, 1.05, 0.0)
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(cell_size * 0.82, 2.10, cell_size * 0.82)
    var col: CollisionShape3D = CollisionShape3D.new()
    col.shape = shape
    exit_area.add_child(col)
    add_child(exit_area)

    var door: MeshInstance3D = MeshInstance3D.new()
    door.name = "GlowingExitDoor"
    var dm: BoxMesh = BoxMesh.new()
    dm.size = Vector3(cell_size * 0.72, 2.25, 0.12)
    door.mesh = dm
    door.material_override = _exit_material
    door.position = exit_world_position + Vector3(0.0, 1.10, 0.0)
    add_child(door)

    var dl: OmniLight3D = OmniLight3D.new()
    dl.name = "ExitDoorGlow"
    dl.position = exit_world_position + Vector3(0.0, 1.35, 0.0)
    dl.light_color = Color(0.38, 1.0, 0.78, 1.0)
    dl.light_energy = 1.9
    dl.omni_range = 8.0
    dl.shadow_enabled = false
    add_child(dl)

# ---------------------------------------------------------------- materyaller

func _create_materials() -> void:
    _wall_material = _make_pbr("wall_yellow_dirty", Color(1.0, 0.99, 0.95, 1.0), 0.0, 0.96, Vector3(3.0, 2.2, 1.0), true, true)
    _floor_material = _make_pbr("carpet_old_dirty", Color(1.0, 0.99, 0.95, 1.0), 0.0, 0.95, Vector3(8.0, 8.0, 1.0), true, true)
    _ceiling_material = _make_pbr("ceiling", Color(1.0, 0.98, 0.92, 1.0), 0.0, 0.85, Vector3(2.0, 2.0, 1.0), true)
    _metal_material = _make_pbr("metal", Color(0.86, 0.87, 0.90, 1.0), 0.85, 0.5, Vector3(1.0, 1.0, 1.0), true, true)
    _concrete_material = _make_pbr("concrete", Color(0.93, 0.91, 0.86, 1.0), 0.0, 0.82, Vector3(1.0, 1.0, 1.0), true, true)
    # Havuz zemini: beyaz fayans (PolyHaven). Vent/ızgara: paslı metal grate (PolyHaven).
    _tile_material = _make_pbr("tile", Color(0.96, 0.97, 0.98, 1.0), 0.0, 0.4, Vector3(2.0, 2.0, 1.0), true, true)
    _grate_material = _make_pbr("grate", Color(0.7, 0.68, 0.64, 1.0), 0.6, 0.7, Vector3(1.0, 1.0, 1.0), true, true)

    _trim_material = _make_flat(Color(0.40, 0.33, 0.18, 1.0), 0.7)
    _ramp_material = _make_pbr("concrete", Color(0.88, 0.86, 0.81, 1.0), 0.0, 0.85, Vector3(1.0, 1.0, 1.0), false)
    var grid_mat: StandardMaterial3D = _make_flat(Color(0.11, 0.11, 0.12, 1.0), 0.5)
    grid_mat.metallic = 0.6
    _ceiling_grid_material = grid_mat

    var exit_mat: StandardMaterial3D = StandardMaterial3D.new()
    exit_mat.albedo_color = Color(0.25, 0.86, 0.64, 1.0)
    exit_mat.roughness = 0.42
    exit_mat.emission_enabled = true
    exit_mat.emission = Color(0.15, 1.0, 0.68, 1.0)
    exit_mat.emission_energy_multiplier = 2.7
    _exit_material = exit_mat

    var emissive: StandardMaterial3D = StandardMaterial3D.new()
    emissive.albedo_color = Color(1.0, 0.98, 0.90, 1.0)
    emissive.roughness = 0.18
    emissive.emission_enabled = true
    emissive.emission = Color(1.0, 0.95, 0.72, 1.0)
    emissive.emission_energy_multiplier = 4.6
    _emissive_material = emissive

func _make_pbr(set_name: String, tint: Color, metallic_value: float, rough_value: float, uv_scale: Vector3, use_normal: bool, use_roughness: bool = false) -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = tint
    var albedo: Texture2D = _load_tex("res://textures/%s_albedo.png" % set_name)
    if albedo != null:
        m.albedo_texture = albedo
    if use_normal:
        var normal: Texture2D = _load_tex("res://textures/%s_normal.png" % set_name)
        if normal != null:
            m.normal_enabled = true
            m.normal_texture = normal
            m.normal_scale = 1.0
    # PolyHaven PBR pürüzlülük haritası (varsa) → gerçekçi yüzey parlaklığı
    if use_roughness:
        var rough_tex: Texture2D = _load_tex("res://textures/%s_roughness.png" % set_name)
        if rough_tex != null:
            m.roughness_texture = rough_tex
            m.roughness = 1.0
        else:
            m.roughness = rough_value
    else:
        m.roughness = rough_value
    m.metallic = metallic_value
    m.uv1_scale = uv_scale
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    m.texture_repeat = true
    return m

func _load_tex(path: String) -> Texture2D:
    if not ResourceLoader.exists(path):
        return null
    var res: Resource = load(path)
    if res is Texture2D:
        return res as Texture2D
    return null

func _make_flat(color: Color, roughness: float) -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = 0.0
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return m

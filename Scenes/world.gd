extends Node2D

const terrain_source_trees := 0
const terrain_source_tallgrass:= 1
const terrain_source_water := 2
const terrain_source_mountain := 3
const terrain_source_fence := 4
const terrain_source_grass := 0
const terrain_source_centerline := 1

@export var MapSize := Vector2i(201, 100)
@export var map_vision_metadata = []
@export var map_movement_metadata = []

var rng = RandomNumberGenerator.new()
var current_player_id = 0
var pathfinding = AStarGrid2D.new()
var active_team := 1
var fog_state_team1: Array = []
var fog_state_team2: Array = []

func _ready() -> void:
	SignalBus.player_selected.connect(_on_player_selected)
	SignalBus.player_moved.connect(_on_player_moved)
	SignalBus.player_stats_updated.connect(_on_player_stats_updated)
	SignalBus.player_set_stance.connect(_on_player_stance_updated)
	SignalBus.map_save.connect(_on_map_save)
	SignalBus.map_load.connect(_on_map_load)
	SignalBus.turn_end.connect(end_turn)
	_setup_black_fog_shader()

	#if FileAccess.file_exists("user://default.map"):
	#	SignalBus.map_load.emit("default.map")
	#else:
	_initialize_new_game()

func _setup_black_fog_shader() -> void:
	var shader = Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(0.0, 0.0, 0.0, 1.0); }"
	var mat = ShaderMaterial.new()
	mat.shader = shader
	$FogOfWar.material = mat

func _initialize_new_game() -> void:
	build_map()
	build_players()
	build_flags()
	_setup_hud()
	update_map_metadata()
	_initialize_fog_states()
	_initialize_player_visibility()
	update_fog_layer()
	update_pathfinding_data()

func _setup_hud() -> void:
	for child in get_children():
		if child.scene_file_path.contains("hud.tscn"):
			return
	var hud = preload("res://Scenes/hud.tscn")
	var hud_instance = hud.instantiate()
	add_child(hud_instance)
	hud_instance.scale.x = Globals.UI_SCALE
	hud_instance.scale.y = Globals.UI_SCALE

func _generate_terrain_blobs(terrain_index: int, num_blobs: int, min_radius: float, max_radius: float, priority_skip: Array) -> void:
	for _i in num_blobs:
		var cx = rng.randi_range(1, MapSize.x - 2)
		var cy = rng.randi_range(1, MapSize.y - 2)
		var radius = rng.randf_range(min_radius, max_radius)
		var cells: Array[Vector2i] = []
		var ir = int(ceil(radius))
		for dx in range(-ir, ir + 1):
			for dy in range(-ir, ir + 1):
				var nx = cx + dx
				var ny = cy + dy
				if nx <= 0 or nx >= MapSize.x - 1 or ny <= 0 or ny >= MapSize.y - 1:
					continue
				var dist = sqrt(float(dx * dx + dy * dy))
				var t = clampf(dist / radius, 0.0, 1.0)
				var probability = clampf(1.0 - (t * t) + rng.randf_range(-0.08, 0.08), 0.0, 1.0)
				if rng.randf() < probability:
					var pos = Vector2i(nx, ny)
					var existing = $GroundFeatures.get_cell_tile_data(pos)
					if existing and existing.terrain in priority_skip:
						continue
					cells.append(pos)
		if cells.size() > 0:
			$GroundFeatures.set_cells_terrain_connect(cells, 0, terrain_index)

func _generate_water_blobs(num_blobs: int, min_radius: float, max_radius: float) -> void:
	for _i in num_blobs:
		var cx = rng.randi_range(1, MapSize.x - 2)
		var cy = rng.randi_range(1, MapSize.y - 2)
		var base_radius = rng.randf_range(min_radius, max_radius)
		var freq1 = rng.randf_range(2.0, 5.0)
		var freq2 = rng.randf_range(2.0, 4.0)
		var phase1 = rng.randf_range(0.0, TAU)
		var phase2 = rng.randf_range(0.0, TAU)
		var amp = rng.randf_range(0.08, 0.18)
		var cells: Array[Vector2i] = []
		var ir = int(ceil(base_radius * 1.25))
		for dx in range(-ir, ir + 1):
			for dy in range(-ir, ir + 1):
				var nx = cx + dx
				var ny = cy + dy
				if nx <= 0 or nx >= MapSize.x - 1 or ny <= 0 or ny >= MapSize.y - 1:
					continue
				var dist = sqrt(float(dx * dx + dy * dy))
				var angle = atan2(float(dy), float(dx))
				var effective_radius = base_radius * (1.0 + amp * (sin(angle * freq1 + phase1) + cos(angle * freq2 + phase2)) * 0.5)
				if dist <= effective_radius:
					var pos = Vector2i(nx, ny)
					var existing = $GroundFeatures.get_cell_tile_data(pos)
					if existing:
						if existing.get_custom_data("Movement_Reduce") >= 1000:
							continue
					cells.append(pos)
		if cells.size() > 0:
			$GroundFeatures.set_cells_terrain_connect(cells, 0, terrain_source_water)

func build_map() -> void:
	for x in MapSize.x:
		for y in MapSize.y:
			var cell = Vector2i(x, y)
			if x == int(MapSize.x / 2):
				$Ground.set_cell(cell, terrain_source_centerline, Vector2i(0, 0), 0)
			else:
				$Ground.set_cell(cell, terrain_source_grass, Vector2i(0, 0), 0)

	var border_cells: Array[Vector2i] = []
	for x in MapSize.x:
		border_cells.append(Vector2i(x, 0))
		border_cells.append(Vector2i(x, MapSize.y - 1))
	for y in range(1, MapSize.y - 1):
		border_cells.append(Vector2i(0, y))
		border_cells.append(Vector2i(MapSize.x - 1, y))
	$GroundFeatures.set_cells_terrain_connect(border_cells, 0, terrain_source_fence)

	_generate_water_blobs(rng.randi_range(3, 5), 3.0, 12.0)
	_generate_terrain_blobs(terrain_source_trees, rng.randi_range(88, 125), 3.0, 15.0, [terrain_source_fence, terrain_source_water])
	_generate_terrain_blobs(terrain_source_tallgrass, rng.randi_range(50, 70), 2.0, 10.0, [terrain_source_fence, terrain_source_water, terrain_source_trees])
	_generate_terrain_blobs(terrain_source_mountain, rng.randi_range(12, 20), 4.0, 20.0, [terrain_source_fence, terrain_source_water, terrain_source_trees, terrain_source_tallgrass])

func build_players() -> void:
	var team1_x = 95 * Globals.CELL_SIZE
	var team2_x = 105 * Globals.CELL_SIZE
	for i in Globals.PlayersPerTeam:
		var y_pixel = int((float(i + 1) / float(Globals.PlayersPerTeam + 1)) * MapSize.y) * Globals.CELL_SIZE
		var vis = int(Globals.Max_Vision * rng.randf_range(0.2, 1))
		var mov = int(Globals.Max_Movement * rng.randf_range(0.2, 1))
		var str = int(Globals.Max_Strength * rng.randf_range(0.2, 1))
		var slth = int(Globals.Max_Stealth * rng.randf_range(0.2, 1))
		create_player(1, i + 1, team1_x, y_pixel, vis, mov, str, slth)
		vis = int(Globals.Max_Vision * rng.randf_range(0.2, 1))
		mov = int(Globals.Max_Movement * rng.randf_range(0.2, 1))
		str = int(Globals.Max_Strength * rng.randf_range(0.2, 1))
		slth = int(Globals.Max_Stealth * rng.randf_range(0.2, 1))
		create_player(2, i + 6, team2_x, y_pixel, vis, mov, str, slth)

func build_flags() -> void:
	_spawn_flag(1, 1, 24)
	_spawn_flag(2, 176, 199)

func _spawn_flag(team: int, x_min: int, x_max: int) -> void:
	var flag_scene = preload("res://Scenes/flag.tscn")
	for _attempt in 100:
		var cx = rng.randi_range(x_min, x_max)
		var cy = rng.randi_range(1, MapSize.y - 2)
		var cell_data = $GroundFeatures.get_cell_tile_data(Vector2i(cx, cy))
		if cell_data:
			var mv = cell_data.get_custom_data("Movement_Reduce")
			if mv >= 1000:
				continue
		var flag = flag_scene.instantiate()
		flag.team_id = team
		flag.position = Vector2(cx * Globals.CELL_SIZE, cy * Globals.CELL_SIZE)
		add_child(flag)
		return

func create_player(team:int, id:int,x: float, y:float, vision:int, movement:int, strength: int, stealth:int) -> void:
	var player = preload("res://Scenes/player.tscn")
	var instance = player.instantiate()
	add_child(instance)
	instance.get_node("Camera").setup_limits(MapSize.x * Globals.CELL_SIZE, MapSize.y * Globals.CELL_SIZE)
	instance.team_id = team
	instance.player_id = id
	instance.position.x = x
	instance.position.y = y
	instance.max_vision_range = vision
	instance.max_movement_range = movement
	instance.max_strength = strength
	instance.max_stealth = stealth
	instance.movement_points_remaining = movement

func get_current_player_object() -> Node:
	for player in self.get_children():
		if player.scene_file_path.contains("player.tscn"):
			if player.player_id == current_player_id:
				return player
	return null

func update_pathfinding_data():
	var tile_size = Vector2i(Globals.CELL_SIZE, Globals.CELL_SIZE)
	var map_rect = Rect2i(0, 0, MapSize.x, MapSize.y)
	pathfinding.region = map_rect
	pathfinding.cell_size = tile_size
	pathfinding.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	pathfinding.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	pathfinding.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	pathfinding.update()

	for x in MapSize.x:
		for y in MapSize.y:
			var pos = Vector2i(x, y)
			pathfinding.set_point_weight_scale(pos, map_movement_metadata[x][y])

	for x in MapSize.x:
		for y in MapSize.y:
			var pos = Vector2i(x, y)
			var cell_data = $GroundFeatures.get_cell_tile_data(pos)
			if cell_data:
				var mv = cell_data.get_custom_data("Movement_Reduce")
				if mv >= 1000:
					pathfinding.set_point_solid(pos, true)

	for x in MapSize.x:
		pathfinding.set_point_solid(Vector2i(x, 0), true)
		pathfinding.set_point_solid(Vector2i(x, MapSize.y - 1), true)
	for y in MapSize.y:
		pathfinding.set_point_solid(Vector2i(0, y), true)
		pathfinding.set_point_solid(Vector2i(MapSize.x - 1, y), true)

func update_fog_layer() -> void:
	var fog_state = fog_state_team1 if active_team == 1 else fog_state_team2

	for x in range(MapSize.x):
		for y in range(MapSize.y):
			if fog_state[x][y] == 3:
				fog_state[x][y] = 2

	for player in get_children():
		if player.scene_file_path.contains("player.tscn") and player.team_id == active_team:
			var half = player.visible_cells.get_size().x / 2
			for x in range(player.visible_cells.get_size().x):
				for y in range(player.visible_cells.get_size().y):
					if player.visible_cells.get_bit(x, y):
						var cell_offset = Vector2i(
							int(player.position.x / Globals.CELL_SIZE) + x - half,
							int(player.position.y / Globals.CELL_SIZE) + y - half
						)
						if cell_offset.x >= 0 and cell_offset.x < MapSize.x and cell_offset.y >= 0 and cell_offset.y < MapSize.y:
							fog_state[cell_offset.x][cell_offset.y] = 3

	for child in get_children():
		if child.scene_file_path.contains("flag.tscn") and child.team_id == active_team:
			var fx = int(child.position.x / Globals.CELL_SIZE)
			var fy = int(child.position.y / Globals.CELL_SIZE)
			if fx >= 0 and fx < MapSize.x and fy >= 0 and fy < MapSize.y:
				fog_state[fx][fy] = 3

	for x in range(MapSize.x):
		for y in range(MapSize.y):
			var cell = Vector2i(x, y)
			var state = fog_state[x][y]
			if state == 1:
				$FogOfWar.set_cell(cell, 1, Vector2i(0, 0), 0)
				$FogOfWar2.erase_cell(cell)
			elif state == 2:
				$FogOfWar.erase_cell(cell)
				$FogOfWar2.set_cell(cell, 1, Vector2i(0, 0), 0)
			else:
				$FogOfWar.erase_cell(cell)
				$FogOfWar2.erase_cell(cell)

func _initialize_fog_states() -> void:
	fog_state_team1.clear()
	fog_state_team1.resize(MapSize.x)
	fog_state_team2.clear()
	fog_state_team2.resize(MapSize.x)
	var center = int(MapSize.x / 2)
	for x in range(MapSize.x):
		fog_state_team1[x] = []
		fog_state_team1[x].resize(MapSize.y)
		fog_state_team2[x] = []
		fog_state_team2[x].resize(MapSize.y)
		for y in range(MapSize.y):
			fog_state_team1[x][y] = 2 if x < center else 1
			fog_state_team2[x][y] = 2 if x > center else 1

func _initialize_player_visibility() -> void:
	for player in get_children():
		if player.scene_file_path.contains("player.tscn"):
			player.update_visible_cells()

func update_map_metadata() -> void:
	map_vision_metadata.clear()
	map_vision_metadata.resize(MapSize.x)
	map_movement_metadata.clear()
	map_movement_metadata.resize(MapSize.x)

	for x in range(MapSize.x):
		map_vision_metadata[x] = []
		map_vision_metadata[x].resize(MapSize.y)
		map_movement_metadata[x] = []
		map_movement_metadata[x].resize(MapSize.y)

		for y in range(MapSize.y):
			var cell_data = $GroundFeatures.get_cell_tile_data(Vector2i(x, y))
			if cell_data:
				map_vision_metadata[x][y] = cell_data.get_custom_data("Vision_Reduce")
				map_movement_metadata[x][y] = cell_data.get_custom_data("Movement_Reduce")
			else:
				map_vision_metadata[x][y] = 1
				map_movement_metadata[x][y] = 1

func get_movement_path(source: Vector2i, dest: Vector2i) -> Array[Vector2]:
	var tile_source = $GroundFeatures.local_to_map(source)
	var tile_dest = $GroundFeatures.local_to_map(dest)
	var path_as_cells = pathfinding.get_id_path(tile_source, tile_dest, true).slice(1)

	var path_as_points: Array[Vector2] = []
	for p in path_as_cells:
		path_as_points.append($GroundFeatures.map_to_local(p))

	return path_as_points

func _on_player_selected(player_id: int) -> void:
	for player in get_children():
		if player.scene_file_path.contains("player.tscn") and player.player_id == player_id:
			if player.team_id != active_team:
				player.deselect_player()
				return
	current_player_id = player_id
	for player in get_children():
		if player.scene_file_path.contains("player.tscn"):
			if player.player_id != player_id:
				player.deselect_player()

func _on_player_moved(pos: Vector2) -> void:
	update_fog_layer()
	_check_auto_end_turn()

func _check_auto_end_turn() -> void:
	for player in get_children():
		if player.scene_file_path.contains("player.tscn"):
			if player.team_id == active_team and player.movement_points_remaining > 0:
				return
	end_turn()

func end_turn() -> void:
	active_team = 2 if active_team == 1 else 1
	for player in get_children():
		if player.scene_file_path.contains("player.tscn"):
			if player.team_id == active_team:
				player.movement_points_remaining = player.max_movement_range
			player.deselect_player()
	current_player_id = 0
	SignalBus.turn_changed.emit(active_team)
	update_fog_layer()

func _on_player_stats_updated(vision:float, movement:float, strength:float, stealth:float) -> void:
	$HUD.vision = vision
	$HUD.movement = movement
	$HUD.strength = strength
	$HUD.stealth = stealth

func _on_player_stance_updated(stance:Globals.Stance) -> void:
	var player = get_current_player_object()
	if player:
		player.set_stance(stance)

func _on_map_save() -> void:
	map_data_save()

func _on_map_load(filename: String) -> void:
	map_data_load(filename)

func map_data_save() -> void:
	var terrain_data = []
	for x in range(MapSize.x):
		for y in range(MapSize.y):
			var cell_data = $GroundFeatures.get_cell_tile_data(Vector2i(x, y))
			if cell_data:
				terrain_data.append({
					"x": x,
					"y": y,
					"type": cell_data.terrain,
					"texture_x": cell_data.texture_origin.x,
					"texture_y": cell_data.texture_origin.y,
				})

	var player_data = []
	for player in self.get_children():
		if player.scene_file_path.contains("player.tscn"):
			player_data.append({
				"id" : player.player_id,
				"team" : player.team_id,
				"x" : player.position.x,
				"y" : player.position.y,
				"vision" : player.max_vision_range,
				"movement" : player.max_movement_range,
				"strength" : player.max_strength,
				"stealth" : player.max_stealth
			})

	var flag_data = []
	for child in get_children():
		if child.scene_file_path.contains("flag.tscn"):
			flag_data.append({
				"team": child.team_id,
				"x": child.position.x,
				"y": child.position.y
			})
	var map_data = {
		"width": MapSize.x,
		"height": MapSize.y,
		"tiles": terrain_data,
		"players": player_data,
		"flags": flag_data,
		"fog1": fog_state_team1,
		"fog2": fog_state_team2,
	}
	var output_file = FileAccess.open_encrypted_with_pass("user://default.map", FileAccess.WRITE, Globals.map_file_password)
	var map_data_json = JSON.stringify(map_data)
	output_file.store_line(map_data_json)

func map_data_load(filename: String) -> void:
	var input_file = FileAccess.open_encrypted_with_pass("user://" + filename, FileAccess.READ, Globals.map_file_password)
	var map_data = JSON.parse_string(input_file.get_as_text())

	MapSize = Vector2i(map_data.width, map_data.height)

	for x in MapSize.x:
		for y in MapSize.y:
			var cell = Vector2i(x, y)
			if x == int(MapSize.x / 2):
				$Ground.set_cell(cell, terrain_source_centerline, Vector2i(0, 0), 0)
			else:
				$Ground.set_cell(cell, terrain_source_grass, Vector2i(0, 0), 0)

	for tile in map_data.tiles:
		var cell_loc = Vector2i(tile.x, tile.y)
		var text_loc = Vector2i(tile.texture_x, tile.texture_y)
		$GroundFeatures.set_cell(cell_loc, tile.type, text_loc, 0)

	for p in map_data.players:
		create_player(p.team, p.id, p.x, p.y, p.vision, p.movement, p.strength, p.stealth)

	if map_data.has("flags"):
		for f in map_data.flags:
			var flag_scene = preload("res://Scenes/flag.tscn")
			var flag = flag_scene.instantiate()
			flag.team_id = f.team
			flag.position = Vector2(f.x, f.y)
			add_child(flag)

	_setup_hud()
	update_map_metadata()
	_initialize_fog_states()
	if map_data.has("fog1"):
		fog_state_team1 = map_data.fog1
	if map_data.has("fog2"):
		fog_state_team2 = map_data.fog2
	update_fog_layer()
	update_pathfinding_data()

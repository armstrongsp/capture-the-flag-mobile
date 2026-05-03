extends Node2D

const terrain_source_trees := 0
const terrain_source_tallgrass:= 1
const terrain_source_water := 2
const terrain_source_grass := 0
const terrain_source_centerline := 1

@export var MapSize := Vector2i(100, 100)
@export var map_vision_metadata = []
@export var map_movement_metadata = []

var rng = RandomNumberGenerator.new()
var current_player_id = 0
var pathfinding = AStarGrid2D.new()

func _ready() -> void:
	SignalBus.player_selected.connect(_on_player_selected)
	SignalBus.player_moved.connect(_on_player_moved)
	SignalBus.player_stats_updated.connect(_on_player_stats_updated)
	SignalBus.player_set_stance.connect(_on_player_stance_updated)
	
	SignalBus.map_save.connect(_on_map_save)
	SignalBus.map_load.connect(_on_map_load)
	
	SignalBus.map_load.emit("default.map")
	
	
func build_map() -> void:
	for x in MapSize.x:
		for y in MapSize.y:
			var cell = Vector2i(x, y) 
			if x == int(MapSize.x / 2):
				$Ground.set_cell(cell, terrain_source_centerline, Vector2i(0, 0), 0)
			else:
				$Ground.set_cell(cell, terrain_source_grass, Vector2i(0, 0), 0)

func build_players() -> void:
	for i in Globals.PlayersPerTeam:
		var vis = int(Globals.Max_Vision * rng.randf_range(0.2, 1))
		var mov = int(Globals.Max_Movement * rng.randf_range(0.2, 1))
		var str = int(Globals.Max_Strength * rng.randf_range(0.2, 1))
		var slth = int(Globals.Max_Stealth * rng.randf_range(0.2, 1))
		create_player(1, i + 1, rng.randf_range(300, 500), rng.randf_range(300, 500), vis, mov, str, slth)

func create_player(team:int, id:int,x: float, y:float, vision:int, movement:int, strength: int, stealth:int) -> void:
	var player = preload("res://Scenes/player.tscn")
	var instance = player.instantiate()
	add_child(instance)
	instance.team_id = team
	instance.player_id = id
	instance.position.x = x
	instance.position.y = y
	instance.max_vision_range = vision
	instance.max_movement_range = movement
	instance.max_strength = strength
	instance.max_stealth = stealth
	
	
	
	
	
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
			
func update_fog_layer() -> void:
	for x in range(MapSize.x):
		for y in range(MapSize.y):
			$FogOfWar.set_cell(Vector2i(x, y), 1, Vector2i(0, 0), 0)
	
	for player in self.get_children():
		if player.scene_file_path.contains("player.tscn"):
			for x in range(player.visible_cells.get_size().x):
				for y in range(player.visible_cells.get_size().y):
					if (player.visible_cells.get_bit(x, y)):
						var posOffset = Vector2(x - player.max_vision_range, y - player.max_vision_range)
						$FogOfWar.erase_cell((player.position / Globals.CELL_SIZE) + posOffset)

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
	current_player_id = player_id
	for player in self.get_children():
		if player.scene_file_path.contains("player.tscn"):
			if player.player_id != player_id:
				player.deselect_player()
				
func _on_player_moved(pos: Vector2) -> void:
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
			
	var map_data = {
		"width": MapSize.x,
		"height": MapSize.y,
		"tiles": terrain_data,
		"players": player_data
	}
	var output_file = FileAccess.open_encrypted_with_pass("user://default.map", FileAccess.WRITE, Globals.map_file_password)
	var map_data_json = JSON.stringify(map_data)
	output_file.store_line(map_data_json)
	
func map_data_load(filename: String) -> void:
	var input_file = FileAccess.open_encrypted_with_pass("user://" + filename, FileAccess.READ, Globals.map_file_password)
	var map_data = JSON.parse_string(input_file.get_as_text())
	
	MapSize = Vector2i(map_data.width, map_data.height)
	for tile in map_data.tiles:
		var cell_loc = Vector2i(tile.x, tile.y) 
		var text_loc = Vector2i(tile.texture_x, tile.texture_y) 
		$GroundFeatures.set_cell(cell_loc, tile.type, text_loc, 0)
	
	for x in MapSize.x:
		for y in MapSize.y:
			var cell = Vector2i(x, y) 
			if x == int(MapSize.x / 2):
				$Ground.set_cell(cell, terrain_source_centerline, Vector2i(0, 0), 0)
			else:
				$Ground.set_cell(cell, terrain_source_grass, Vector2i(0, 0), 0)
			
	for p in map_data.players:
		create_player(p.team, p.id, p.x, p.y, p.vision, p.movement, p.strength, p.stealth)
	
	var hud = preload("res://Scenes/hud.tscn")
	var hud_instance = hud.instantiate()
	add_child(hud_instance)
	hud_instance.scale.x = Globals.UI_SCALE
	hud_instance.scale.y = Globals.UI_SCALE
	
	update_map_metadata()
	update_fog_layer()
	update_pathfinding_data()
	

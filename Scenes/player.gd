extends CharacterBody2D

const BASE_MOVE_SPEED := 200

@export var player_id := -1
@export var team_id := 1
@export var is_selected := false
@export var visible_cells: BitMap

#player stats
@export var max_vision_range : int = 15 :
	set(value):
		max_vision_range = value
		visible_cells = BitMap.new()
		visible_cells.create(Vector2i(value * 3, value * 3))
@export var max_movement_range : int = 500
@export var max_strength : int = 100
@export var max_stealth : int = 100

var stance := Globals.Stance.Running
var movement_points_remaining := 0
var rng = RandomNumberGenerator.new()
var last_pos = Vector2(0, 0)
var cur_path: Array[Vector2]

func _init() -> void:
	visible_cells = BitMap.new()
	visible_cells.create(Vector2i(max_vision_range * 3, max_vision_range * 3))

func _physics_process(delta: float) -> void:
	if not is_selected:
		$SelectedBox.visible = false 
		$OutOfMovementBox.visible = false
	else:
		if movement_points_remaining <= 0:
			$SelectedBox.visible = false
			$OutOfMovementBox.visible = true
		else:
			$SelectedBox.visible = true 
			$OutOfMovementBox.visible = false
			
			if not cur_path.is_empty():
				position = position.move_toward(cur_path.front(), 5)
				
				if position == cur_path.front():
					cur_path.pop_front()
		
			if position != last_pos:
				last_pos = position
				
				var check_pos = floor((position / Globals.CELL_SIZE))
				var cell_movement_subtract = self.get_parent().map_movement_metadata[check_pos.x][check_pos.y]
				cell_movement_subtract = int(float(cell_movement_subtract) * Globals.StanceMods[stance].movement)
				
				if cell_movement_subtract <= 0:
					cell_movement_subtract = 1
					
				movement_points_remaining -= cell_movement_subtract
				
				if movement_points_remaining < 0:
					movement_points_remaining = 0
					
				update_visible_cells()
				SignalBus.player_moved.emit(position)
				trigger_stats_update()
			

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action_released("select"):
		is_selected = true
		SignalBus.player_selected.emit(player_id)
		SignalBus.player_set_stance.emit(stance)
		trigger_stats_update()
		$Camera.make_active_camera()

func _unhandled_input(event: InputEvent) -> void:
	if is_selected && event.is_action_released("select"):
		cur_path = self.get_parent().get_movement_path(position, get_global_mouse_position())

		
func deselect_player() -> void:
	is_selected = false
	$SelectedBox.visible = false 
	cur_path.clear()
	
func trigger_stats_update() -> void:
	var vision_perc = float(max_vision_range) / float(Globals.Max_Vision)
	var movement_perc = float(movement_points_remaining) / float(max_movement_range)
	var strength_perc = float(max_strength) / float(Globals.Max_Strength)
	var stealth_perc = float(max_stealth) / float(Globals.Max_Stealth)
	SignalBus.player_stats_updated.emit(vision_perc, movement_perc, strength_perc, stealth_perc)
	
func set_stance(new_stance: Globals.Stance) -> void:
	stance = new_stance
	match new_stance:
		Globals.Stance.Scouting:
			$AnimatedSprite2D.play("scouting")
		Globals.Stance.Running:
			$AnimatedSprite2D.play("running")
		Globals.Stance.Walking:
			$AnimatedSprite2D.play("walking")
		Globals.Stance.Crawling:
			$AnimatedSprite2D.play("crawling")
		Globals.Stance.Prone:
			$AnimatedSprite2D.play("prone")
	update_visible_cells()
	SignalBus.player_moved.emit(position)
	
func update_visible_cells() -> void:
	var bitmap_size = max_vision_range * 3
	var center = bitmap_size / 2
	for x in range(0, bitmap_size):
		for y in range(0, bitmap_size):
			visible_cells.set_bit(x, y, false)

	var parent = get_parent()
	var player_cell_x = int(position.x / Globals.CELL_SIZE)
	var player_cell_y = int(position.y / Globals.CELL_SIZE)
	var player_terrain_vision = parent.map_vision_metadata[player_cell_x][player_cell_y]
	# negative Vision_Reduce means "mountain" — grants 1.5x vision range
	var effective_range = int(max_vision_range * 1.5) if player_terrain_vision < 0 else max_vision_range

	for angle in range(0, 360, 2):
		var range_remaining = effective_range
		for dist in range(0, effective_range):
			var destOffset = Vector2(cos(angle * PI / 180), sin(angle * PI / 180)) * dist
			var check_x = player_cell_x + int(destOffset.x)
			var check_y = player_cell_y + int(destOffset.y)
			if check_x < 0 or check_x >= parent.MapSize.x or check_y < 0 or check_y >= parent.MapSize.y:
				break
			var cell_vision = parent.map_vision_metadata[check_x][check_y]
			if cell_vision < 0:
				cell_vision = 0  # mountains don't block LOS when looking through them
			range_remaining -= int(float(cell_vision) * Globals.StanceMods[stance].vision)
			if range_remaining <= 0:
				break
			var bit_x = int(destOffset.x) + center
			var bit_y = int(destOffset.y) + center
			if bit_x >= 0 and bit_x < bitmap_size and bit_y >= 0 and bit_y < bitmap_size:
				visible_cells.set_bit(bit_x, bit_y, true)
			

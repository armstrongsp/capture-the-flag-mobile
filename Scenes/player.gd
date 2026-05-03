extends CharacterBody2D

const BASE_MOVE_SPEED := 200

@export var player_id := -1
@export var team_id := 1
@export var is_selected := false
@export var visible_cells: BitMap

#player stats
@export var max_vision_range : int = 15
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
	visible_cells.create(Vector2i(max_vision_range * 2, max_vision_range * 2))

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
		movement_points_remaining = max_movement_range
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
	for x in range(0, max_vision_range * 2):
		for y in range(0, max_vision_range * 2):
			visible_cells.set_bit(x, y, false)
	
	for angle in range(0, 360, 2):
		var range_remaining = max_vision_range	
		for dist in range(0, max_vision_range):
			var destOffset = Vector2(cos(angle * PI / 180), sin(angle * PI / 180)) * dist
			var check_pos = (position / Globals.CELL_SIZE) + destOffset
			var cell_vision_subtract = self.get_parent().map_vision_metadata[check_pos.x][check_pos.y]
			
			range_remaining -= int(float(cell_vision_subtract) * Globals.StanceMods[stance].vision)
			
			if range_remaining <= 0:
				break
			else:
				visible_cells.set_bit(destOffset.x + max_vision_range, destOffset.y + max_vision_range, true)
			

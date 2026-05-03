extends CanvasLayer

@export var movement : float = 1
@export var vision : float = 1
@export var strength : float = 1
@export var stealth : float = 1

var bar_movement_max_width : float = 0.0
var bar_vision_max_width : float = 0.0
var bar_strength_max_width : float = 0.0
var bar_stealth_max_width : float = 0.0

func _ready() -> void:
	bar_movement_max_width = $PlayerPanel/MovementContainer/MovementBar.transform.x[0]
	bar_vision_max_width = $PlayerPanel/VisionContainer/VisionBar.transform.x[0]
	bar_strength_max_width = $PlayerPanel/StrengthContainer/StrengthBar.transform.x[0]
	bar_stealth_max_width = $PlayerPanel/StealthContainer/StealthBar.transform.x[0]

	$SaveButton.pressed.connect(_on_save_clicked)
	$LoadButton.pressed.connect(_on_load_clicked)
	$EndTurnButton.pressed.connect(_on_end_turn_pressed)
	SignalBus.player_set_stance.connect(_on_player_stance_updated)
	SignalBus.turn_changed.connect(_on_turn_changed)
	call_deferred("_position_right_elements")

func _position_right_elements() -> void:
	var local_w = get_viewport().get_visible_rect().size.x / scale.x
	var btn_right = local_w - 30
	var btn_left = btn_right - 58
	$EndTurnButton.offset_left = btn_left
	$EndTurnButton.offset_right = btn_right
	$EndTurnButton.offset_top = 2
	$EndTurnButton.offset_bottom = 14
	$TurnLabel.offset_right = btn_left - 7
	$TurnLabel.offset_left = btn_left - 152
	$TurnLabel.offset_top = 2
	$TurnLabel.offset_bottom = 14
	$TurnLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	
func _physics_process(delta: float) -> void:
	$PlayerPanel/MovementContainer/MovementBar.transform.x[0] = bar_movement_max_width * movement
	$PlayerPanel/VisionContainer/VisionBar.transform.x[0] = bar_vision_max_width * vision
	$PlayerPanel/StrengthContainer/StrengthBar.transform.x[0] = bar_strength_max_width * strength
	$PlayerPanel/StealthContainer/StealthBar.transform.x[0] = bar_stealth_max_width * stealth
	
func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_released("select")):
		if clicked_in_sprite($Stance_Scouting): set_stance($Stance_Scouting, Globals.Stance.Scouting)
		elif clicked_in_sprite($Stance_Running): set_stance($Stance_Running, Globals.Stance.Running)
		elif clicked_in_sprite($Stance_Walking): set_stance($Stance_Walking, Globals.Stance.Walking)
		elif clicked_in_sprite($Stance_Crawling): set_stance($Stance_Crawling, Globals.Stance.Crawling)
		elif clicked_in_sprite($Stance_Prone): set_stance($Stance_Prone, Globals.Stance.Prone)
		
		
func clicked_in_sprite(sprite: Sprite2D) -> bool:
	var mouse_pos = sprite.get_global_mouse_position()
	var box = (sprite.transform * sprite.get_rect())
	if box.has_point(mouse_pos):
		return true
	return false

func set_stance(sprite: Sprite2D, stance:Globals.Stance) -> void:
	$Stance_Selected.transform = sprite.transform
	$Stance_Selected.visible = true
	SignalBus.player_set_stance.emit(stance)
	sprite.get_viewport().set_input_as_handled()

func _on_save_clicked() -> void:
	SignalBus.map_save.emit()
	
func _on_load_clicked() -> void:
	SignalBus.map_load.emit("default.map")

func _on_end_turn_pressed() -> void:
	SignalBus.turn_end.emit()

func _on_turn_changed(team_id: int) -> void:
	$TurnLabel.text = "Team " + str(team_id) + "'s Turn"
	
func _on_player_stance_updated(stance:Globals.Stance) -> void:
	var selected_sprite = $Stance_Scouting
	if stance == Globals.Stance.Scouting: selected_sprite = $Stance_Scouting
	elif stance == Globals.Stance.Running: selected_sprite = $Stance_Running
	elif stance == Globals.Stance.Walking: selected_sprite = $Stance_Walking
	elif stance == Globals.Stance.Crawling: selected_sprite = $Stance_Crawling
	elif stance == Globals.Stance.Prone: selected_sprite = $Stance_Prone
	
	$Stance_Selected.transform = selected_sprite.transform
	$Stance_Selected.visible = true
	

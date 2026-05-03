extends Node2D

@export var team_id := 1

func _ready() -> void:
	var rect = ColorRect.new()
	rect.size = Vector2(Globals.CELL_SIZE, Globals.CELL_SIZE)
	rect.position = Vector2(-Globals.CELL_SIZE / 2.0, -Globals.CELL_SIZE / 2.0)
	if team_id == 1:
		rect.color = Color.RED
	else:
		rect.color = Color.BLUE
	add_child(rect)

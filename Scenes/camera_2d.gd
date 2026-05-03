extends Node2D

const ZOOM_SPEED := 0.5

@export var CameraPos = Vector2(1, 1)
@export var CameraZoom := 1.0

var mouse_start_pos
var screen_start_position
var dragging = false

func _input(event):
	if event.is_action("zoomin"):
		if CameraZoom < 10:
			CameraZoom += ZOOM_SPEED
	elif event.is_action("zoomout"):
		if CameraZoom > 1:
			CameraZoom -= ZOOM_SPEED
	elif event.is_action("camera_pan"):
		if event.is_pressed():
			mouse_start_pos = event.position
			screen_start_position = $Camera2D.position
			dragging = true
		else:
			dragging = false
	
	if event is InputEventMouseMotion and dragging:
		CameraPos = (1 / CameraZoom) * (mouse_start_pos - event.position) + screen_start_position
	
	$Camera2D.zoom = Vector2(CameraZoom, CameraZoom)
	$Camera2D.position = CameraPos
	
func make_active_camera() -> void:
	$Camera2D.make_current()

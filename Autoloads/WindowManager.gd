extends Node

var screen_size = DisplayServer.window_get_size()
 
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	
# GameManager Keyboard Input Events
func _input(event) -> void:
	if event.is_action_pressed("fullscreen"):
		toggle_fullscreen()
	if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
		get_tree().quit()
	
func toggle_fullscreen() -> void:
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		screen_size = DisplayServer.window_get_size() 
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		screen_size = DisplayServer.window_get_size()

func mouse_pos_viewport() -> Vector2:
	return get_viewport().get_mouse_position()

func mouse_pos_cam() -> Vector2:
	return get_viewport().get_camera_2d().get_global_mouse_position()

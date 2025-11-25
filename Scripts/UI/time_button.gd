extends TextureButton
	
func _toggled(toggled_on: bool) -> void:
	get_tree().paused = toggled_on
			

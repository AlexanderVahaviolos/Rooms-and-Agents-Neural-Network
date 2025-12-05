extends TextureButton
	
func _toggled(toggled_on: bool) -> void:
	if toggled_on:
		print("Paused Simulation")
	else:
		print("Resumed Simulation")
	get_tree().paused = toggled_on
			

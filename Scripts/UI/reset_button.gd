extends TextureButton

@export var MainScene: Node2D

func _pressed() -> void:
	MainScene.reset_agents(true)

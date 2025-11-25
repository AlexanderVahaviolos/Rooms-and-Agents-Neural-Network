@tool
class_name ShadowComponent
extends Sprite2D

const shadow_texture = preload("res://Sprites/Shapes/circle.png")

func _enter_tree() -> void:
	texture = shadow_texture
	show_behind_parent = true
	self.modulate = Color.from_rgba8(15, 0, 30, 45)

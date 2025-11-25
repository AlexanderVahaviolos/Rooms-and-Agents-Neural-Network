@abstract
class_name Hazard extends Area2D

var hazard_type: int

@export var damage: int = 10
@export var knockback_force: float

@abstract
func _on_hazard_enter(body: Node2D) -> void

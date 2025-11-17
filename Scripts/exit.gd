extends Area2D
class_name Exit

@onready var exit_shape: CollisionShape2D = $ExitShape
var shape_bounds: Rect2i

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	var collision_shape: Shape2D = exit_shape.shape
	shape_bounds = collision_shape.get_rect()
	
func _on_body_entered(body: Node2D) -> void:
	body.score += 100
	print(body.name, " has completed the maze. | SCORE: ", body.score) 
	body.set_physics_process(false)
	body.visible = false

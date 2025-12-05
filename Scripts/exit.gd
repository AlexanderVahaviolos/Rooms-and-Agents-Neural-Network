extends Area2D
class_name Exit

@onready var exit_shape: CollisionShape2D = $ExitShape
var shape_bounds: Rect2i

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	var collision_shape: Shape2D = exit_shape.shape
	shape_bounds = collision_shape.get_rect()
	
func _on_body_entered(body: Node2D) -> void:
	if body is not Agent:
		return 
	
	var agent: Agent = body
	agent.score += 150
	if agent.time_alive > 0.1:
		agent.score += 120.0 / max(agent.time_alive, 5.0)
	
	print(agent.name, " has completed the room. | SCORE: ", agent.score) 
	agent.completed_flag = true
	agent.send_instance.emit(agent)

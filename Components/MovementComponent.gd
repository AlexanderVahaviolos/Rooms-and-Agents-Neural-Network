extends Node
class_name MovementComponent

@export var direction := Vector2.ZERO
@export var acceleration := 150.0
@export var decceleration := 250.0
@export var max_velocity := Vector2(50.0, 45.0)

var velocity := Vector2.ZERO

# Should always be called from _physics_process
func accelerate(delta: float) -> void:	
	velocity = velocity.move_toward(direction * max_velocity, acceleration * delta).round()
	velocity.x = clamp(velocity.x, -max_velocity.x, max_velocity.x)
	velocity.y = clamp(velocity.y, -max_velocity.y, max_velocity.y)

func decelerate(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, decceleration * delta).round()
		

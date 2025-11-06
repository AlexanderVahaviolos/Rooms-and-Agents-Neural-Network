extends CharacterBody2D

@export var movement_component: MovementComponent
var direction: Vector2 = Vector2.ZERO

@onready var raycast: RayCast2D = $RayCast2D

func _ready() -> void:
	pass
	
func _physics_process(delta: float) -> void:
	direction = Input.get_vector("left", "right", "up", "down")
	if direction != Vector2.ZERO:
		movement_component.direction = direction
		movement_component.accelerate(delta)
	else:
		movement_component.decelerate(delta)
	
	# Apply Velocity
	#print("VELOCITY = ", owner.movement_component.velocity)
	velocity = movement_component.velocity
	
	move_and_slide()

extends State

func enter(entity: Node2D) -> void:
	entity.animation_player.play("move")
	
func exit(_entity: Node2D) -> void:
	pass
	
func update(entity: Node2D, _delta) -> void:
	var dir: Vector2 = Input.get_vector("left", "right", "up", "down")
	entity.movement_component.direction = dir
	if entity.velocity == Vector2.ZERO and dir == Vector2.ZERO:
		entity.state_machine.change_state("idle")
		
func physics_update(entity: Node2D, delta) -> void:
	if entity.movement_component.direction != Vector2.ZERO:
		entity.movement_component.accelerate(delta)
	else:
		entity.movement_component.decelerate(delta)
	
	entity.velocity = entity.movement_component.velocity

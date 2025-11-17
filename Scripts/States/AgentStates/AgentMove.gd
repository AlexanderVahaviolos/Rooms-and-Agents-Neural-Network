extends State

func enter(entity: Node2D) -> void:
	entity.animation_player.play("move")
	
func exit(_entity: Node2D) -> void:
	pass
	
func update(entity: Node2D, _delta) -> void:
	if entity.velocity == Vector2.ZERO:
		entity.state_machine.change_state("idle")
		
func physics_update(entity: Node2D, delta) -> void:
	var move_intent = entity.move_intent
	
	if move_intent > 0.1:
		entity.movement_component.accelerate(delta)
	elif move_intent < -0.1:
		entity.movement_component.brake(delta)
	else:
		entity.movement_component.decelerate(delta)

	entity.velocity = entity.movement_component.velocity

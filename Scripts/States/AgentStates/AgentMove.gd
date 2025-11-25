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
	
	if move_intent >= 0.0:
		entity.movement_component.accelerate(delta * max(move_intent, 0.1))
	elif move_intent:
		entity.movement_component.brake(delta * abs(move_intent))

	entity.velocity = entity.movement_component.velocity

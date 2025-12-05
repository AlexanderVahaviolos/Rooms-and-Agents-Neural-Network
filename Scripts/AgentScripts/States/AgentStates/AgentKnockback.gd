extends State

func enter(entity: Node2D) -> void:
	entity.movement_component.direction = Vector2.ZERO
	entity.movement_component.velocity = Vector2.ZERO
	entity.iframes = entity.iframes_on_hit
	entity.animation_player.play("idle")
	
func exit(_entity: Node2D) -> void:
	pass
	
func update(_entity: Node2D, _delta) -> void:
	pass
		
func physics_update(entity: Node2D, delta) -> void:
	entity.velocity = entity.velocity.move_toward(Vector2.ZERO, 200 * delta)
	if entity.velocity.length() < 1.0:
		entity.state_machine.change_state("idle")

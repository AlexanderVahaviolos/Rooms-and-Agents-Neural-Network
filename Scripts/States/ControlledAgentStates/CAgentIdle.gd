extends State

func enter(entity: Node2D) -> void:
	entity.animation_player.play("idle")
	entity.movement_component.velocity = Vector2.ZERO
	entity.velocity = Vector2.ZERO
	
func exit(_entity: Node2D) -> void:
	pass
	
func update(entity: Node2D, _delta) -> void:
	var dir: Vector2 = Input.get_vector("left", "right", "up", "down")
	entity.movement_component.direction = dir
	if dir != Vector2.ZERO:
		entity.state_machine.change_state("move")
		
func physics_update(_entity: Node2D, _delta) -> void:
	pass

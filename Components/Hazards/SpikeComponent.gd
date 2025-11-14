class_name SpikeHazard extends Hazard

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_hazard_enter"))
	
func _on_hazard_enter(body: Node2D) -> void:
	#print("BODY ENTERED")
	if body.iframes == 0:
		var knockback_direction = -body.movement_component.direction
		#print("APPLIED ", damage_dealt, " DAMAGE")
		body.health_component.apply_damage(damage_dealt)
		if knockback_force > 0:
			body.knockback_enabled = true
			#print("APPLIED ", knockback_force, " IN ", knockback_direction)
			body.velocity = knockback_force * knockback_direction

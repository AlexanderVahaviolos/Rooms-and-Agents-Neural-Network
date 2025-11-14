class_name FireComponent extends Hazard

@export var FireAnimation: AnimationPlayer
@export var ticks: int

@onready var hazard_collider: CollisionShape2D = $HazardCollider
var hazard_bounds: Rect2i

func _ready() -> void:
	hazard_type = "Fire"
	connect("body_entered", Callable(self, "_on_hazard_enter"))
	FireAnimation.play("fire")
	
	var collision_shape: Shape2D = hazard_collider.shape
	hazard_bounds = collision_shape.get_rect()
	
func _on_hazard_enter(body: Node2D) -> void:
	print("BODY ENTERED")
	if body.iframes == 0:
		var knockback_direction = -body.movement_component.direction
		print("APPLIED ", damage_dealt, " DAMAGE")
		body.health_component.apply_damage(damage_dealt)
		if knockback_force > 0:
			body.knockback_enabled = true
			print("APPLIED ", knockback_force, " IN ", knockback_direction)
			body.velocity = knockback_force * knockback_direction

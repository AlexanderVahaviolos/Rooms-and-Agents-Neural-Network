@tool
class_name Arrow
extends Hazard

signal arrow_landed()

var velocity: Vector2 = Vector2.ZERO

@onready var movement_component: MovementComponent = $MovementComponent
@onready var hazard_collider: CollisionShape2D = $ArrowCollider
var hazard_bounds: Rect2i
var is_available: bool = true

func _reset() -> void:
	is_available = true
	visible = false
	movement_component.direction = Vector2.ZERO
	velocity = Vector2.ZERO

func _ready() -> void:
	hazard_type = SimulationManager.Detectables.ARROW
	connect("body_entered", Callable(self, "_on_hazard_enter"))
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if !is_available: # if supposed to be in motion
		if movement_component.direction != Vector2.ZERO:
			movement_component.accelerate(delta)
		velocity = movement_component.velocity
		global_position += velocity * delta 

func _on_hazard_enter(body: Node2D) -> void:
	#print("BODY ENTERED: ", body.name)
	if body is Hazard and body.iframes == 0:
		var knockback_direction = body.movement_component.direction
		#print("APPLIED ", damage_dealt, " DAMAGE")
		body.health_component.apply_damage(damage)
		body.score -= 20
		if knockback_force > 0:
			body.knockback_enabled = true
			#print("APPLIED ", knockback_force, " IN ", knockback_direction)
			body.velocity = knockback_force * knockback_direction
	
	_reset()
	emit_signal("arrow_landed")

@tool
class_name ArrowTrap
extends StaticBody2D

var direction: Vector2
@export var trap_direction: facing_direction:
	set(value):
		print("Changed ", name, " direction to ", value)
		trap_direction = value
		_get_trap_direction(value)
		update_arrows()

@export var offset: Vector2 = Vector2(5, 0)

@onready var arrow_container: Node = $ArrowContainer
var Arrows: Array

enum facing_direction {
	RIGHT,
	DOWN,
	LEFT
}

func _get_trap_direction(facing: int) -> Vector2:
	match(facing):
		facing_direction.RIGHT:
			scale.x = 1.0
			%TrapSprite.set_frame_coords(Vector2i(1, 2))
			return Vector2.RIGHT
		facing_direction.DOWN:
			scale.x = 1.0
			%TrapSprite.set_frame_coords(Vector2i(0, 2))
			return Vector2.DOWN
		facing_direction.LEFT:
			scale.x = -1.0
			%TrapSprite.set_frame_coords(Vector2i(1, 2))
			return Vector2.LEFT
		_:
			push_error("not a valid direction ", facing)
			return Vector2.ZERO
			
func update_arrows() -> void:
	var rotation_angle: float = direction.angle()
	for arrow in Arrows:
		if arrow.is_available:
			arrow.rotation = rotation_angle
			arrow.global_position = (global_position + offset).rotated(rotation_angle)

func _ready() -> void:
	%ShootTimer.connect("timeout", Callable(self,"_shoot_arrow"))
	Arrows = arrow_container.get_children()
	direction = _get_trap_direction(trap_direction)
	
	for arrow in Arrows:
		arrow.connect("arrow_landed", Callable(self, "update_arrows"))
		arrow.visible = false
	
func _shoot_arrow() -> void:
	for arrow in Arrows:
		if arrow.is_available:
			#print("SHOOTING FROM ", arrow.global_position, " | SPOS: ", arrow.position)
			arrow.is_available = false
			arrow.visible = true
			arrow.movement_component.direction = direction
			arrow.set_physics_process(true)
			return

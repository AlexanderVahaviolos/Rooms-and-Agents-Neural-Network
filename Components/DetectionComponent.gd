class_name DetectionComponent
extends Area2D

signal target_entered(target: Area2D)
signal target_exited(target: Area2D)

signal static_detected(body: Node2D)

@export var Respondee: Node
@export_range(0.0, 1.0, 0.1) var PayloadSendTime: float
@onready var DetectionArea: CollisionPolygon2D = $DetectionShape
@onready var Raycasts: Node2D = $Raycasts

var current_direction: Vector2 = Vector2(1, 0)
var next_direction: Vector2

var targets: Dictionary[String, Area2D] = {}
var static_node: Node2D
var static_point: Vector2

func _ready() -> void:
	connect("area_entered", Callable(self, "_on_area_detected"))
	connect("area_exited", Callable(self, "_on_area_exited"))
	
	collision_layer = 0
	#collision_mask << 2
	
func _physics_process(_delta: float) -> void:
	var current_distances: Dictionary[Node, float]
	for raycast in Raycasts.get_children():
		if raycast.is_colliding():
			current_distances[raycast] = raycast.get_collision_point().distance_to(raycast.global_position)
				
	if current_distances.size() > 0:
		current_distances.sort()
		_on_static_detected(current_distances.keys()[0])
		
	if Respondee.movement_component.direction != Vector2.ZERO:
		next_direction = Respondee.movement_component.direction
	if next_direction != current_direction:
		current_direction = next_direction
		rotation = atan2(next_direction.y, next_direction.x)
		
func _on_static_detected(raycast: RayCast2D) -> void:	
	static_point = raycast.get_collision_point()

	if static_node != raycast.get_collider():
		static_node = raycast.get_collider()
		emit_signal("static_detected", static_node)
		
func _on_area_detected(area: Area2D) -> void:
	targets[area.name] = area
	emit_signal("target_entered", area)

func _on_area_exited(area: Area2D) -> void:
	emit_signal("target_exited", area)

class_name DetectionComponent
extends Area2D

signal target_entered(target: Area2D)
signal target_exited(target: Area2D)

@export var Respondee: Node
@export_range(0.0, 1.0, 0.1) var PayloadSendTime: float
@onready var DetectionArea: CollisionPolygon2D = $DetectionShape

var current_direction: Vector2 = Vector2(1, 0)
var next_direction: Vector2

var targets: Dictionary[String, Area2D] = {}

func _ready() -> void:
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("area_exited", Callable(self, "_on_area_exited"))
	
	collision_layer = 0
	#collision_mask << 2
	
func _physics_process(_delta: float) -> void:			
	if Respondee.movement_component.direction != Vector2.ZERO:
		next_direction = Respondee.movement_component.direction
	if next_direction != current_direction:
		current_direction = next_direction
		rotation = atan2(next_direction.y, next_direction.x)

func _on_area_entered(area: Area2D) -> void:
	targets[area.name] = area
	emit_signal("target_entered", area)

func _on_area_exited(area: Area2D) -> void:
	emit_signal("target_exited", area)

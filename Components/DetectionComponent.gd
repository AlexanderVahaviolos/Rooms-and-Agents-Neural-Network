class_name DetectionComponent
extends Area2D

signal targetsUpdated(target: Dictionary[String, Dictionary])

@export var Respondee: Node
@export_range(0.0, 1.0, 0.1) var PayloadSendTime: float
@onready var DetectionArea: CollisionShape2D = $CollisionShape2D

var current_direction: Vector2 = Vector2(1, 0)
var next_direction: Vector2

var targets: Dictionary[String, Dictionary]

func _ready() -> void:
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("area_exited", Callable(self, "_on_area_exited"))
	
	collision_layer = 0
	#collision_mask << 2

func _to_string() -> String:
	var line: String = ""
	for value in targets.values():
		line += str(value)
	return line	
	
func _physics_process(_delta: float) -> void:	
	for target in targets.values():
			target["distance"] = Respondee.global_position - target["instance"].global_position
		
	if Respondee.movement_component.direction != Vector2.ZERO:
		next_direction = Respondee.movement_component.direction
	if next_direction != current_direction:
		current_direction = next_direction
		rotation = atan2(next_direction.y, next_direction.x)

func _on_area_entered(area: Area2D) -> void:
	#print(area)
	if area is Exit:
		targets[area.name] = {
			"instance": area,
			"bounds": area.shape_bounds,
			"distance": Respondee.global_position - area.global_position
		}	
	elif area is Hazard:
		targets[area.name] = {
			"instance": area,
			"hazard": area.hazard_type,
			"bounds": area.hazard_bounds,
			"distance": Respondee.global_position - area.global_position
		}
	emit_signal("targetsUpdated", targets)

func _on_area_exited(area: Area2D) -> void:
	targets.erase(area.name)

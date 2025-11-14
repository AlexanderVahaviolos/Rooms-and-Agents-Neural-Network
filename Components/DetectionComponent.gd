extends Area2D
class_name DetectionComponent

@export var Respondee: Node
@export_range(0.0, 1.0, 0.1) var PayloadSendTime: float
@onready var DetectionArea: CollisionShape2D = $CollisionShape2D

var detect_timer: Timer = Timer.new()
var targets: Dictionary[String, Dictionary]

func _ready() -> void:
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("area_exited", Callable(self, "_on_area_exited"))
	detect_timer.connect("timeout", Callable(self, "_on_timeout"))
	
	detect_timer.wait_time = PayloadSendTime
	add_child(detect_timer)
	collision_layer = 0
	collision_mask << 2
	
func _physics_process(_delta: float) -> void:
	if targets.size() > 0:
		if detect_timer.is_stopped():
			detect_timer.start()		
		
		for target in targets.values():
			target["distance"] = Respondee.global_position - target["instance"].global_position
		
	elif targets.size() == 0:
		detect_timer.stop()

func _on_area_entered(area: Area2D) -> void:
	print(area)
	targets[area.name] = {
		"instance": area,
		"hazard": area.hazard_type,
		"bounds": area.hazard_bounds,
		"distance": Respondee.global_position - area.global_position
	}

func _on_area_exited(area: Area2D) -> void:
	targets.erase(area.name)

func _on_timeout() -> void:
	print(targets.values())

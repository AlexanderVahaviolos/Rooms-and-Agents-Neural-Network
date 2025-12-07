class_name DetectionComponent
extends Area2D

signal send_payload(payload: Array[Array])

@export var Respondee: Node
var payload: Dictionary[String, Array] = {}
var payload_array: Array[Array] = []
var payload_timer: float = 0.0
@export_range(0.0, 0.5, 0.1) var PAYLOAD_TIME_LIMIT: float
@onready var DetectionArea: CollisionShape2D = $DetectionShape

@onready var Raycasts: Node2D = $Raycasts
var raycast_points: Dictionary[String, Vector2] = {}
var raycast_lengths: Dictionary[String, float] = {}
var raycast_normals: Dictionary[String, Vector2] = {}

var raycast_timer: float = 0.0
const RAYCAST_TIME_LIMIT: float = 0.05 # Updates 20 times per second
@export var raycast_debug: bool = false

var current_direction: Vector2 = Vector2(1, 0)
var next_direction: Vector2

func _ready() -> void:	
	# Initialize here as I don't want to recalculate constant values
	for raycast in Raycasts.get_children():
		raycast_points[raycast.name] = raycast.target_position
		raycast_lengths[raycast.name] = raycast.target_position.length()
		raycast_normals[raycast.name] = raycast.target_position.normalized()
	
	connect("area_entered", Callable(self, "_on_area_entered"))
	
func _physics_process(delta: float) -> void:
	if Respondee.movement_component.direction != Vector2.ZERO:
		raycast_timer += delta
		next_direction = Respondee.movement_component.direction
	if next_direction != current_direction:
		current_direction = next_direction
		rotation = next_direction.angle()
	
	payload_timer += delta
	if payload_timer >= PAYLOAD_TIME_LIMIT:
		payload_timer = 0.0
		for value in payload.values():
			payload_array.append(value)
		emit_signal("send_payload", payload_array)
	
	if raycast_timer >= RAYCAST_TIME_LIMIT:
		raycast_timer = 0.0
		_update_raycasts()
		
func _update_raycasts() -> void:
	for raycast in Raycasts.get_children():
		var base_len: float = raycast_lengths[raycast.name]
		var max_len := base_len

		# If there's a collision, use that distance as an additional max
		if raycast.is_colliding():
			payload[raycast.name] = [raycast.get_collider(), raycast.get_collision_point()]
			if raycast_debug:
				print(raycast.name, " is collding with: ", raycast.get_collider().name)
			var col_local = raycast.to_local(raycast.get_collision_point())
			max_len = min(max_len, col_local.length())

		var new_target_position = raycast.target_position + raycast_normals[raycast.name] * 10.0
		var new_len = new_target_position.length()

		if new_len <= max_len:
			raycast.target_position = new_target_position
		else:
			# Clamp to max_len along the same direction instead of snapping back
			var dir = new_target_position.normalized()
			raycast.target_position = dir * max_len
		
func _on_area_entered(area: Node2D) -> void:
	payload[area.name] = [area, area.global_position]

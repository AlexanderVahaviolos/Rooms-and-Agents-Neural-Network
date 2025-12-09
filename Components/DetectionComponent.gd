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
	
		raycast.collide_with_areas = true
		raycast.collide_with_bodies = true
	
	connect("area_entered", Callable(self, "_on_area_entered"))

func reset() -> void:
	payload_array.clear()
	payload.clear()
	payload_timer = 0.0
	
	for raycast in Raycasts.get_children():
		raycast.target_position = raycast_points[raycast.name]

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
		
		payload_array.clear()
		# see if can clear payload as well
		for value in payload.values():
			var collider: Node2D = value[0]
			var point: Vector2 = value[1]
			payload_array.append([collider, point])
	
		emit_signal("send_payload", payload_array)
		payload.clear()
	
	if raycast_timer >= RAYCAST_TIME_LIMIT:
		raycast_timer = 0.0
		_update_raycasts()

func _add_hit_to_payload(collider: Node2D, hit_point: Vector2) -> void:
	var key: String = str(collider.get_instance_id())
	
	var dist: float = global_position.distance_to(hit_point)
	
	if payload.has(key):
		var existing := payload[key]
		var existing_dist: float = existing[2]
		if dist < existing_dist:
			payload[key] = [collider, hit_point, dist]
		else:
			payload[key] = [collider, hit_point, dist]

func _update_raycasts() -> void:
	for raycast in Raycasts.get_children():
		var base_len: float = raycast_lengths[raycast.name]
		var max_len := base_len

		# If there's a collision, use that distance as an additional max
		if raycast.is_colliding():
			var collider: Node2D = raycast.get_collider()
			var hit_point: Vector2 = raycast.get_collision_point()
			_add_hit_to_payload(collider, hit_point)
			
			if raycast_debug:
				print(raycast.name, " is collding with: ", raycast.get_collider().name)
				
			var col_local = raycast.to_local(hit_point)
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

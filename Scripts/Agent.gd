extends CharacterBody2D
class_name Agent

signal send_instance(agent: Agent)

@onready var agent_sprite: Sprite2D = $AgentSprite
@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AgentAnimator

@onready var health_component: HealthComponent = $HealthComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var detection_component: DetectionComponent = $DetectionComponent

@export var iframes_on_hit: int
var iframes: float = 0

@export_category("Detection Parameters")
@export_range(4, 10, 1) var hazard_memory: int = 4
@export_range(1, 3, 1) var exit_memory: int = 2
@export_range(100, 300, 10) var memory_decay_distance: float = 100.0

var flip_threshold: float = 0.1

# x-pos: room number | y-pos: room number variant
var current_room: Vector2i = Vector2i(1, 1)

# Agent Movement States
var states: Dictionary = {
	"idle": preload("res://Scripts/States/AgentStates/AgentIdle.gd").new(),
	"move": preload("res://Scripts/States/AgentStates/AgentMove.gd").new(),
	"knockback": preload("res://Scripts/States/AgentStates/AgentKnockback.gd").new()
}

# Neural Network Variables
var brain: Net = Net.new()
var score: float = 0.0
var time_alive: float = 0.0
var id: int
var initialized: bool = false

# --- STAGNATION CHECKING ---
var stagnation_timer: float = 0.0
var last_significant_score: float = 0.0

# --- CIRCLE CHECKING ---
var circle_timer: float = 0.0
var total_path_length: float = 0.0
const MIN_PATH_LENGTH: float = 100.0 # ignoring very short early runs
const EFFICIENCY_THRESHOLD: float = 0.15 # <15% effective progress
const CIRCLE_TIME_LIMIT: float = 5.0

# --- SPINNING CHECKING ---
var spin_timer: float = 0.0
var prev_spin_angle: float = 0.0
var total_spin_angle: float = 0.0
const SPIN_THRESHOLD: float = TAU*2
const SPIN_TIME_LIMIT: float = 5.0

# --- WALL CHECKING ---
var wall_touch_counter: int = 0
var wall_flag: bool = false
var stuck_timer: float = 0.0

# --- IDLE CHECKING ---
var idle_time: float = 0.0

# --- AGENT FINAL CONDITIONS --- 
var death_flag: bool = false
var completed_flag: bool = false

# Neuron inputs
var neuron_inputs: Array
var agent_inputs: Array
var arrow_input: Array
var wall_input: Array
var memory_inputs: Array

var memory_dict: Dictionary[String, Dictionary]
var exit_dict: Dictionary[String, Dictionary]
var hazard_dict: Dictionary[String, Dictionary]

var memory_slots: int = hazard_memory * 4 + exit_memory * 4

# initialized for now
var start_position: Vector2i = Vector2i(randi_range(0, 25), randi_range(0, 25))

var direction: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1))
var new_direction: Vector2
var turn_angle: float
var move_intent: float

var prev_exit_distances: Dictionary[String, float]

var prev_position: Vector2
var prev_velocity: Vector2

func reset_agent() -> void:
	score = 0.0
	time_alive = 0.0
	
	# --- STAGNATION CHECKING ---
	stagnation_timer = 0.0
	last_significant_score = 0.0

	# --- SPINNING CHECKING ---
	spin_timer = 0.0
	prev_spin_angle = 0.0
	total_spin_angle = 0.0

	# --- CIRCLE CHECKING ---
	circle_timer = 0.0
	total_path_length = 0.0
	
	# --- WALL CHECKING ---
	wall_touch_counter = 0
	wall_flag = false
	stuck_timer = 0.0

	# --- IDLE CHECKING ---
	idle_time = 0.0

	# --- AGENT FINAL CONDITIONS --- 
	death_flag = false
	completed_flag = false
	
	set_physics_process(true)
	visible = true
	
	neuron_inputs.clear()
	agent_inputs.clear()
	memory_inputs.clear()
	
	memory_dict.clear()
	hazard_dict.clear()
	exit_dict.clear()
	prev_exit_distances.clear()
	
	start_position = Vector2i(randi_range(0, 25), randi_range(0, 25))
	direction = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	new_direction = direction
	move_intent = 0.0
	
	_ready()

func _ready() -> void:
	global_position = start_position
	
	prev_spin_angle = direction.angle()
	prev_position = global_position
	prev_velocity = velocity
	
	memory_inputs.resize(memory_slots)
	memory_inputs.fill(0.0)
	
	if !initialized: # Run through only once, as this function is also called by reset
		initialized = true
		health_component.connect("damaged", Callable(self, "_on_damaged"))
		health_component.connect("died", Callable(self, "_on_death"))
		detection_component.connect("target_entered", Callable(self, "_update_memory"))
		state_machine.states = self.states
	
		for state in states.values():
			state_machine.add_child(state)
		state_machine.start()
		
		agent_sprite.material = agent_sprite.material.duplicate()
		
func _physics_process(delta: float) -> void:
	if not death_flag:
		for key in memory_dict.keys():
			_update_memory(detection_component.targets[key])
		_check_agent_progress(delta)
	else:
		send_instance.emit(self)
		
	var normalized_pos: Vector2 = global_position / Vector2(WindowManager.screen_size)
	var normalized_vel: Vector2 = velocity / movement_component.max_velocity
	var wall_sensor_value: float
	
	if is_on_wall() and !wall_flag:
		wall_sensor_value = 1.0
		wall_touch_counter += 1
		score -= 20
		wall_flag = true
	elif !is_on_wall() and wall_flag:
		wall_sensor_value = 0.0
		wall_flag = false
		
	agent_inputs = [
		normalized_pos.x, normalized_pos.y,
		normalized_vel.x, normalized_vel.y,
		direction.x, direction.y,
		wall_sensor_value
	]
	
	neuron_inputs = agent_inputs.duplicate()
	neuron_inputs.append_array(memory_inputs)
	
	var output = brain.predict(neuron_inputs)
	turn_angle = output[0] * 5.0 # radians/sec
	new_direction = direction.rotated(turn_angle * delta).normalized()
	move_intent = output[1]
	
	if new_direction != movement_component.direction:
		movement_component.direction = new_direction
	direction = movement_component.direction

	if movement_component.direction.x > flip_threshold: # if looking right
		$AgentSprite.scale.x = 1.0
	elif movement_component.direction.x < -flip_threshold: # if looking left
		$AgentSprite.scale.x = -1.0
		
	if iframes > 0:
		iframes -= ceil(delta)
	move_and_slide()

func _update_memory(target: Area2D) -> void:
	var dir: Vector2 = (target.global_position - global_position).normalized()
	var dist: float = dir.length()
	
	var dict_ref: Dictionary = {}
	var mem_limit: int
	
	var key = target.name
	
	if target is Hazard:
		dict_ref = hazard_dict
		mem_limit = hazard_memory
	elif target is Exit:
		dict_ref = exit_dict
		mem_limit = exit_memory
	else:
		push_error("Unknown target ", key)
		return
		
	dict_ref[key] = {
		"direction": dir,
		"distance": dist
	}
	
	if dict_ref == exit_dict:
		prev_exit_distances[key] = dict_ref[key]["distance"]
	
	if dict_ref[key]["distance"] > memory_decay_distance and dict_ref == hazard_dict:
		dict_ref.erase(key)
		detection_component.targets.erase(key)
		_build_memory_inputs()
	
	if dict_ref.size() > mem_limit:
		var keys = dict_ref.keys()
		keys.sort_custom(func(a, b):
			return dict_ref[a]["distance"] < dict_ref[b]["distance"]
		)
		
		for i in range(mem_limit, keys.size()):
			dict_ref.erase(keys[i])
			
	_build_memory_inputs()
	
func _build_memory_inputs() -> void:
	var inputs: Array[float] = []
	
	var append_targets = func(dict: Dictionary):
		for key in dict.keys():
			var d = dict[key]
			var type_value: int = SimulationManager.node_to_type(d)
			
			var dir_vec = d["direction"].normalized()
			var dist_norm = clamp(d["distance"] / memory_decay_distance, 0.0, 1.0)
			inputs.append_array([type_value, dir_vec.x, dir_vec.y, 1.0 - dist_norm])
			
	append_targets.call(hazard_dict, #remove parameter)
	append_targets.call(exit_dict, SimulationManager.Detectables.EXIT)
	
	# Padding to make it a fixed size
	var remaining = (hazard_memory + exit_memory) - (hazard_dict.size() + exit_dict.size())
	for i in range(remaining):
		inputs.append_array([0.0, 0.0, 0.0, 0.0])
	
	memory_inputs = inputs

func _check_agent_progress(delta: float) -> void:
	time_alive += delta
	
	var dist_moved = global_position.distance_to(prev_position)
	var net_displacement = global_position.distance_to(start_position)
	var vel_aligned = velocity.normalized().dot(direction)

	# Movement / Alignment Rewards
	if dist_moved > 0.0:
		score += dist_moved * 0.1
	if vel_aligned > 0.7:
		score += 0.05
	else:
		score -= 0.02
	
	# Penalty for being Idle 
	if velocity.length() < 1.0:
		score -= delta * 0.1
	
	# Exit penalties and bonuses
	if exit_dict.size() > 0:
		# Check if they are in line with the exit direction
		for key in exit_dict.keys():
			var exit_aligned = velocity.normalized().dot(exit_dict[key]["direction"])
			var prev_exit_distance = prev_exit_distances[key]
			
			if exit_aligned > 0.7:
				score += 0.30
			else:
				score -= 0.03
			if exit_dict[key]["distance"] < prev_exit_distance:
				score += 0.5
			else:
				score -= 0.05
			prev_exit_distance = exit_dict[key]["distance"]
			
	# ------ KILL CHECKS --------
	
	# SPIN CHECK
	var current_spin_angle = direction.angle()
	var delta_rotation_rad = current_spin_angle - prev_spin_angle
	
	while delta_rotation_rad > PI:
		delta_rotation_rad -= TAU
	while delta_rotation_rad < -PI:
		delta_rotation_rad += TAU
	
	total_spin_angle += abs(delta_rotation_rad)
	prev_spin_angle = current_spin_angle
	
	if abs(total_spin_angle) > SPIN_THRESHOLD:
		spin_timer += delta
	else:
		spin_timer = 0.0
		
	if total_spin_angle >= SPIN_THRESHOLD: # 2 full cycles
		death_flag = true
		print("Agent ", name, " died because they spun too much")
		return
			
	if spin_timer > 0.0:
		score -= 3.0 * delta
	elif spin_timer >= SPIN_TIME_LIMIT:
		total_spin_angle = 0.0
		spin_timer = 0.0
	
	# OVERALL JUST BAD CHECK
	if score < -75:
		death_flag = true
		print("Agent ", name, " died because their score was too low")
		return
	
	# CIRCLE CHECK
	total_path_length += dist_moved
	var efficiency = (net_displacement / max(total_path_length, 0.001))
	
	if total_path_length > MIN_PATH_LENGTH and efficiency < EFFICIENCY_THRESHOLD:
		circle_timer += delta
	else:
		circle_timer = 0.0
	
	if circle_timer > CIRCLE_TIME_LIMIT:
		score -= 50.0
		death_flag = true
		print("Agent ", name, " died because they were circling around")
		return
		
	# TOUCHED THE WALL TOO MANY TIMES CHECK
	if wall_touch_counter > 4:
		# score is already deducted every wall touch
		death_flag = true
		print("Agent ", name, " died because they liked walls too much")
		return
	
	# PROGRESS CHECK
	var progress = score - last_significant_score

	if progress > 0.03:
		stagnation_timer = 0.0
		last_significant_score = score
	else:
		stagnation_timer += delta

	if stagnation_timer > 5.0: # 5 seconds of no real score gain
		score -= 30.0
		death_flag = true
		print("Agent ", name, " died because they stagnated for too long")
		return
	
	# STUCK ON WALL CHECK
	if is_on_wall() and dist_moved < 1.0:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	
	if stuck_timer > 2.0:
		score -= 40.0
		death_flag = true
		print("Agent ", name, " died because they got stuck on a wall")
		return
	
	# NO MOVEMENT CHECK
	if dist_moved < 1.0 and velocity.length() < 2.0: # and if no arrow trap in range
		idle_time += delta
		if idle_time > 5.0:
			score -= 50.0
			death_flag = true
			print("Agent ", name, " died because they didn't move enough")
			return
	else:
		idle_time = 0.0
	
	# ---------------------------
	
	prev_position = global_position
	prev_velocity = velocity
	#print(score)	

func _on_damaged(_damage: int) -> void:
	state_machine.change_state("knockback")
	
func _on_death() -> void:
	score -= 15
	death_flag = true

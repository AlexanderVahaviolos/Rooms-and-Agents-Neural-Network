extends CharacterBody2D

@export var iframes_on_hit: int
var iframes: float = 0

@export_category("Debug Testing")
@export var score: float = 0
var debug_timer: float = 0.0
@export_range(0.1, 1.0, 0.1) var debug_print: float = 0.5
@export var memory_testing: bool
@export var direction_testing: bool
@export var wall_testing: bool
@export var spin_testing: bool

@export_group("Detect Testing")
@export var print_exit: bool
@export var print_direct: bool
@export var print_static: bool
@export var print_moving: bool

@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AgentAnimator

@onready var detection_component: DetectionComponent = $DetectionComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var movement_component: MovementComponent = $MovementComponent

var flip_threshold: float = 0.1

# x-pos: room number | y-pos: room number variant
var current_room: Vector2i = Vector2i(1, 1)
var start_position: Vector2i = Vector2.ZERO

var states: Dictionary = {
	"idle": preload("res://Scripts/AgentScripts/States/ControlledAgentStates/CAgentIdle.gd").new(),
	"move": preload("res://Scripts/AgentScripts/States/ControlledAgentStates/CAgentMove.gd").new(),
	"knockback": preload("res://Scripts/AgentScripts/States/AgentStates/AgentKnockback.gd").new()
}

# Memory Testing
var memory: MemoryInput
@export_category("Memory Parameters")
@export_range(4, 10, 1) var direct_memory: int = 4
@export_range(1, 3, 1) var exit_memory: int = 2
@export_range(1, 3, 1) var static_memory: int = 4
@export_range(100, 300, 10) var memory_decay_distance: float = 100.0

enum DeathTypes {
	BAD_SCORE,
	SPINNING,
	CIRCLING,
	STAGNATION,
	WALL_TOUCH,
	WALL_STUCK,
	NO_MOVEMENT
}
var death_reason: int

# Score Testing
var scoring: Score

# Neural Testing
var arrow_input: Array
var wall_input: Array

# --- SPINNING CHECKING ---
var spin_timer: float = 0.0
var prev_spin_angle: float = 0.0
var total_spin_angle: float = 0.0
const SPIN_THRESHOLD: float = PI
const SPIN_TIME_LIMIT: float = 5.0

var death_flag: bool
var wall_flag: bool
var wall_sensor_value: float = 0.0
var wall_touch_counter: int = 0
		
var direction: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1))
var new_direction: Vector2
var turn_angle: float
var move_intent: float

var prev_exit_distances: Dictionary[String, float] = {}

var prev_direction: Vector2 = Vector2.ZERO
var prev_position: Vector2
var prev_velocity: Vector2

func _ready() -> void:
	health_component.connect("damaged", Callable(self, "_on_damaged"))
	health_component.connect("died", Callable(self, "_on_death"))
	state_machine.states = self.states
	for state in states.values():
		state_machine.add_child(state)
	state_machine.start()
	
	global_position = start_position
	
	memory = MemoryInput.new(self)
	scoring = Score.new(self)
	
func _debug_prints() -> void:
	if memory_testing:
		#print("used slots: ", memory.used_slots, " memory inputs: ", memory.memory_inputs)
		
		if print_exit:
			for value in memory.exit_dict.values():
				print("exit_dict: ", value)
		if print_direct:
			for value in memory.direct_dict.values():
				print("direct_dict: ", value)		
		if print_static:
			for value in memory.static_dict.values():
				print("static_dict: ", value)
		if print_moving:
			for value in memory.moving_dict.values():
				print("moving_dict: ", value)

	if wall_testing:
		var wall = detection_component.static_node
		var point = detection_component.static_point
		if wall:
			print(
				"static name: ", wall.name, 
				"distance: ", point.distance_to(global_position)
				)
	if direction_testing:
		print(" comp direction ", movement_component.direction,
		" prev direction ", direction)
	
	if spin_testing:
		print("new angle: ", abs(detection_component.global_rotation_degrees) * direction.y,
			" direction: ", direction,
			" total angle: ", total_spin_angle)
			
func _physics_process(delta: float) -> void:
	_debug_check(delta)
	debug_timer += delta
	if debug_timer >= debug_print:
		debug_timer = 0.0
		_debug_prints()
	
	if is_on_wall() and !wall_flag:
		wall_sensor_value = 1.0
		wall_touch_counter += 1
		scoring.score -= 20
		wall_flag = true
	elif !is_on_wall() and wall_flag:
		wall_sensor_value = 0.0
		wall_flag = false
	
	if movement_component.direction.x > flip_threshold: # if looking right
		$AgentSprite.scale.x = 1.0
	elif movement_component.direction.x < -flip_threshold: # if looking left
		$AgentSprite.scale.x = -1.0
	
	if iframes > 0:
		iframes -= delta
	
	direction = movement_component.direction
	move_and_slide()

func _debug_check(delta: float) -> void:
	# SPIN CHECK
	var current_spin_angle = abs(detection_component.global_rotation_degrees) * direction.y
	if prev_spin_angle != current_spin_angle:
		total_spin_angle += (current_spin_angle - prev_spin_angle)
		prev_spin_angle = current_spin_angle
	
	if total_spin_angle > SPIN_THRESHOLD:
		spin_timer += delta
	else:
		spin_timer = 0.0
	
	if spin_timer > 0.0:
		pass
	elif spin_timer > SPIN_TIME_LIMIT:
		if total_spin_angle >= TAU * 3: # 3 full cycles
			print("Agent ", name, " died because they spun too much")
			return
		else:
			total_spin_angle = 0.0
			spin_timer = 0.0

func _on_damaged(_damage: int) -> void:
	state_machine.change_state("knockback")
	
func _on_death() -> void:
	print(self.name, " has died")
	set_physics_process(false)
	visible = false
	global_position = Vector2(-1000, -1000)

extends CharacterBody2D

@export var iframes_on_hit: int
var iframes: float = 0

@export_category("Debug Testing")
@export var score: float = 250
var debug_timer: float = 0.0
@export_range(0.1, 1.0, 0.1) var debug_print: float = 0.5
@export var memory_testing: bool
@export var direction_testing: bool
@export var wall_testing: bool
@export var spin_testing: bool

@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AgentAnimator

@onready var detection_component: DetectionComponent = $DetectionComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var movement_component: MovementComponent = $MovementComponent

var flip_threshold: float = 0.1

# x-pos: room number | y-pos: room number variant
var current_room: Vector2i = Vector2i(1, 1)

var states: Dictionary = {
	"idle": preload("res://Scripts/AgentScripts/States/ControlledAgentStates/CAgentIdle.gd").new(),
	"move": preload("res://Scripts/AgentScripts/States/ControlledAgentStates/CAgentMove.gd").new(),
	"knockback": preload("res://Scripts/AgentScripts/States/AgentStates/AgentKnockback.gd").new()
}

# Neural Testing
var arrow_input: Array
var wall_input: Array

# --- SPINNING CHECKING ---
var spin_timer: float = 0.0
var prev_spin_angle: float = 0.0
var total_spin_angle: float = 0.0
const SPIN_THRESHOLD: float = PI
const SPIN_TIME_LIMIT: float = 5.0

var prev_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	health_component.connect("damaged", Callable(self, "_on_damaged"))
	health_component.connect("died", Callable(self, "_on_death"))
	detection_component.connect("target_entered", Callable(self, "_update_memory"))

	state_machine.states = self.states
	for state in states.values():
		state_machine.add_child(state)
	state_machine.start()
	
func _update_memory(detected: Node2D) -> void:
	if memory_testing:
		print("target name: ", detected.name, " | target: ", detected)
	
func _debug_prints() -> void:
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
		" prev direction ", prev_direction)
	
	if spin_testing:
		print("new angle: ", abs(detection_component.global_rotation_degrees) * prev_direction.y,
			" direction: ", prev_direction,
			" total angle: ", total_spin_angle)
			
func _physics_process(delta: float) -> void:
	_debug_check(delta)
	debug_timer += delta
	if debug_timer >= debug_print:
		debug_timer = 0.0
		_debug_prints()
	
	if movement_component.direction.x > flip_threshold: # if looking right
		$AgentSprite.scale.x = 1.0
	elif movement_component.direction.x < -flip_threshold: # if looking left
		$AgentSprite.scale.x = -1.0
	
	if iframes > 0:
		iframes -= delta
	
	if movement_component.direction != Vector2.ZERO:
		prev_direction = movement_component.direction
	move_and_slide()

func _debug_check(delta: float) -> void:
	# SPIN CHECK
	var current_spin_angle = abs(detection_component.global_rotation_degrees) * prev_direction.y
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

class_name Agent
extends CharacterBody2D

signal send_instance(agent: Agent)

@onready var agent_sprite: Sprite2D = $AgentSprite
@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AgentAnimator

@onready var health_component: HealthComponent = $HealthComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var detection_component: DetectionComponent = $DetectionComponent

@export var iframes_on_hit: int
var iframes: float = 0

var flip_threshold: float = 0.1

# x-pos: room number | y-pos: room number variant
var current_room: Vector2i = Vector2i(1, 1)

# Agent Movement States
var states: Dictionary = {
	"idle": preload("res://Scripts/AgentScripts/States/AgentStates/AgentIdle.gd").new(),
	"move": preload("res://Scripts/AgentScripts/States/AgentStates/AgentMove.gd").new(),
	"knockback": preload("res://Scripts/AgentScripts/States/AgentStates/AgentKnockback.gd").new()
}

var death_reason: int

# Neural Network Variables
var brain: Net
var memory: MemoryInput
var scoring: Score
var score: float = 0
var agent_inputs: Array[float] = []
var neuron_inputs: Array[float] = []
var neuron_size: int
var time_alive: float = 0.0
var id: int

# --- WALL CHECKING ---
var wall_touch_counter: int = 0
var wall_flag: bool = false

# --- AGENT FINAL CONDITIONS --- 
var death_flag: bool = false
var completed_flag: bool = false

# initialized for now
var start_position: Vector2i = Vector2i(12, 120)

var direction: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1))
var new_direction: Vector2
var turn_angle: float
var move_intent: float

var prev_exit_distances: Dictionary[String, float] = {}

var prev_position: Vector2
var prev_velocity: Vector2

func reset_agent() -> void:
	detection_component.reset()
	memory.reset()
	scoring.reset()
	neuron_inputs.fill(0.0)
	agent_inputs.fill(0.0)
	score = 0.0
	
	time_alive = 0.0

	# --- WALL CHECKING ---
	wall_touch_counter = 0
	wall_flag = false

	# --- AGENT FINAL CONDITIONS --- 
	death_reason = -1
	death_flag = false
	completed_flag = false
	
	direction = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	new_direction = direction
	move_intent = 0.0
	
	global_position = start_position
	
	prev_exit_distances.clear()
	
	turn_angle = 0 
	prev_position = global_position
	prev_velocity = velocity
	enabled(true)

func enabled(state: bool) -> void:
	detection_component.set_physics_process(state)
	self.set_physics_process(state)
	visible = state

func _ready() -> void:
	global_position = start_position
	
	prev_position = global_position
	prev_velocity = velocity
	
	memory = MemoryInput.new(self)
	scoring = Score.new(self)
	neuron_size = SimulationManager.neuron_size
	agent_inputs.resize(SimulationManager.AGENT_INP_SIZE)
	agent_inputs.fill(0.0)
	neuron_inputs.resize(neuron_size)
	neuron_inputs.fill(0.0)
	brain = Net.new(neuron_size)
	
	health_component.connect("damaged", Callable(self, "_on_damaged"))
	health_component.connect("died", Callable(self, "_on_death"))
	state_machine.states = self.states
	
	for state in states.values():
		state_machine.add_child(state)
	state_machine.start()
		
	agent_sprite.material = agent_sprite.material.duplicate()
	
func _physics_process(delta: float) -> void:
	if death_flag:
		send_instance.emit(self)
	time_alive += delta
	
	# Step 1: Fill in agent_inputs array
	var normalized_pos: Vector2 = global_position / Vector2(WindowManager.screen_size)
	var normalized_vel: Vector2 = velocity / movement_component.max_velocity
	var wall_sensor_value: float = 0
	
	if is_on_wall() and !wall_flag:
		wall_sensor_value = 1.0
		wall_touch_counter += 1
		scoring.score -= 20
		wall_flag = true
	elif !is_on_wall() and wall_flag:
		wall_sensor_value = 0.0
		wall_flag = false
	
	# Building the Agent Input Array
	agent_inputs[0] = normalized_pos.x
	agent_inputs[1] = normalized_pos.y
	agent_inputs[2] = normalized_vel.x
	agent_inputs[3] = normalized_vel.y
	agent_inputs[4] = direction.x
	agent_inputs[5] = direction.y
	agent_inputs[6] = wall_sensor_value
	
	# Step 2: Copy agent_inputs + memory_inputs into neuron_inputs
	for i in range(SimulationManager.AGENT_INP_SIZE):
		neuron_inputs[i] = agent_inputs[i]
		
	for i in range(memory.memory_size):
		neuron_inputs[SimulationManager.AGENT_INP_SIZE + i] = memory.memory_inputs[i]
	
	# Step 3: Get Agent prediction
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

func _on_damaged(_damage: int) -> void:
	state_machine.change_state("knockback")
	
func _on_death() -> void:
	scoring.score -= 15
	death_flag = true

extends CharacterBody2D
class_name Agent

signal send_instance(agent: Agent)

@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AgentAnimator

@onready var health_component: HealthComponent = $HealthComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var detection_component: DetectionComponent = $DetectionComponent

@export var iframes_on_hit: int
var iframes: float = 0
var knockback_enabled: bool = false

@export_category("Detection Parameters")
@export var max_hazards: int = 4
@export var max_exits: int = 2

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
var dead: bool = false
var complete: bool = false

var agent_inputs: Array
var target_inputs: Array
var target_input_size: int = max_hazards * 4 + max_exits * 4
var neural_inputs: Array
# Agent Movement

# initialized for now
var start_position: Vector2i = Vector2i(randi_range(0, 25), randi_range(0, 25))

var dir: Vector2
var new_direction: Vector2
var move_intent: float

var prev_position: Vector2
var prev_velocity: Vector2

func _ready() -> void:
	global_position = start_position
	
	prev_position = global_position
	prev_velocity = velocity
	
	target_inputs.resize(target_input_size)
	target_inputs.fill(0.0)
	
	health_component.connect("damaged", Callable(self, "_on_damaged"))
	health_component.connect("died", Callable(self, "_on_death"))
	detection_component.connect("targetsUpdated", Callable(self, "get_inputs_from_targets"))
	state_machine.states = self.states
	
	for state in states.values():
		state_machine.add_child(state)
	state_machine.start()
	

func _physics_process(delta: float) -> void:
	if not dead:
		_calculate_new_score(delta)
	
	agent_inputs = [
		global_position.x, global_position.y,
		velocity.x, velocity.y,
		dir.x, dir.y		
	]
	
	neural_inputs = agent_inputs.duplicate()
	neural_inputs.append_array(target_inputs)
	
	var output = brain.predict([global_position.x, global_position.y, 
							   velocity.x, velocity.y, 
							   dir.x, dir.y])
	
	new_direction = output[0]
	move_intent = output[1]
	
	if new_direction != movement_component.direction:
		movement_component.direction = new_direction
	dir = movement_component.direction

	if movement_component.direction.x > flip_threshold: # if looking right
		$AgentSprite.scale.x = 1.0
	elif movement_component.direction.x < -flip_threshold: # if looking left
		$AgentSprite.scale.x = -1.0
		
	if iframes > 0:
		iframes -= delta
	move_and_slide()

func _calculate_new_score(delta: float) -> void:
	var dist_moved = global_position.distance_to(prev_position)
	var vel_aligned = velocity.normalized().dot(dir)
	
	# Base reward for moving
	if dist_moved > 0.0:
		score += dist_moved * 0.1
		
	# Alignment reward
	if vel_aligned > 0.7:
		score += 0.05
	else:
		score -= 0.02
	
	# Penalty for being Idle 
	if velocity.length() < 1.0: # and certain wait trap not in range
		score -= delta * 0.1
	
	# if trap in targets and distance is sufficient:
	# +score
	
	# Lifetime bonus
	score += delta * 0.01
	
	prev_position = global_position
	prev_velocity = velocity

func get_inputs_from_targets(targets: Dictionary[String, Dictionary]) -> void:
	var inputs: Array = []
	var hazards: Array = []
	var exits: Array = []
	
	for k in targets.keys():
		var t = targets[k]
		if t["instance"] is Exit:
			exits.append(t)
		elif t["instance"] is Hazard:
			hazards.append(t)
	
	# sorting hazards by distance	
	hazards.sort_custom(func(a, b):
		return a["distance"].length() < b["distance"].length()
		)
		
	for h in hazards.slice(0, max_hazards):
		var dist: float = h["distance"].length()
		var dir: Vector2 = h["distance"].normalized()
		var detect_type = float(h["hazard"])
		inputs.append_array([detect_type, dir.x, dir.y, dist])
	
	for e in exits.slice(0, max_exits):
		var dist: float = e["distance"].length()
		var dir: Vector2 = e["distance"].normalized()
		var detect_type = float(SimulationManager.Detectables.EXIT)
		inputs.append_array([detect_type, dir.x, dir.y, dist])
	
	while inputs.size() < target_input_size:
		inputs.append(0.0)
		
	target_inputs = inputs
			
func _on_collision(_area: Area2D) -> void:
	if not dead or not complete:
		send_instance.emit(self)
		
		# check what the agent has collided with
		

# honestly it should become dead if the agent's score is like below a certain
# threshold, maybe like it just dies if their score is below like
# average / 1.5 every like 20-30 seconds, time might be dynamic based on like
# tiles from enterance to exit tile + avg score gain / prev_gen_best_score

extends CharacterBody2D

@onready var state_machine: StateMachine = $StateMachine
@onready var animation_player: AnimationPlayer = $AgentAnimator

@onready var health_component: HealthComponent = $HealthComponent
@onready var movement_component: MovementComponent = $MovementComponent

@onready var raycast: RayCast2D = $RayCast2D

@export var iframes_on_hit: int
var iframes: int = 0
var knockback_enabled: bool = false

var flip_threshold: float = 0.1

var states: Dictionary = {
	"idle": preload("res://Scripts/States/ControlledAgentStates/CAgentIdle.gd").new(),
	"move": preload("res://Scripts/States/ControlledAgentStates/CAgentMove.gd").new(),
	"knockback": preload("res://Scripts/States/AgentStates/AgentKnockback.gd").new()
}

func _ready() -> void:
	health_component.connect("damaged", Callable(self, "_on_damaged"))
	health_component.connect("died", Callable(self, "_on_death"))
	state_machine.states = self.states
	
	for state in states.values():
		state_machine.add_child(state)
	state_machine.start()
	
func _physics_process(delta: float) -> void:
	if movement_component.direction.x > flip_threshold: # if looking right
		$AgentSprite.scale.x = 1.0
	elif movement_component.direction.x < -flip_threshold: # if looking left
		$AgentSprite.scale.x = -1.0
		
	if iframes > 0:
		iframes -= delta
	move_and_slide()
	
func _on_damaged(_damage: int) -> void:
	state_machine.change_state("knockback")
	
func _on_death() -> void:
	print(self.name, " has died")
	self.queue_free()

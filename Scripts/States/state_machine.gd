@icon("res://Sprites/Icons/states.png")

extends Node
class_name StateMachine

@export var owner_ref: Node2D
@export var initial_state : String
var states: Dictionary = {} # {"Idle": IdleState.tres, "Move": MoveState.tres}
var current_state

func start():
	change_state(initial_state)

func _process(delta: float):
	if current_state:
		current_state.update(owner_ref, delta)

func _physics_process(delta: float):
	if current_state:
		current_state.physics_update(owner_ref, delta)

func change_state(state_name: String):
	if current_state:
		current_state.exit(owner_ref)
	current_state = states.get(state_name)
	if current_state:
		current_state.enter(owner_ref)
	#print("[STATE MACHINE] - THE STATE: ", state_name)

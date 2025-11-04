extends CharacterBody2D
class_name Agent

## AGENTS DO NOT COLLIDE WITH OTHER AGENTS

signal send_instance(agent: Agent)

@export var speed: float = 100.0
var direction: Vector2 = Vector2.ZERO

var screen_size: Vector2

var brain: Net = Net.new()
var score: int = 0
var dead: bool = false
var complete: bool = false

func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	# position will be wherever the start of the maze is

func _physics_process(_delta: float) -> void:
	
	# INPUTS:
	# SELF
	# Position x
	# Position y
	# Velocity
	# Direction
	direction = brain.predict([global_position.x, global_position.y, 
							   velocity.x, velocity.y, 
							   direction.x, direction.y])
	
	velocity = direction * speed
	move_and_slide()

func _on_collision(area: Area2D) -> void:
	if not dead or not complete:
		send_instance.emit(self)
		
		# check what the agent has collided with
		

# honestly it should become dead if the agent's score is like below a certain
# threshold, maybe like it just dies if their score is below like
# average / 1.5 every like 20-30 seconds, time might be dynamic based on like
# tiles from enterance to exit tile + avg score gain / prev_gen_best_score

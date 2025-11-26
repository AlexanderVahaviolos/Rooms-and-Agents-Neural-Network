extends Node

var screen_size: Vector2i
const mutation_rate: float = 0.05

@export var start_agent_count: int = 5
var current_agent_count: int = start_agent_count

@export var MazeScene: PackedScene
@export var AgentScene: PackedScene

@onready var RoomContainer: Node2D = $RoomContainer
@onready var AgentContainer: Node2D = $AgentContainer

@export_category("DEBUG")
@export var ControllableAgentScene: PackedScene
@export var enable_character: bool = false

var maze
var enter_location: Vector2i
var exit_location: Vector2i

var agents: Dictionary[String, Agent] = {}
var dead_agents: Dictionary[String, Agent] = {} # might not need
var complete_agents: Dictionary[String, Agent] = {} # complete as finished maze
var agent_neurons: int = 0

var best_agent: Agent = null
var generation: int = 1

var check_score_timer: float = 0.0
const score_timer_limit: float = 0.25
var prev_top_score_agent: Agent
var prev_lowest_score_agent: Agent

func _ready() -> void:
	%SkipButton.connect("pressed", Callable(self, "_next_generation"))
	randomize()
	screen_size = get_viewport().get_visible_rect().size
	_setup()

# Just an agent size check
func _physics_process(delta: float) -> void:
	check_score_timer += delta
	if check_score_timer >= score_timer_limit:
		check_score_timer = 0.0
		_outline_agents()
	
	if agents.size() > 0 and !enable_character and %LoopButton.toggle_mode:
		pass
	elif agents.size() <= 0 and !enable_character and %LoopButton.toggle_mode:
		_next_generation()
		
func _setup() -> void:
	# Initial Setup for the maze and the agents
	
	# generate maze code
	
	# generate the agents 
	if !enable_character:
		for i in range(start_agent_count):
			var agent_instance = AgentScene.instantiate()
			agent_instance.id = i
			agent_instance.name = str(generation) + "-" + str(agent_instance.id)
			
			# Getting Agent Information
			if i == 1:
				agent_neurons = 7 + agent_instance.memory_slots # 7 is the current agent inputs
			
			agent_instance.connect("send_instance", Callable(self, "_on_send_agent_instance"))
			agent_instance.add_to_group("Agents")
			AgentContainer.add_child(agent_instance)
			agents[agent_instance.name] = agent_instance
	else:
		var agent_instance = ControllableAgentScene.instantiate()
		AgentContainer.add_child(agent_instance)

	%GenerationLabel.text = "Generation " + str(generation)
	%ScoreLabel.text = "Previous Top Score: 0"

func _next_generation() -> void:
	generation += 1
	
	var performant_agents: Array[Agent]
	var dead_performant_agents: Array[Agent]
	var remainder: int = 0
	
	if %SkipButton.perform_skip:
		print("GOING TO: GENERATION ", generation)
		%SkipButton.perform_skip = false
		dead_agents = agents.duplicate()
		agents.clear()
	
	if generation != 1: # skipping first generation
		# getting the top 10 best performing agents
		# should also get best agent as a guarantee in next gen
		# + some special allocation for next gen idk yet
		
		# Check if there are completed agents
		if complete_agents.size() > 0:
			performant_agents = complete_agents.values().duplicate()
			performant_agents.sort_custom(func(a, b):
				return a.score > b.score
			)
		
		# if there are 10 or more complete agents	
		if complete_agents.size() >= 10:
			performant_agents = performant_agents.slice(0, 10)
		
		# If there are less than 10 complete agents
		else: 
			# gets the instances from the dead agents and how many to append
			# works whether there are a range 0 - 9 complete agents 
			dead_performant_agents = dead_agents.values().duplicate()
			remainder = 10 - complete_agents.size() 

			dead_performant_agents.sort_custom(func(a, b):
				return a.score > b.score
			)				
			performant_agents.append_array(dead_performant_agents.slice(0, remainder))
			print("ye i appended these bums, ", dead_performant_agents.slice(0, remainder))
		
		best_agent = performant_agents[0]
		# score display
		print("generation " + str(generation) + " score: " + str(best_agent.score))
	
	# add a weight ratio so that if say the 3rd agent did way better than the 
	# 4th agent, then it will be weighted so that the 3rd agent gets picked more
	# than the 4th and all previous agents before the 4th
	# go through all the agents and update their brain net
	for agent in AgentContainer.get_children():
		agent.brain = mutate(performant_agents[randi_range(0, 9)].brain)

	# Update UI
	%GenerationLabel.text = "Generation " + str(generation)
	%ScoreLabel.text = "Previous Top Score: " + str("%.2f" % best_agent.score)

	# then add them back to the regular agent list and reset them
	_reset_agents(false)
	
func _reset_agents(all_reset: bool) -> void:
	var all_agents = complete_agents.merged(dead_agents)
	
	if all_reset: # True reset, restarts the simulation
		pass
	else: # Post generation reset, called after each generation
		if agents.size() > 0:
			push_error("Agent Array should be zero, yet it is: ", agents.size())
		else:
			for key in all_agents.keys():
				var agent_instance = all_agents[key]
				agent_instance.name = str(generation) + "-" + str(agent_instance.id)
				key = agent_instance.name
				
				agent_instance.reset_agent()
			
				agents[key] = agent_instance
				
	complete_agents.clear()
	dead_agents.clear()

func _outline_agents() -> void:
	var current_agents: Array = agents.values()
	
	if current_agents.is_empty():
		return
		
	current_agents.sort_custom(func(a, b):
		return a.score > b.score
	)
			
	var top_score_agent = current_agents[0]
	var lowest_score_agent = current_agents[-1]
	
	if prev_top_score_agent: 
		prev_top_score_agent.agent_sprite.material.set_shader_parameter(
			"outline_color", Color.from_rgba8(0, 0, 0, 0)
		)
	if prev_lowest_score_agent:
		prev_lowest_score_agent.agent_sprite.material.set_shader_parameter(
			"outline_color", Color.from_rgba8(0, 0, 0, 0)
		)	

	top_score_agent.agent_sprite.material.set_shader_parameter(
		"outline_color", Color.from_rgba8(125, 255, 125, 185)
		)
	lowest_score_agent.agent_sprite.material.set_shader_parameter(
		"outline_color", Color.from_rgba8(255, 100, 100, 185)
		)		
		
	prev_top_score_agent = top_score_agent
	prev_lowest_score_agent = lowest_score_agent

func _on_send_agent_instance(agent: Agent) -> void:
	# shove them out of the way
	agent.global_position = Vector2(-10000, -10000)
	agents.erase(agent.name)
	
	agent.set_physics_process(false)
	agent.visible = false
	
	if agent.death_flag:
		dead_agents[agent.name] = agent
	elif agent.completed_flag:
		complete_agents[agent.name] = agent
		print(complete_agents)

func mutate(parent_net: Net) -> Net:
	var mutation: Net = Net.new()
	
	for i in range(parent_net.layers.size()):
		for j in range(parent_net.layers[i].neurons.size()):
			for k in range(parent_net.layers[i].neurons[j].weights.size()): 
				if randf() <= mutation_rate:
					mutation.layers[i].neurons[j].weights.append(randf_range(-1, 1))
				else:
					mutation.layers[i].neurons[j].weights.append(parent_net.layers[i].neurons[j].weights[k])
	return mutation
			

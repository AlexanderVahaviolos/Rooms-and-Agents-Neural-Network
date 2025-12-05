extends Node

var screen_size: Vector2i
const mutation_rate: float = 0.05

@export_category("Simulation Controls")
@export var start_agent_count: int = 5
var current_agent_count: int = start_agent_count

# --- MEMORY UPDATING ---
var memory_update_timer: float = 0.0
@export_range(0.1, 0.5, 0.05) var MEMORY_TIMER_LIMIT: float = 0.2 # called every 200ms

@export_group("Scenes")
@export var MazeScene: PackedScene
@export var AgentScene: PackedScene

@export_group("Generation Decay Settings")
@export_range(0.8, 0.9, 0.025) var BASE_DECAY: float = 0.85 
@export_range(0.995, 0.999, 0.0005) var DECAY_FACTOR: float = 0.9975
const MIN_DECAY: float = 0.8

@export_range(1.0, 30, 1.0) var CONVERGE_TIME: float = 1.0
@export_range(10, 60, 5.0) var SLOW_TIME: float = 20.0

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

# Agent Generation data
var best_agent: Agent = null
var generation: int = 1
var best_time: float

var check_score_timer: float = 0.0
const score_timer_limit: float = 0.25
var prev_top_score_agent: Agent
var prev_lowest_score_agent: Agent

func _ready() -> void:
	%SkipButton.connect("pressed", Callable(self, "_next_generation"))
	randomize()
	screen_size = get_viewport().get_visible_rect().size
	setup()

# Just an agent size check
func _physics_process(delta: float) -> void:
	if !%TimeButton.button_pressed:
		check_score_timer += delta
		if check_score_timer >= score_timer_limit:
			check_score_timer = 0.0
			_outline_agents()
	
		memory_update_timer += delta
		if memory_update_timer >= MEMORY_TIMER_LIMIT:
			for agent in agents.values():
				agent.memory.update_memory()
				agent.update_score(memory_update_timer)
			memory_update_timer = 0.0
	
		if !enable_character and !%LoopButton.button_pressed and agents.is_empty():
			_next_generation()
	
func setup() -> void:
	# Initial Setup for the maze and the agents
	generation = 0
	memory_update_timer = 0.0
	check_score_timer = 0.0
	best_agent = null
	
	# generate maze code
	
	# generate the agents 
	if !enable_character:
		for i in range(start_agent_count):
			var agent_instance = AgentScene.instantiate()
			agent_instance.id = i
			agent_instance.name = str(generation) + "-" + str(agent_instance.id)
			agent_instance.connect("send_instance", Callable(self, "_on_send_agent_instance"))
			agent_instance.add_to_group("Agents")
			%AgentContainer.add_child(agent_instance)
			agents[agent_instance.name] = agent_instance
	else:
		var agent_instance = ControllableAgentScene.instantiate()
		%AgentContainer.add_child(agent_instance)

	%GenerationLabel.text = "Generation " + str(generation)
	%ScoreLabel.text = "Previous Top Score: 0"

func _next_generation() -> void:
	generation += 1
		
	if %SkipButton.perform_skip:
		print("GOING TO: GENERATION ", generation)
		%SkipButton.perform_skip = false
		dead_agents = dead_agents.merged(agents) # turns currently existing agents into dead ones
		
	var performant_agents: Array[Agent] = complete_agents.values().duplicate()
	performant_agents.append_array(dead_agents.values().duplicate())
	performant_agents.sort_custom(func(a,b): return a.score > b.score)
	
	# Guarantees first two takes the brain of the generation's top scores
	var agent_nodes = %AgentContainer.get_children()
	best_agent = performant_agents[0]
	agent_nodes[0].brain = performant_agents[0].brain
	agent_nodes[1].brain = performant_agents[1].brain
	# Picks the rest of the agents brain through score distribution
	for i in range(2, agent_nodes.size()):
		var parent: Agent = _pick_rank_exponential(performant_agents, 0.85)
		agent_nodes[i].brain = mutate(parent.brain)

	# Update UI
	%GenerationLabel.text = "Generation " + str(generation)
	%ScoreLabel.text = "Previous Top Score: %.2f" % best_agent.score
	print("generation " + str(generation) + " score: " + str(best_agent.score))

	# then add them back to the regular agent list and reset them
	reset_agents(false)

func _get_current_decay(gen: int) -> float:
	var base_decay = BASE_DECAY * pow(DECAY_FACTOR, float(gen - 1))
	
	var t: float = clamp((best_time - FAST_TIME) / max(SLOW_TIME - FAST_TIME, 0.001), 0.0, 1.0)
	var time_factor: float = lerp(MIN_TIME_FACTOR, 1.0, t)
	
	var final_decay: float = base_decay * time_factor
	return max(final_decay, MIN_DECAY)

func _pick_rank_exponential(pool: Array[Agent], decay: float = 0.9) -> Agent:
	# Sort best to worst by score
	pool.sort_custom(func(a, b): return a.score > b.score)
	var n := pool.size()
	var total := 0.0
	var weights: Array[float] = []

	for i in range(n):
		var w := pow(decay, i)  # i = 0 is best agent
		weights.append(w)
		total += w

	var pick := randf() * total
	var accum := 0.0

	for i in range(n):
		accum += weights[i]
		if accum >= pick:
			return pool[i]

	return pool[0]  # fallback

func reset_agents(all_reset: bool) -> void:
	agents.clear()
	var resulting_agents = complete_agents.duplicate().merged(dead_agents)
	
	if all_reset: # True reset, restarts the simulation
		for agent in %AgentContainer.get_children():
			agent.queue_free()
		setup()
		# arrow trap doesnt reset, will implement once rooms are implemented
	else: # Post generation reset, called after end of generation
		for key in resulting_agents.keys():
			var agent_instance = resulting_agents[key]
			agent_instance.name = str(generation) + "-" + str(agent_instance.id)
			key = agent_instance.name
				
			agent_instance.reset_agent()
			agents[key] = agent_instance
				
	complete_agents.clear()
	dead_agents.clear()
	current_agent_count = start_agent_count

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
	current_agent_count -= 1
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
			

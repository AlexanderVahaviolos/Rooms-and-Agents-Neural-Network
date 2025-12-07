extends Node

var screen_size: Vector2i
const mutation_rate: float = 0.05

@export_category("Simulation Controls")
@export_range(10, 250, 5) var total_agents: int = 5
var spawned_agents: int = 0
var spawn_chunk: int = 0
var agent_spawn_timer: float = 0.0
@export var SPAWN_TIME: float = 0.1

# Agent Processing
## Amount of Agents to process each physics frame
@export var enable_chunking: bool = true
@export_range(2, 10, 1) var chunk_partitions: int = 5
var process_chunk: int = 0
var process_count: int = 0
var memory_update_timer: float = 0.0
@export_range(0.1, 0.3, 0.05) var MEMORY_TIMER_LIMIT: float = 0.2 

@export_group("Scenes")
@export var RoomsScene: Dictionary[String, PackedScene]
@export var AgentScene: PackedScene

@export_group("Generation Parameters")
@export_range(0, 0.2, 0.01) var best_percentage: float = 0.10
@export_range(1, 5, 1) var best_brains: int = 3
var best_cutoff: int = 0
@export_range(0.8, 0.9, 0.025) var BASE_DECAY: float = 0.85 
@export_range(0.995, 0.999, 0.0005) var DECAY_FACTOR: float = 0.9975
const MIN_DECAY: float = 0.8

@export_category("DEBUG")
@export var ControllableAgentScene: PackedScene
@export var enable_character: bool = false

var agents: Dictionary[String, Agent] = {}
var dead_agents: Dictionary[String, Agent] = {} 
var complete_agents: Dictionary[String, Agent] = {} 
var agent_neurons: int = 0

# Agent Generation data
var best_agent: Agent = null
var generation: int = 1
var best_time: float

# Room Settings

var room: Node2D
var current_room: String
var start_point: Vector2i

var FAST_TIME: float
var SLOW_TIME: float
var MIN_TIME_FACTOR: float

var check_score_timer: float = 0.0
const score_timer_limit: float = 0.5
var prev_best: Agent
var prev_worst: Agent

func _ready() -> void:
	%SkipButton.connect("pressed", Callable(self, "_next_generation"))
	randomize()
	screen_size = get_viewport().get_visible_rect().size
	setup()

# Just an agent size check
func _physics_process(delta: float) -> void:
	# SPAWNING AGENTS
	if spawned_agents != total_agents:
		agent_spawn_timer += delta
		if agent_spawn_timer >= SPAWN_TIME:
			agent_spawn_timer = 0.0
			if enable_chunking:
				var s_count: int = spawn_chunk
				if spawned_agents + spawn_chunk > total_agents:
					s_count = total_agents - spawned_agents
				_spawn_agents(s_count)
			else:
				_spawn_agents(total_agents)
		return
	
	# OUTLINER
	check_score_timer += delta
	if check_score_timer >= score_timer_limit:
		check_score_timer = 0.0
		_outline_agents()
	
	# AGENT MEMORY UPDATER
	memory_update_timer += delta
	if memory_update_timer >= MEMORY_TIMER_LIMIT:
		var dt: float = memory_update_timer
		memory_update_timer = 0.0

		var list: Array = agents.values()
		var agent_count: int = list.size()
		if agent_count == 0:
			return

		var p_count: int = 0
		if enable_chunking:
			p_count = process_chunk
			if process_count + process_chunk > agent_count:
				p_count = agent_count - process_count
		else:
			p_count = agent_count

		for i in range(p_count):
			var idx: int = process_count + i
			var agent: Agent = list[idx]
			agent.memory.update_memory()
			agent.update_score(dt)
		
		process_count += p_count
		if process_count >= agent_count:
			process_count = 0
	
	# NEXT GENERATION CHECK
	if !enable_character and !%LoopButton.button_pressed and agents.is_empty():
		print("End of Generation: ", generation)
		_next_generation()
	
func setup() -> void:
	# Initial Setup for the room and the agents
	generation = 0
	spawned_agents = 0
	memory_update_timer = 0.0
	check_score_timer = 0.0
	best_agent = null
	@warning_ignore("narrowing_conversion")
	best_cutoff = total_agents * best_percentage
	
	# Generate Room Code
	current_room = ["Room1"].pick_random()
	match(current_room):
		"Room1":
			FAST_TIME = 10.0
			SLOW_TIME = 40.0
			MIN_TIME_FACTOR = 0.85
			room = RoomsScene[current_room].instantiate()
			start_point = Vector2i(12, 60)
			%RoomContainer.add_child(room)
		_:
			push_error("Invalid room chosen: ", current_room)
	
	if enable_chunking:
		@warning_ignore("integer_division")
		process_chunk = max(1, total_agents / chunk_partitions)
		@warning_ignore("integer_division")
		spawn_chunk = max(1, total_agents / chunk_partitions)
		_spawn_agents(spawn_chunk)
	
	%GenerationLabel.text = "Generation " + str(generation)
	%ScoreLabel.text = "Previous Top Score: 0"

func _spawn_agents(count: int) -> void:
	# generate the agents
	if !enable_character:
		var current_size: int = spawned_agents
		for i in range(count):
			var agent_instance = AgentScene.instantiate()
			agent_instance.id = i + current_size
			agent_instance.name = str(generation) + "-" + str(agent_instance.id)
			agent_instance.start_position = start_point
			agent_instance.connect("send_instance", Callable(self, "_on_send_agent_instance"))
			agent_instance.add_to_group("Agents")
			%AgentContainer.add_child(agent_instance)
			agents[agent_instance.name] = agent_instance
	else:
		var agent_instance = ControllableAgentScene.instantiate()
		%AgentContainer.add_child(agent_instance)
	spawned_agents = agents.size()

func _next_generation() -> void:
	generation += 1
		
	if %SkipButton.perform_skip:
		print("GOING TO: GENERATION ", generation)
		%SkipButton.perform_skip = false
		dead_agents = dead_agents.merged(agents) # turns currently existing agents into dead ones
		
	var performant_agents: Array[Agent] = []
	performant_agents.append_array(complete_agents.values())
	performant_agents.append_array(dead_agents.values())
	performant_agents.sort_custom(func(a,b): return a.score > b.score)
	
	# Guarantees first two takes the brain of the generation's top scores
	var agent_nodes = %AgentContainer.get_children()
	best_agent = performant_agents[0]
	for i in range(best_cutoff):
		agent_nodes[i].brain = performant_agents[i % best_brains].brain
	# Picks the rest of the agents brain through score distribution
	for i in range(best_brains, agent_nodes.size()):
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
	var resulting_agents: Array[Agent] 
	resulting_agents.append_array(complete_agents.values())
	resulting_agents.append_array(dead_agents.values())
	
	if all_reset: # True reset, restarts the simulation
		print("TRUE RESET INITIATED")
		for agent in %AgentContainer.get_children():
			agent.queue_free()
		for r in %RoomContainer.get_children():
			r.queue_free()
		setup()
	else: # Post generation reset, called after end of generation
		for agent_instance in resulting_agents:
			agent_instance.name = str(generation) + "-" + str(agent_instance.id)
			agent_instance.start_position = start_point
				
			agent_instance.reset_agent()
			agent_instance.enabled(true)
			agents[agent_instance.name] = agent_instance
				
	complete_agents.clear()
	dead_agents.clear()

func _outline_agents() -> void:
	var current_agents: Array = agents.values()
	if current_agents.is_empty():
		return
	
	var best: Agent = current_agents[0]
	var worst: Agent = current_agents[0]
	
	for agent in current_agents:
		if agent.score > best.score:
			best = agent
		if agent.score < worst.score:
			worst = agent
	
	if prev_best: 
		prev_best.agent_sprite.material.set_shader_parameter(
			"outline_color", Color.from_rgba8(0, 0, 0, 0)
		)
	if prev_worst:
		prev_worst.agent_sprite.material.set_shader_parameter(
			"outline_color", Color.from_rgba8(0, 0, 0, 0)
		)	

	best.agent_sprite.material.set_shader_parameter(
		"outline_color", Color.from_rgba8(125, 255, 125, 185)
		)
	worst.agent_sprite.material.set_shader_parameter(
		"outline_color", Color.from_rgba8(255, 100, 100, 185)
		)		
		
	prev_best = best
	prev_worst = worst

func _on_send_agent_instance(agent: Agent) -> void:
	# shove them out of the way
	agent.global_position = Vector2(-10000, -10000)
	agents.erase(agent.name)	
	agent.enabled(false)
	
	if agent.death_flag:
		dead_agents[agent.name] = agent
	elif agent.completed_flag:
		complete_agents[agent.name] = agent

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
			

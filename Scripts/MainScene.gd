extends Node

var screen_size: Vector2i

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
@export var mutation_rate: float = 0.05
@export_range(0, 0.2, 0.01) var best_percentage: float = 0.10
@export_range(0, 0.3, 0.01) var complete_percentage: float = 0.20
var best_cutoff: int = 0
const MIN_DECAY: float = 0.8

@export_category("DEBUG")
@export var ControllableAgentScene: PackedScene
@export var enable_character: bool = false

var agents: Dictionary[String, Agent] = {}
var dead_agents: Dictionary[String, Agent] = {} 
var complete_agents: Dictionary[String, Agent] = {} 
var agent_neurons: int = 0

# Agent Generation data
var top_simulation_agents: Dictionary[Net, float] = {}
const TOP_AGENTS_SIZE: int = 5
var simulation_score: float = -INF
var best_generation_agent: Agent = null
var generation: int = 1
var decay_generation: int
var best_time: float

var controlled_agent: CharacterBody2D

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
	%ExportButton.connect("pressed", Callable(self, "save_simulation"))
	%ImportButton.connect("pressed", Callable(self, "load_simulation"))
	randomize()
	screen_size = get_viewport().get_visible_rect().size
	setup()

func save_simulation(path: String = "user://sim_save.json") -> void:
	var data := {}
	
	data.generation = generation
	data.total_agents = total_agents
	data.simulation_score = simulation_score
	
	data.top_agents = []
	for net in top_simulation_agents.keys():
		var rec := {
			"score": top_simulation_agents[net],
			"brain": net.to_dict(),
		}
		data.top_agents.append(rec)
		
	var json := JSON.stringify(data, "\t")
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file: ", path)
		return
	file.store_string(json)
	file.close()
	
	print("Simulation saved to : ", path)

func load_simulation(path: String = "user://sim_save.json") -> void:
	if not FileAccess.file_exists(path):
		push_error("Save file does not exist: ", path)
		return
		
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open save file: ", path)
		return
	var text := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid save data")
		return
		
	var data: Dictionary = parsed
	
	# Restore basic variables
	generation = int(data.get("generation", 1))
	total_agents = int(data.get("total_agents", total_agents))
	simulation_score = float(data.get("simulation_score", 0.0))
	
	# Restore top brains
	top_simulation_agents.clear()
	var top_datas: Array = data.get("top_agents", [])
	for rec in top_datas:
		var brain_dict: Dictionary = rec.brain
		var score: float = float(rec.score)
		var brain: Net = Net.from_dict(SimulationManager.neuron_size, brain_dict)
		top_simulation_agents[brain] = score
	
	print("Simulation loaded from: ", path)
	_start_from_load()

func _start_from_load() -> void:
	for agent in %AgentContainer.get_children():
		agent.queue_free()
		
	agents.clear()
	dead_agents.clear()
	complete_agents.clear()
	
	spawned_agents = 0
	memory_update_timer = 0.0
	check_score_timer = 0.0
	best_generation_agent = null
	@warning_ignore("narrowing_conversion")
	best_cutoff = total_agents * best_percentage
	
	_spawn_agents(total_agents)
	
	var brains: Array = top_simulation_agents.keys()
	if brains.is_empty():
		push_warning("Loaded simulation has no top_simulation_agents; using random brains.")
	else:
		var agent_nodes: Array = %AgentContainer.get_children()
		var brain_count: int = brains.size()
		
		var scores: Array[float] = top_simulation_agents.values()
		var idxs := range(brain_count)
		idxs.sort_custom(func(a, b):
			return scores[a] > scores[b]
		)
		
		for i in range(agent_nodes.size()):
			var brain: Net = brains[idxs[i % brain_count]]
			agent_nodes[i].brain = brain.clone()
			agent_nodes[i].reset_agent()
				
	_update_text()

		
func _physics_process(delta: float) -> void:
	# CHARACTER
	if enable_character:
		if spawned_agents == 0:
			_spawn_agents(1)
			spawned_agents += 1
			var ag = %AgentContainer.get_child(0)
			controlled_agent = ag
		
		memory_update_timer += delta
		if memory_update_timer >= MEMORY_TIMER_LIMIT:
			var dt: float = memory_update_timer
			memory_update_timer = 0.0
			controlled_agent.memory.update_memory()
			controlled_agent.scoring.update_score(dt)
		return
	
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
			agent.scoring.update_score(dt)
		
		process_count += p_count
		if process_count >= agent_count:
			process_count = 0
	
	# NEXT GENERATION CHECK
	if !enable_character and !%LoopButton.button_pressed and agents.is_empty():
		print("End of Generation: ", generation)
		_next_generation()

func _create_room() -> void:
	current_room = ["Room1"].pick_random()
	match current_room:
		"Room1":
			FAST_TIME = 10.0
			SLOW_TIME = 40.0
			MIN_TIME_FACTOR = 0.85
			room = RoomsScene[current_room].instantiate()
			start_point = Vector2i(12, 60)
			%RoomContainer.add_child(room)
		_:
			push_error("Invalid room chosen: ", current_room)
			
func setup() -> void:
	# Initial Setup for the room and the agents
	generation = 0
	spawned_agents = 0
	memory_update_timer = 0.0
	check_score_timer = 0.0
	best_generation_agent = null
	@warning_ignore("narrowing_conversion")
	best_cutoff = total_agents * best_percentage
	
	_create_room()
	
	if enable_chunking and !enable_character:
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
		agent_instance.start_position = start_point
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
	
	# Death Classification
	for dead_agent in dead_agents.values():
		SimulationManager.DEATHS_COUNTER[dead_agent.death_reason] += 1
	print("prom death reason: ", SimulationManager.prominent_death_reason())
	
	# Simulation Top Scorers
	var agent_nodes = %AgentContainer.get_children()
	best_generation_agent = performant_agents[0]
	var best_gen_brain: Net = performant_agents[0].brain.clone()
	
	# Top Simulation Agents
	var keys: Array[Net] = top_simulation_agents.keys()
	if top_simulation_agents.size() < TOP_AGENTS_SIZE and best_generation_agent.score > 0:
		if top_simulation_agents.size() == 0:
			decay_generation = generation
		top_simulation_agents[best_gen_brain] = best_generation_agent.score
		keys.append(best_gen_brain)
	else:
		if complete_agents.has(best_generation_agent.name):
			var keys_ascending: Array[Net] = keys.duplicate()
			keys_ascending.reverse() # Keys in Ascending Order
			for key in keys_ascending:
				if best_generation_agent.score > top_simulation_agents[key]:
					keys.erase(key)
					keys.append(best_gen_brain)
					top_simulation_agents.erase(key)
					top_simulation_agents[best_gen_brain] = best_generation_agent.score
					break
	
	var top_scorers: Array[float] = top_simulation_agents.values()
	top_scorers.sort() # Sort Ascending
	top_scorers.reverse() # Reverse to be sorted Descending
	
	if top_scorers.is_empty():
		simulation_score = best_generation_agent.score
	else:
		simulation_score = top_scorers[0]
	
	for i in range(top_simulation_agents.values().size()):
		print(i, ": ", top_simulation_agents.values()[i])
	
	# Adjust cutoff
	var cutoff = best_cutoff
	if !complete_agents.is_empty():
		cutoff = total_agents * (best_percentage + complete_percentage)
	if complete_agents.size() > (total_agents * (best_percentage/2)):
		cutoff = total_agents
	if keys.is_empty():
		cutoff = 0
	
	# Inserts Simulation's best agents
	for i in range(cutoff):
		var key: Net = keys[i % keys.size()]
		var chosen_brain = key
		if i > best_cutoff:
			agent_nodes[i].brain = mutate(chosen_brain)
		else:
			agent_nodes[i].brain = chosen_brain
	# Picks the rest of the agents brain through score distribution
	for i in range(cutoff, total_agents):
		var parent: Agent = _pick_rank_exponential(performant_agents, 0.85)
		var new_brain: Net = parent.brain.clone()
		agent_nodes[i].brain = mutate(new_brain)

	_update_text()

	# then add them back to the regular agent list and reset them
	reset_agents(false)

func _pick_rank_exponential(pool: Array[Agent], decay: float = 0.9) -> Agent:
	# Sort best to worst by score
	pool.sort_custom(func(a, b): return a.score > b.score)
	var n: int = pool.size()
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
		simulation_score = 0
		top_simulation_agents.clear()
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
			agents[agent_instance.name] = agent_instance
	
	SimulationManager.reset()
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

func _update_text() -> void:
	# Update UI
	%GenerationLabel.text = "Generation " + str(generation)
	%ScoreLabel.text = "Previous Top Score: %.2f" % simulation_score
	print("generation " + str(generation) + " score: " + str(simulation_score))

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
	var child: Net = parent_net.clone()
	
	for layer in child.layers:
		for neuron in layer.neurons:
			for w_i in range(neuron.weights.size()):
				if randf() <= mutation_rate:
					neuron.weights[w_i] = randf_range(-1.0, 1.0)
	
	return child
			

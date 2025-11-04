extends Node

var screen_size: Vector2i
const mutation_rate: float = 0.05

@export var start_agent_count: int = 5
var current_agent_count: int = start_agent_count

@export var MazeScene: PackedScene
@export var AgentScene: PackedScene

@onready var MazeContainer: Node2D = $MazeContainer
@onready var AgentContainer: Node2D = $AgentContainer

@onready var GenerationLabel: Label = $SimulationCamera/SimulationUI/Generation
@onready var ScoreLabel: Label = $SimulationCamera/SimulationUI/Score

var maze
var enter_location: Vector2i
var exit_location: Vector2i

var agents: Dictionary[String, Agent] = {}
var dead_agents: Dictionary[String, Agent] = {} # might not need
var complete_agents: Dictionary[String, Agent] = {} # complete as finished maze

var best_agent: Agent = null
var generation: int = 1

func _ready() -> void:
	randomize()
	screen_size = get_viewport().get_visible_rect().size
	_setup()

# Just an agent size check
func _physics_process(delta: float) -> void:
	if agents.size() > 0:
		pass
	else:
		generation += 1
		_next_generation()
		
func _setup() -> void:
	# Initial Setup for the maze and the agents
	
	# generate maze code
	
	# generate the agents 
	for i in range(start_agent_count):
		var agent_instance = AgentScene.instantiate()
		agent_instance.name = str(generation) + "-" + str(i)
		agent_instance.connect("send_instance", Callable(self, "_on_send_agent_instance"))
		AgentContainer.add_child(agent_instance)
		agents[agent_instance.name] = agent_instance

	GenerationLabel.text = "Generation " + str(generation)
	ScoreLabel.text = "Previous Top Score: 0"

func _next_generation() -> void:
	var performant_agents: Array[Agent]
	var dead_performant_agents: Array[Agent]
	var remainder: int = 0
	if generation != 1: # skipping first generation
		# getting the top 10 best performing agents
		# should also get best agent as a guarantee in next gen
		# + some special allocation for next gen idk yet
		
		# Check if there are completed agents
		if complete_agents.size() > 0:
			performant_agents = complete_agents.values()
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
			dead_performant_agents = dead_agents.values()
			remainder = 10 - complete_agents.size()
				
			# first section for complete agents
			performant_agents = performant_agents.slice(0, complete_agents.size())
			# second section for dead agents
			dead_performant_agents.sort_custom(func(a, b):
				return a.score > b.score
			)
			# check if this is appropriate (like do it work)
			performant_agents.append(dead_performant_agents.slice(0, remainder))
		
		best_agent = performant_agents[0]
		# score display
		print("generation " + str(generation) + " score: " + str(best_agent.score))

			
		# going to switch from deleting and then recreating, to reallocating the values
		# into the currently pre-existing instances as to not increase cost for each generation
		# so will need a setup function for both the maze and agents for this
	
	# add a weight ratio so that if say the 3rd agent did way better than the 
	# 4th agent, then it will be weighted so that the 3rd agent gets picked more
	# than the 4th and all previous agents before the 4th
	# go through all the agents and update their brain net
	for agent in AgentContainer.get_children():
		agent.brain = mutate(performant_agents[randi_range(0, 9)].brain)

func _on_agent_send_instance(agent: Agent) -> void:
	agents.erase(agent.name)
	if agent.died:
		dead_agents[agent.name] = agent
	elif agent.completed:
		complete_agents[agent.name] = agent

func mutate(parent_net: Net) -> Net:
	var mutation: Net = Net.new()
	
	for i in range(parent_net.layers.size()):
		for j in range(parent_net.layers[i].neurons.size()):
			for k in range(4): # TEMP, SHOULD BE DYNAMIC TO HOW MANY ACTUAL INPUTS THERE ARE
				if randf() <= mutation_rate:
					mutation.layers[i].neurons[j].weights.append(randf_range(-1, 1))
				else:
					mutation.layers[i].neurons[j].weights.append(parent_net.layers[i].neurons[j].weights[k])
	return mutation
			

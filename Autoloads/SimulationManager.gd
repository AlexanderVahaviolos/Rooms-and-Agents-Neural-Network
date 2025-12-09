extends Node

var neuron_size: int
const AGENT_INP_SIZE: int = 7

@export_category("Memory Parameters")
@export_range(4, 10, 1) var direct_memory: int = 4
@export_range(1, 3, 1) var exit_memory: int = 2
@export_range(1, 3, 1) var static_memory: int = 4
@export_range(20, 50, 2) var memory_decay_distance: float = 30.0
var memory_size: int
const SLOT_SIZE: int = 6

enum Detectables {
	EXIT,
	WALL,
	FIRE,
	SPIKE,
	ARROW_TRAP,
	ARROW
}

enum DeathTypes {
	BAD_SCORE,
	SPINNING,
	CIRCLING,
	STAGNATION,
	WALL_TOUCH,
	WALL_STUCK,
	NO_MOVEMENT
}

var DEATHS_COUNTER: Array

func _ready() -> void:
	var death_types_size: int = DeathTypes.size()
	DEATHS_COUNTER.resize(death_types_size)
	DEATHS_COUNTER.fill(0)
	
	var memory_slots = direct_memory + exit_memory + static_memory + 1 # +1 for arrow memory
	memory_size = memory_slots * SLOT_SIZE
	neuron_size = AGENT_INP_SIZE + memory_size

func reset() -> void:
	DEATHS_COUNTER.fill(0)

func death_classifer(death_reason: int) -> String:
	print(death_reason)
	match(death_reason):
		DeathTypes.BAD_SCORE:
			return "BAD SCORE"
		DeathTypes.SPINNING:
			return "SPINNING"
		DeathTypes.CIRCLING:
			return "CIRCLING"
		DeathTypes.STAGNATION:
			return "STAGNATION"
		DeathTypes.WALL_TOUCH:
			return "WALL TOUCH"
		DeathTypes.WALL_STUCK:
			return "WALL STUCK"
		DeathTypes.NO_MOVEMENT:
			return "NO MOVEMENT"
		_:
			return "UNIDENTIFIED"

func prominent_death_reason() -> String:
	var death_types_size: int = DeathTypes.size()
	var largest_index: int = 0
	for i in range(1, death_types_size):
		if DEATHS_COUNTER[i] > DEATHS_COUNTER[largest_index]:
			largest_index = i
	var largest_death_reason: String = death_classifer(largest_index)
	return largest_death_reason

func area_classifier(node: Node2D) -> Array:
	if node is Exit:
		return ["exit", Detectables.EXIT]
	elif node.name == "WallLayer" or node.name == "ForegroundLayer":
		return ["static", Detectables.WALL]
	elif node is FireHazard:
		return ["direct", Detectables.FIRE]
	elif node is SpikeHazard:
		return ["direct", Detectables.SPIKE]
	elif node is ArrowTrap:
		return ["static", Detectables.ARROW_TRAP]
	elif node is Arrow:
		return ["arrow", Detectables.ARROW]
	else:
		push_error(node, " is not part of the list")
		return ["", -999]
		

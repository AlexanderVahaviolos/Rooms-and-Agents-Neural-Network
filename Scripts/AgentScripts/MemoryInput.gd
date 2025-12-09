class_name MemoryInput
extends RefCounted

# Neuron inputs
var agent_reference: CharacterBody2D
var memory_inputs: Array = []

# Memory Storage
var memory_dict: Dictionary[String, Dictionary] = {}

var exit_dict: Dictionary[String, Dictionary] = {}
var direct_dict: Dictionary[String, Dictionary] = {}
var static_dict: Dictionary[String, Dictionary] = {}
var moving_dict: Dictionary[String, Dictionary] = {}

var memory_size: int
var SLOT_SIZE: int
var used_slots: int = 0
var MDD: float

var d_memory: int
var e_memory: int
var s_memory: int

# Inputs from DirectionComponent
var d_comp: DetectionComponent

func _init(ag_ref: CharacterBody2D) -> void:
	self.agent_reference = ag_ref
	self.MDD = SimulationManager.memory_decay_distance
	self.d_comp = agent_reference.detection_component
	
	self.d_memory = SimulationManager.direct_memory
	self.e_memory = SimulationManager.exit_memory
	self.s_memory = SimulationManager.static_memory
	
	self.memory_size = SimulationManager.memory_size
	self.SLOT_SIZE = SimulationManager.SLOT_SIZE
	
	d_comp.connect("send_payload", Callable(self, "_receive_payload"))
	
	memory_inputs.resize(memory_size)
	memory_inputs.fill(0.0)

func reset() -> void:	
	memory_dict.clear()
	direct_dict.clear()
	exit_dict.clear()
	static_dict.clear()
	moving_dict.clear()
	
	memory_inputs.fill(0.0)
	used_slots = 0
	
func _receive_payload(payload: Array[Array]) -> void:
	var changed: bool = false
	
	for item in payload:
		var node: Node2D = item[0]
		var point: Vector2 = item[1]
		
		var area_type: Array = SimulationManager.area_classifier(node)
		var dict_key: String = area_type[0]
		var type_value: int = area_type[1]
		
		# Check if node is already in memory and point needs to be constantly updated
		if memory_dict.has(node.name) and dict_key != "static":
			continue
		
		changed = true
		match(dict_key):
			"exit":
				exit_dict[node.name] = {"node": node, "point": point, "type": type_value}
			"direct":
				direct_dict[node.name] = {"node": node, "point": point, "type": type_value}
			"static":
				static_dict[node.name] = {"node": node, "point": point, "type": type_value}
			"arrow":
				moving_dict[node.name] = {"node": node, "point": point, "type": type_value}
			_:
				push_error("Invalid area type: ", dict_key)
	
	if changed:
		update_memory()

func _process_memory_dict(dict: Dictionary, dict_slots: int, allow_decay: bool) -> void:
	var keys_to_erase: Array[String] = []
	
	for key in dict.keys():
		var d = dict[key]
		var dir: Vector2 = (d["point"] - agent_reference.global_position)
		var dist: float = dir.length()
		
		# Constructing the Dictionary Values for the key
		memory_dict[key] = {
		"direction": dir,
		"distance": dist,
		"type": d["type"]
		}
			
		# Checking whether to append velocity or not
		if memory_dict[key]["type"] == SimulationManager.Detectables.ARROW:
			memory_dict[key]["node_direction"] = d["node"].velocity.normalized()
	
		# Checking if current memory type is Exit for scoring purposes
		if memory_dict[key]["type"] == SimulationManager.Detectables.EXIT:
			agent_reference.prev_exit_distances[key] = dist
	
		# Checking whether value is out of distance and removes it from dictionary
		if allow_decay and dist > MDD:
			keys_to_erase.append(key)
		
	# Checking if there are too many slots being used
	if dict.size() > dict_slots:
		var keys = dict.keys()
		keys.sort_custom(func(a, b):
			return memory_dict[a]["distance"] < memory_dict[b]["distance"]
		)	
		keys_to_erase.append_array(keys.slice(dict_slots, -1))
	
	for key in keys_to_erase:
		dict.erase(key)

func update_memory() -> void:
	if !exit_dict.is_empty():
		_process_memory_dict(exit_dict, e_memory, false)
	if !direct_dict.is_empty():
		_process_memory_dict(direct_dict, d_memory, true)
	if !static_dict.is_empty():
		_process_memory_dict(static_dict, s_memory, true)
	if !moving_dict.is_empty():
		_process_memory_dict(moving_dict, 1, true)
	
	_count_used_slots()
	_build_memory_inputs()

func _count_used_slots() -> void:
	used_slots = exit_dict.size() + direct_dict.size() + static_dict.size() + moving_dict.size()

func _build_memory_inputs() -> void:
	var inputs: Array[float] = []
	inputs.resize(memory_size)
	inputs.fill(0.0)
	
	var index: int = 0
	var keys: Array[String] = memory_dict.keys()
	keys.sort_custom(func(a, b):
		return memory_dict[a]["distance"] < memory_dict[b]["distance"]
	)
	
	for key in keys:
		if index + SLOT_SIZE > memory_size:
			break
	
		var d = memory_dict[key]
		var dir_vec = d["direction"].normalized()
		var dist_norm = clamp(d["distance"] / MDD, 0.0, 1.0)
		var node_dir = Vector2.ZERO
		if d["type"] == SimulationManager.Detectables.ARROW:
			node_dir = d["node_direction"]
		
		inputs[index + 0] = d["type"]
		inputs[index + 1] = dir_vec.x
		inputs[index + 2] = dir_vec.y
		inputs[index + 3] = 1.0 - dist_norm
		inputs[index + 4] = node_dir.x
		inputs[index + 5] = node_dir.y
			
		index += SLOT_SIZE
	
	memory_inputs = inputs

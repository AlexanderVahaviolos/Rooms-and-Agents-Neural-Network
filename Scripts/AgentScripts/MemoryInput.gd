class_name MemoryInput
extends RefCounted

# Neuron inputs
var agent_reference: Agent
var memory_inputs: Array

# Memory Storage
var memory_dict: Dictionary[String, Dictionary]

var exit_dict: Dictionary[String, Array]
var direct_dict: Dictionary[String, Array]
var static_dict: Dictionary[String, Array]
var moving_dict: Dictionary[String, Array]

var memory_slots: int 
var memory_size: int
var used_slots: int = 0
var slot_size: int = 4
var MDD: float

var d_memory: int
var e_memory: int
var s_memory: int

# Inputs from DirectionComponent
var d_comp: DetectionComponent

func _init(ag_ref: Node2D) -> void:
	self.agent_reference = ag_ref
	self.MDD = agent_reference.memory_decay_distance
	self.d_comp = agent_reference.detection_component
	
	self.d_memory = agent_reference.direct_memory
	self.e_memory = agent_reference.exit_memory
	self.s_memory = agent_reference.static_memory
	
	d_comp.connect("area_entered", Callable(self, "_insert_area"))
	d_comp.connect("static_detected", Callable(self, "_insert_area"))
	
	memory_slots = d_memory + e_memory + s_memory + 1 # +1 for arrow memory
	memory_size = memory_slots * slot_size + 2 # +2 for arrows
	
	memory_inputs.resize(memory_slots)
	memory_inputs.fill(0.0)

func reset() -> void:	
	memory_dict.clear()
	direct_dict.clear()
	exit_dict.clear()
	static_dict.clear()
	moving_dict.clear()
	
	memory_inputs.fill(0.0)
	used_slots = 0
	
func _insert_area(area: Node2D) -> void:
	var area_type: Array
	if not area is RayCast2D:
		area_type = SimulationManager.area_classifier(area)
	else:
		area_type = SimulationManager.area_classifier(area.get_collider())
	
	var dict_key: String = area_type[0]
	var type_value: int = area_type[1]
	used_slots += 1

	match(dict_key):
		"exit":
			exit_dict[area.name] = [area, type_value]
		"direct":
			direct_dict[area.name] = [area, type_value]
		"static":
			static_dict[area.name] = [area, type_value]
		"arrow":
			moving_dict[area.name] = [area, type_value]
		_:
			push_error("Invalid area type: ", dict_key)
	update_memory()

func update_memory() -> void:
	
	# Helper function
	var _get_memory_info = func(dict: Dictionary, dict_slots: int):
		for key in dict.keys():
			var d = dict[key]
			var dir: Vector2
			
			if !d[0] is RayCast2D: # Checking if it's from a raycast or not
				dir = (d[0].global_position - agent_reference.global_position)
			else:
				dir = (d[0].get_collision_point() - agent_reference.global_position)
			var dist: float = dir.length()
		
			# Constructing the Dictionary Values for the key
			memory_dict[key] = {
			"direction": dir,
			"distance": dist,
			"type": d[1]
			}
			
			# Checking whether to append velocity or not
			if memory_dict[key]["type"] == SimulationManager.Detectables.ARROW:
				memory_dict[key]["projectile_direction"] = d[0].velocity.normalized()
	
			# Checking if current memory type is Exit for scoring purposes
			if memory_dict[key]["type"] == SimulationManager.Detectables.EXIT:
				agent_reference.prev_exit_distances[key] = dist
	
			# Checking whether value is out of distance and removes it from dictionary
			if dist > agent_reference.memory_decay_distance and dict != exit_dict:
				dict.erase(key)
				used_slots -= 1
	
		# Checking if there are too many slots being used
		if dict.size() > dict_slots:
			var keys = dict.keys()
			keys.sort_custom(func(a, b):
				return memory_dict[a]["distance"] < memory_dict[b]["distance"]
			)
				
			# Remove excess key(s)
			for i in range(dict_slots, keys.size()):
				dict.erase(keys[i])
				used_slots -= 1
	
	if !exit_dict.is_empty():
		_get_memory_info.call(exit_dict, e_memory)
	if !direct_dict.is_empty():
		_get_memory_info.call(direct_dict, d_memory)
	if !static_dict.is_empty():
		_get_memory_info.call(static_dict, s_memory)
	if !moving_dict.is_empty():
		_get_memory_info.call(moving_dict, 1)
		
	_build_memory_inputs()
	
func _build_memory_inputs() -> void:
	var inputs: Array[float] = []
	
	for key in memory_dict.keys():
		var d = memory_dict[key]
		var dir_vec = d["direction"].normalized()
		var dist_norm = clamp(d["distance"] / MDD, 0.0, 1.0)
		if not d["type"] == SimulationManager.Detectables.ARROW:
			inputs.append_array([d["type"], dir_vec.x, dir_vec.y, 1.0 - dist_norm])
		else:
			# put velocity as well
			var arrow_dir = d["projectile_direction"]
			inputs.append_array([d["type"], dir_vec.x, dir_vec.y, arrow_dir.x, arrow_dir.y, 1.0 - dist_norm])
	
	# Padding to make it a fixed size
	var remaining = memory_slots - used_slots
	for i in range(remaining):
		inputs.append_array([0.0, 0.0, 0.0, 0.0])
	
	memory_inputs = inputs

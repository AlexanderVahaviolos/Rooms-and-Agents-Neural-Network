extends RefCounted
class_name Net

var layers: Array[Layer] = []
var neuron_size: int

func _init(input_size: int) -> void:
	neuron_size = input_size
	# input -> hidden1 (3 neurons)
	layers.push_back(Layer.new(3, input_size))
	# hidden1 -> hidden2 (3 neurons)
	layers.push_back(Layer.new(3, 3)) 
	# hidden2 -> output (2 neurons)
	layers.push_back(Layer.new(2, 3)) 

func clone() -> Net:
	var net_clone: Net = Net.new(neuron_size)
	net_clone.layers.clear()
	
	for layer in layers:
		net_clone.layers.append(layer.clone())
	return net_clone

func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data.layers = []
	for l in layers:
		data.layers.append(l.to_dict())
	return data
	
static func from_dict(input_size: int, data: Dictionary) -> Net:
	var n: Net = Net.new(input_size)
	n.layers.clear()
	
	for layer_data in data["layers"]:
		var neuron_datas: Array = layer_data["neurons"]
		if neuron_datas.is_empty():
			continue
			
		var neuron_count: int = neuron_datas.size()
		var neuron_weights_any: Array = neuron_datas[0]["weights"]
		var layer_input_size: int = neuron_weights_any.size() - 1
		
		var layer: Layer = Layer.new(neuron_count, layer_input_size)
		for j in range(neuron_count):
			var neuron_data: Dictionary = neuron_datas[j]
			var saved_any: Array = neuron_data["weights"]
			
			var w: Array[float] = []
			w.resize(saved_any.size())
			for k in range(saved_any.size()):
				w[k] = float(saved_any[k])
				
			layer.neurons[j].weights = w
			
		n.layers.append(layer)

	return n

func predict(input: Array) -> Array[float]:
	var x: Array[float] = input
	for layer in layers:
		x = layer.predict(x)
	# Last layer has 2 neurons
	return x

extends RefCounted
class_name Layer

var neurons: Array[Neuron] = []

func _init(numNeurons: int, input_size: int) -> void:
	for i in range(numNeurons):
		neurons.push_back(Neuron.new(input_size))

func clone() -> Layer:
	var layer_clone: Layer = Layer.new(0, 0)
	layer_clone.neurons.clear()
	
	for neuron in neurons:
		layer_clone.neurons.append(neuron.clone())
	return layer_clone

func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data.neurons = []
	for n in neurons:
		data.neurons.append(n.to_dict())
	return data
	
func predict(input: Array) -> Array:
	var output: Array[float] = []
	output.resize(neurons.size())
	for i in range(neurons.size()):
		output[i] = neurons[i].predict(input)
	return output

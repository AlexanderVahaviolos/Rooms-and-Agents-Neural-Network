extends Resource
class_name Layer

var neurons: Array[Neuron] = []

func _init(numNeurons: int) -> void:
	for i in range(numNeurons):
		neurons.push_back(Neuron.new())

func predict(input: Array) -> Array:
	var output: Array = []
	
	for neuron in neurons:
		output.push_back(neuron.predict(input))
	return output

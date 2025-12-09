class_name Neuron
extends RefCounted

var weights: Array[float] = []

func _init(input_size: int) -> void:
	weights.resize(input_size + 1) # + 1 for bias
	for i in range(input_size + 1):
		weights[i] = randf_range(-1.0, 1.0)

func clone() -> Neuron:
	var neuron_clone: Neuron = Neuron.new(weights.size() - 1)
	neuron_clone.weights = weights.duplicate()
	return neuron_clone

func to_dict() -> Dictionary:
	return {
		"weights": weights.duplicate()
	}

func predict(input: Array) -> float:
	var sum: float = 0.0
		
	# Weighted sum
	for i in range(input.size()):
		sum += weights[i] * input[i]
			
	# Add bias
	sum += weights[weights.size() - 1]
	
	var output = tanh(sum) # value between -1 and 1
	return output

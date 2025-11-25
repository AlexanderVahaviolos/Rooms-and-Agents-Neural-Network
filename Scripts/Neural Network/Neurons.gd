class_name Neuron
extends RefCounted

var weights: Array[float] = []

func predict(input: Array) -> float:
	while weights.size() < input.size():
		weights.append(randf_range(-1.0, 1.0))
		
	var sum: float = 0.0
		
	# Weighted sum
	for i in input.size():
		sum += weights[i] * input[i]
			
	# Add bias
	sum += weights[weights.size() - 1]
	
	var output = tanh(sum) # value between -1 and 1
	return output

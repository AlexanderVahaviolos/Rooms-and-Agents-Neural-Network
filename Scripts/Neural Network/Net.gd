extends RefCounted
class_name Net

var layers: Array[Layer] = []

func _init() -> void:
	layers.push_back(Layer.new(3)) # first hidden layer, 3 neurons
	layers.push_back(Layer.new(3)) # second hidden layer, 3 neurons
	layers.push_back(Layer.new(3)) # output layer, 2 neuron that decides x and y velocity
	
func predict(input: Array):
	for layer in layers:
		input = layer.predict(input) # each layer creates the input for the next layer
	
	return [Vector2(input[0], input[1]), input[2]]

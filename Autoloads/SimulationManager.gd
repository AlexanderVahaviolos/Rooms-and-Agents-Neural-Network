extends Node

enum Detectables {
	EXIT,
	WALL,
	FIRE,
	SPIKE,
	ARROW_TRAP,
	ARROW
}

func area_classifier(node: Node2D) -> Array:
	if node is Exit:
		return ["exit", Detectables.EXIT]
	elif node.name == "WallLayer":
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
		

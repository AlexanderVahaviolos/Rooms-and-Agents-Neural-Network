extends Node

enum Detectables {
	EXIT,
	WALL,
	FIRE,
	SPIKE,
	ARROW_TRAP,
	ARROW
}

func type_classifier(node: Node2D) -> int:
	if node is Exit:
		return Detectables.EXIT
	elif node.name == "WallLayer":
		return Detectables.WALL
	elif node is FireHazard:
		return Detectables.FIRE
	elif node is SpikeHazard:
		return Detectables.SPIKE
	elif node is ArrowTrap:
		return Detectables.ARROW_TRAP
	elif node is Arrow:
		return Detectables.ARROW
	else:
		push_error(node, " is not part of the list")
		return -999
		

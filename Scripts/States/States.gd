@abstract
class_name State extends Node

@export var state_name : String

@abstract func enter(entity: Node2D)
@abstract func exit(entity: Node2D)
@abstract func update(entity: Node2D, delta)
@abstract func physics_update(entity: Node2D, delta)

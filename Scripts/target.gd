extends RigidBody2D

func _ready() -> void:
	self.connect("body_entered", Callable(self, "_on_body_entered"))
	self.connect("body_shape_entered", Callable(self, "_on_shape_entered"))

func _move_self(other: Node2D) -> void:
	pass

func _on_body_entered(body: Node) -> void:
	print(body.name)
	
func _on_shape_entered(body_rid: RID, body: Node, BSI: int, LSI: int) -> void:
	print(body.name)

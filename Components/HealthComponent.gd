extends Node
class_name HealthComponent

signal health_changed(current: int, max: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export var max_health: int:
	set(value):
		max_health = value
		current_health = value
@export var current_health: int

@export var defense : int = 10

func apply_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	current_health = max(current_health - amount, 0)
	
	emit_signal("damaged", amount)
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		emit_signal("died")
		
func heal(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	current_health = min(current_health + amount, max_health)
	emit_signal("healed", amount)
	emit_signal("health_changed", current_health, max_health)

func kill() -> void:
	apply_damage(current_health)
	
func reset_health() -> void:
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

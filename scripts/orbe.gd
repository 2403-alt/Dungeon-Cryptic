extends Area2D

signal collected

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		queue_free()
	pass # Replace with function body.

extends Area2D

@export var amount: int = 5

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("add_stones"):
		body.add_stones(amount)
		queue_free()

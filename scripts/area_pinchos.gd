extends Area2D

@export var damage_amount: int = 10
@export var damage_interval: float = 1.0

var player_inside: Node2D = null
var damage_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if player_inside == null:
		return

	if not is_instance_valid(player_inside):
		player_inside = null
		return

	damage_timer += delta

	if damage_timer >= damage_interval:
		damage_timer = 0.0

		if player_inside.has_method("damage"):
			player_inside.damage(damage_amount, true)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = body
		damage_timer = damage_interval

func _on_body_exited(body: Node2D) -> void:
	if body == player_inside:
		player_inside = null
		damage_timer = 0.0

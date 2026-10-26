
extends Area2D

@export var speed: float = 300.0
@export var damage: int = 10
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.RIGHT
var shooter: Node2D = null
var has_hit: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	await get_tree().create_timer(lifetime).timeout

	if is_inside_tree():
		queue_free()


func launch(
	shoot_direction: Vector2,
	owner_node: Node2D,
	projectile_damage: int
) -> void:
	direction = shoot_direction.normalized()
	shooter = owner_node
	damage = projectile_damage


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if has_hit or body == shooter:
		return

	if body.is_in_group("enemies"):
		return

	has_hit = true

	if body.is_in_group("player"):
		if body.has_method("damage"):
			body.damage(damage)
		elif body.has_method("take_damage"):
			body.take_damage(damage)

	queue_free()

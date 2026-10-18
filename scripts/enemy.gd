extends CharacterBody2D

@export var speed: float = 400.0
@export var hurt: int = 1

var direction: int = 1
var initial_position: Vector2

@onready var attackarea: Area2D = $attackarea

func _ready() -> void:
	initial_position = position
	attackarea.body_entered.connect(_on_attackarea_body_entered)

func _physics_process(delta: float) -> void:
	position.x += speed * direction * delta
	var screen_widht := get_viewport_rect().size.x
	var margin := 60.0
	if global_position.x >= screen_widht - margin:
		direction = -1
	elif global_position.x <= margin:
		direction = 1

func _on_attackarea_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("damage"):
		position = initial_position
		direction *= -1
		body.damage(hurt)

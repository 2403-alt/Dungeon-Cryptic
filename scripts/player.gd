extends CharacterBody2D

@onready var animation = $bro

signal health_changed(health_current: int, health_max: int)
signal died

const SPEED: float = 300.0
const JUMP_VELOCITY: float = -400.0
const MAX_JUMPS: int = 2
var initial_position: Vector2

@export var health_max: int = 3
var health: int = 3
var jumps: int = 0
var invulnerable: bool = false
var defeated: bool = false

func _ready() -> void:
	initial_position = position
	add_to_group("player")
	health = health_max
	health_changed.emit(health, health_max)

func damage(amount: int = 1) -> void:
	animation.play("hurt")
	position = initial_position
	if invulnerable or defeated:
		return
	health = max(health - amount, 0)
	health_changed.emit(health, health_max)
	print("Intentos restantes: ", health)
	if health <= 0:
		defeated = true
		died.emit()
		set_physics_process(false)
		return
	# Evita perder varios intentos seguidos mientras el balón sigue cerca.
	invulnerable = true
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree() and not defeated:
		invulnerable = false

func _physics_process(delta: float) -> void:
	if defeated:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		jumps = 0
	if Input.is_action_just_pressed("ui_accept") and jumps < MAX_JUMPS:
		velocity.y = JUMP_VELOCITY
		jumps += 1
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()

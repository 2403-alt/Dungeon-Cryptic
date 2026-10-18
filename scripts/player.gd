extends CharacterBody2D

@onready var animation: AnimatedSprite2D = $bro
@onready var smoke_jump = $doble_jump
@export var invulnerability_time: float = 1.0
@export var health_max: int = 3

signal health_changed(health_current: int, health_max: int)
signal died

const SPEED: float = 300.0
const JUMP_VELOCITY: float = -425.0
const MAX_JUMPS: int = 2

var initial_position: Vector2
var health: int = 3
var jumps: int = 0
var invulnerable: bool = false
var defeated: bool = false

func _ready() -> void:
	initial_position = position
	add_to_group("player")
	health = health_max
	animation.play("walk")
	animation.pause()
	animation.frame = 0
	health_changed.emit(health, health_max)

func damage(amount: int = 1) -> void:
	# Ignora impactos repetidos durante la invulnerabilidad.
	if invulnerable or defeated:
		return

	invulnerable = true
	health = max(health - amount, 0)
	health_changed.emit(health, health_max)
	print("Intentos restantes: ", health)

	if health <= 0:
		defeated = true
		velocity = Vector2.ZERO
		animation.play("death")
		died.emit()
		set_physics_process(false)
		return

	# Conserva el comportamiento actual: al recibir daño, vuelve al inicio.
	position = initial_position
	velocity = Vector2.ZERO
	jumps = 0
	animation.play("hurt")

	await get_tree().create_timer(invulnerability_time).timeout
	if is_inside_tree() and not defeated:
		invulnerable = false
		_update_animation()

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
		if jumps == 1:
			animation.play("jump")
		else:
			animation.play("jump")
			smoke_jump.visible = true
			smoke_jump.play("doble_jump")

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * SPEED
		animation.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_update_animation()

func _update_animation() -> void:
	if defeated:
		if animation.animation != "death":
			animation.play("death")
		return

	# La animación de daño tiene prioridad durante toda la invulnerabilidad.
	if invulnerable:
		if animation.animation != "hurt":
			animation.play("hurt")
		return

	if not is_on_floor():
		# No reiniciar la animación en cada fotograma.
		if animation.animation != "jump" and animation.animation != "doble_jump":
			animation.play("jump")
	elif absf(velocity.x) > 5.0:
		if animation.animation != "run":
			animation.play("run")
	else:
		# No existe animación idle en este SpriteFrames; dejamos el primer frame de walk.
		if animation.animation != "walk":
			animation.play("walk")
			animation.pause()
			animation.frame = 0

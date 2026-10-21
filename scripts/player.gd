extends CharacterBody2D

@onready var animation: AnimatedSprite2D = $bro
@onready var smoke_jump = $doble_jump
@onready var attack: AnimatedSprite2D = $attack
@onready var attack_area: Area2D = $AttackArea


@export var attack_damage: int = 20
@export var attack_cooldown: float = 0.2
@export var invulnerability_time: float = 1.0
@export var health_max: int = 100

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
var enemies_hit: Array[Node2D] = []

var attacking: bool = false
var attack_timer: float = 0.0
var attack_hit: bool = false

func _ready() -> void:
	initial_position = position
	add_to_group("player")
	health = health_max
	animation.play("idle")
	smoke_jump.visible = false
	attack.visible = false

	health_changed.emit(health, health_max)

func damage(amount: int = 1) -> void:
	if invulnerable or defeated:
		return

	invulnerable = true
	health = max(health - amount, 0)
	health_changed.emit(health, health_max)

	if health <= 0:
		defeated = true
		attacking = false
		velocity = Vector2.ZERO
		attack.visible = false
		animation.play("death")
		died.emit()
		set_physics_process(false)
		return

	await get_tree().create_timer(invulnerability_time).timeout
	if is_inside_tree() and not defeated:
		invulnerable = false
		_update_animation()

func _physics_process(delta: float) -> void:
	if defeated:
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	if is_on_floor():
		jumps = 0
		smoke_jump.visible = false
	elif jumps == 0:
		jumps = 1

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor() and jumps == 0:
			velocity.y = JUMP_VELOCITY
			jumps += 1
			animation.play("jump")
		elif not is_on_floor() and jumps == 1:
			velocity.y = JUMP_VELOCITY
			jumps = 2
			animation.play("jump")
			animation.frame = 0
			smoke_jump.visible = true
			smoke_jump.play("doble_jump")

	var direction := Input.get_axis("ui_left", "ui_right")

	if direction != 0:
		velocity.x = direction * SPEED
		animation.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if Input.is_action_just_pressed("player_attack") and attack_timer <= 0.0 and not attacking:
		_start_attack()
		
	move_and_slide()
	_update_animation()

func _start_attack() -> void:
	enemies_hit.clear()
	attacking = true
	animation.visible = false
	attack_hit = false
	enemies_hit.clear()
	attack_timer = attack_cooldown

	attack.visible = true
	attack.flip_h = animation.flip_h
	attack.frame = 0

	if absf(velocity.x) > 5.0:
		attack.play("attack_walk")
	else:
		attack.play("attack")
	
	_deal_attack_damage()
		
func _update_animation() -> void:
	if defeated:
		if animation.animation != "death":
			animation.play("death")
		return

	if invulnerable:
		if animation.animation != "hurt":
			animation.play("hurt")
		return

	if attacking:
		return

	attack.visible = false

	if not is_on_floor():
		if animation.animation != "jump":
			animation.play("jump")
	elif absf(velocity.x) > 5.0:
		if animation.animation != "run":
			animation.play("run")
	else:
		if animation.animation != "idle":
			animation.play("idle")

func _on_attack_animation_finished() -> void:
	attacking = false
	attack.stop()
	attack.frame = 0
	attack.visible = false
	animation.visible = true
	_update_animation()

func _deal_attack_damage() -> void:
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("enemies") and not enemies_hit.has(body):
			if body.has_method("take_damage"):
				body.take_damage(attack_damage)
				enemies_hit.append(body)

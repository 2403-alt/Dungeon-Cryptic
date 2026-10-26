extends CharacterBody2D

@onready var animation: AnimatedSprite2D = $bro
@onready var smoke_jump = $doble_jump
@onready var attack: AnimatedSprite2D = $attack
@onready var attack_area: Area2D = $AttackArea
@onready var attack_sound: AudioStreamPlayer = $AttackSound
@onready var collect_sound: AudioStreamPlayer = $CollectedSound
@onready var damage_sound: AudioStreamPlayer = $DamageSound
@onready var jump_sound: AudioStreamPlayer = $JumpSound
@onready var doublejump_sound: AudioStreamPlayer = $DobleJumpSound
@onready var throw_animation: AnimatedSprite2D = $ThrowAnimation
@onready var throw_sound: AudioStreamPlayer = $ThrowSound
@onready var run_sound: AudioStreamPlayer = $RunSound

@export var attack_damage: int = 20
@export var attack_cooldown: float = 0.2
@export var invulnerability_time: float = 0.5
@export var health_max: int = 100
@export var stone_scene: PackedScene
@export var max_stones: int = 10


signal health_changed(health_current: int, health_max: int)
signal died
signal stones_changed(current: int, maximum: int)

const SPEED: float = 300.0
const JUMP_VELOCITY: float = -425.0
const MAX_JUMPS: int = 2

var initial_position: Vector2
var health: int = 100
var jumps: int = 0
var invulnerable: bool = false
var defeated: bool = false
var enemies_hit: Array[Node2D] = []
var playing_hurt: bool = false

var attacking: bool = false
var attack_timer: float = 0.0
var attack_hit: bool = false
var stones: int = 3
var throwing_stone: bool = false

func _ready() -> void:
	throw_animation.visible = false
	initial_position = position
	add_to_group("player")
	health = health_max
	animation.play("idle")
	smoke_jump.visible = false
	attack.visible = false
	
	if run_sound.stream is AudioStreamWAV:
		var run_audio := run_sound.stream as AudioStreamWAV
		run_audio.loop_mode = AudioStreamWAV.LOOP_FORWARD

	health_changed.emit(health, health_max)
	stones_changed.emit(stones, max_stones)


func damage(amount: int = 1, ignore_invulnerability: bool = false) -> void:
	if defeated:
		return

	if invulnerable and not ignore_invulnerability:
		return

	if not ignore_invulnerability:
		invulnerable = true

	health = max(health - amount, 0)
	health_changed.emit(health, health_max)
	damage_sound.play()

	if health <= 0:
		defeated = true
		playing_hurt = false
		attacking = false
		velocity = Vector2.ZERO
		attack.visible = false
		animation.visible = true
		animation.play("death")
		died.emit()
		set_physics_process(false)
		return

	attacking = false
	attack.visible = false
	animation.visible = true

	playing_hurt = true
	animation.play("hurt")

	await animation.animation_finished

	if not is_inside_tree() or defeated:
		return

	playing_hurt = false

	if not ignore_invulnerability:
		await get_tree().create_timer(invulnerability_time).timeout

		if not is_inside_tree() or defeated:
			return

		invulnerable = false

	_update_animation()



func _physics_process(delta: float) -> void:
	if defeated:
		return

	if throwing_stone:
		velocity.x = 0.0

		if not is_on_floor():
			velocity += get_gravity() * delta

		move_and_slide()
		_update_run_sound()
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
			jump_sound.play()
			animation.play("jump")

		elif not is_on_floor() and jumps == 1:
			velocity.y = JUMP_VELOCITY
			jumps = 2
			doublejump_sound.play()
			animation.play("jump")
			animation.frame = 0
			smoke_jump.visible = true
			smoke_jump.play("doublejump_sound")

	# Movimiento horizontal: conserva la velocidad original.
	var direction := Input.get_axis("ui_left", "ui_right")

	if direction != 0:
		velocity.x = direction * SPEED
		animation.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if Input.is_action_just_pressed("player_attack") and attack_timer <= 0.0 and not attacking:
		_start_attack()

	if Input.is_action_just_pressed("throw_stone"):
		throw_stone()

	# Mover al personaje una sola vez por fotograma.
	move_and_slide()

	_update_run_sound()
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
	
	attack_sound.play()
	_deal_attack_damage()
	
func _update_animation() -> void:
	if defeated:
		if animation.animation != "death":
			animation.play("death")
		return

	if playing_hurt:
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
	if throwing_stone:
		return
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
				
func collect_orbe() -> void:
	if not collect_sound.playing:
		collect_sound.play()
	else:
		collect_sound.stop()
		collect_sound.play()
		
func heal_on_enemy_kill() -> void:
	if defeated or health <= 0:
		return

	var heal_amount: int = 5
	health = mini(health + heal_amount, health_max)

	health_changed.emit(health, health_max)
	
func throw_stone() -> void:
	if defeated or attacking or throwing_stone:
		return

	if stones <= 0:
		return

	if stone_scene == null:
		push_warning("No se ha asignado stone.tscn al jugador.")
		return

	throwing_stone = true
	stones -= 1
	stones_changed.emit(stones, max_stones)

	var direction := -1.0 if animation.flip_h else 1.0

	velocity.x = 0
	animation.visible = false
	attack.visible = false

	throw_animation.visible = true
	throw_animation.flip_h = animation.flip_h
	throw_animation.frame = 0
	throw_animation.play("attack_throw")
	throw_sound.play()

	await throw_animation.animation_finished

	if not is_inside_tree():
		return

	if not defeated:
		var stone = stone_scene.instantiate()
		get_tree().current_scene.add_child(stone)
		stone.global_position = global_position + Vector2(25.0 * direction, -10.0)
		stone.launch(direction, self)

	throw_animation.stop()
	throw_animation.visible = false
	animation.visible = true
	throwing_stone = false
	_update_animation()
	
func add_stones(amount: int = 1) -> void:
	var previous_stones := stones
	stones = mini(stones + amount, max_stones)

	if stones != previous_stones:
		stones_changed.emit(stones, max_stones)
		

func _update_run_sound() -> void:
	var should_play := (
		is_on_floor()
		and absf(velocity.x) > 5.0
		and not defeated
		and not throwing_stone
	)

	if should_play:
		if not run_sound.playing:
			run_sound.play()
	elif run_sound.playing:
		run_sound.stop()

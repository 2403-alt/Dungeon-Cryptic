
extends CharacterBody2D

signal killed

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	RETURN
}

@export var patrol_speed: float = 70.0
@export var chase_speed: float = 115.0
@export var arrival_distance: float = 12.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0

@export var knockback_force: float = 250.0
@export var knockback_upward: float = 80.0
@export var knockback_duration: float = 0.2

@export var idle_duration: float = 1.0
@export var repath_distance: float = 8.0
@export var max_health: int = 100

# Disparos
@export var projectile_scene: PackedScene
@export var projectile_damage: int = 10
@export var shoot_cooldown: float = 1.5

# Protección después de recibir un golpe
@export var damage_invulnerability: float = 0.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var shoot_range: Area2D = $ShootRange
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var patrol_a: Marker2D = $PositionPatrolA
@onready var patrol_b: Marker2D = $PositionPatrolB
@onready var healthbar: TextureProgressBar = $HealthBar

@onready var shoot_timer: Timer = $ShootTimer
@onready var muzzle: Marker2D = $Muzzle

var health: int = 100
var is_dead: bool = false
var state: State = State.IDLE
var player: CharacterBody2D = null

var home_position: Vector2
var patrol_positions: Array[Vector2] = []
var patrol_index: int = 0

var idle_timer: float = 0.0
var attack_timer: float = 0.0
var damage_invulnerability_timer: float = 0.0

var facing_direction: String = "right"
var navigation_ready: bool = false

var knockback_timer: float = 0.0
var knockback_direction: float = 0.0


func _ready() -> void:
	add_to_group("enemies")

	home_position = global_position

	health = max_health
	healthbar.max_value = max_health
	healthbar.value = health

	patrol_positions = [
		patrol_a.global_position,
		patrol_b.global_position
	]

	navigation_agent.path_desired_distance = 8.0
	navigation_agent.target_desired_distance = 10.0
	navigation_agent.avoidance_enabled = false

	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	shoot_range.body_entered.connect(_on_shoot_range_body_entered)
	shoot_range.body_exited.connect(_on_shoot_range_body_exited)

	shoot_timer.stop()
	shoot_timer.wait_time = maxf(shoot_cooldown, 0.1)
	shoot_timer.one_shot = true
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)

	state = State.IDLE
	idle_timer = idle_duration
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

	call_deferred("_initialize_navigation")


func _initialize_navigation() -> void:
	await get_tree().physics_frame

	if not is_inside_tree():
		return

	navigation_ready = true
	navigation_agent.target_position = home_position


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	# Reducir el tiempo de invulnerabilidad.
	damage_invulnerability_timer = maxf(
		damage_invulnerability_timer - delta,
		0.0
	)

	attack_timer = maxf(attack_timer - delta, 0.0)


	update_shooting()

	if not navigation_ready:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif knockback_timer <= 0.0:
		velocity.y = 0.0

	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity.x = knockback_direction * knockback_force

		update_facing_direction(Vector2(velocity.x, 0.0))
		move_and_slide()
		update_animation()
		return

	if state == State.CHASE or state == State.ATTACK:
		evaluate_decision()

	match state:
		State.IDLE:
			process_idle(delta)
		State.PATROL:
			process_patrol()
		State.CHASE:
			process_chase()
		State.ATTACK:
			process_attack()
		State.RETURN:
			process_return()

	move_and_slide()
	update_animation()


func process_idle(delta: float) -> void:
	velocity.x = 0.0
	idle_timer -= delta

	if idle_timer <= 0.0:
		change_state(State.PATROL)


func process_patrol() -> void:
	if patrol_positions.is_empty():
		velocity.x = 0.0
		return

	var target: Vector2 = patrol_positions[patrol_index]
	navigate_to(target, patrol_speed)

	if global_position.distance_to(target) <= arrival_distance:
		velocity.x = 0.0
		patrol_index = (patrol_index + 1) % patrol_positions.size()
		change_state(State.IDLE)


func process_chase() -> void:
	if not is_instance_valid(player):
		player = null
		change_state(State.RETURN)
		return

	if not is_player_alive():
		player = null
		change_state(State.RETURN)
		return

	if is_player_in_attack_range():
		velocity.x = 0.0
		change_state(State.ATTACK)
		return

	navigate_to(player.global_position, chase_speed)


func process_attack() -> void:
	velocity.x = 0.0

	if not is_instance_valid(player) or not is_player_alive():
		player = null
		change_state(State.RETURN)
		return

	if not is_player_in_attack_range():
		change_state(State.CHASE)
		return

	var direction: Vector2 = player.global_position - global_position
	update_facing_direction(direction)

	if attack_timer <= 0.0:
		sprite.play("attack")

		if player.has_method("damage"):
			player.damage(attack_damage)
		elif player.has_method("take_damage"):
			player.take_damage(attack_damage)

		attack_timer = attack_cooldown


func process_return() -> void:
	navigate_to(home_position, patrol_speed)

	if global_position.distance_to(home_position) <= arrival_distance:
		velocity.x = 0.0
		change_state(State.IDLE)


# RECIBIR DAÑO

func take_damage(amount: int) -> void:
	if is_dead or damage_invulnerability_timer > 0.0:
		return

	health = maxi(health - amount, 0)
	healthbar.value = health

	if health <= 0:
		die()
		return


	damage_invulnerability_timer = damage_invulnerability

	sprite.play("hurt")

	if is_instance_valid(player):
		if player.global_position.x < global_position.x:
			knockback_direction = 1.0
		else:
			knockback_direction = -1.0
	else:
		knockback_direction = -1.0 if facing_direction == "right" else 1.0

	velocity.x = knockback_direction * knockback_force
	velocity.y = -knockback_upward
	knockback_timer = knockback_duration


func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	shoot_timer.stop()

	killed.emit()

	if is_instance_valid(player) and player.has_method("heal_on_enemy_kill"):
		player.heal_on_enemy_kill()

	queue_free()


func navigate_to(target: Vector2, movement_speed: float) -> void:
	if not navigation_ready:
		velocity.x = 0.0
		return

	if navigation_agent.target_position.distance_to(target) > repath_distance:
		navigation_agent.target_position = target

	if navigation_agent.is_navigation_finished():
		velocity.x = 0.0
		return

	var next_position: Vector2 = navigation_agent.get_next_path_position()
	var direction: Vector2 = global_position.direction_to(next_position)

	velocity.x = direction.x * movement_speed

	if absf(velocity.x) > 1.0:
		update_facing_direction(Vector2(velocity.x, 0.0))


func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body is CharacterBody2D:
		player = body as CharacterBody2D
		change_state(State.CHASE)


func _on_detection_body_exited(body: Node2D) -> void:
	if body == player and not shoot_range.overlaps_body(body):
		player = null
		change_state(State.RETURN)


func _on_shoot_range_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body is CharacterBody2D:
		player = body as CharacterBody2D


func _on_shoot_range_body_exited(body: Node2D) -> void:
	if body == player and not detection_area.overlaps_body(body):
		player = null
		shoot_timer.stop()
		if state == State.CHASE or state == State.ATTACK:
			change_state(State.RETURN)


func is_player_in_attack_range() -> bool:
	if not is_instance_valid(player):
		return false

	return attack_area.overlaps_body(player)


func is_player_alive() -> bool:
	if not is_instance_valid(player):
		return false

	if "is_dead" in player and player.is_dead:
		return false

	return true


func evaluate_decision() -> void:
	if is_dead:
		return

	if not is_instance_valid(player) or not is_player_alive():
		player = null
		change_state(State.RETURN)
		return

	if is_player_in_attack_range():
		change_state(State.ATTACK)
	else:
		change_state(State.CHASE)


func change_state(new_state: State) -> void:
	if state == new_state:
		return

	state = new_state

	match state:
		State.IDLE:
			idle_timer = idle_duration
			velocity.x = 0.0
		State.PATROL:
			pass
		State.CHASE:
			pass
		State.ATTACK:
			velocity.x = 0.0
		State.RETURN:
			pass


# DISPAROS: usa el área amplia ShootRange. AttackArea queda para el ataque cercano.
func can_shoot_player() -> bool:
	if is_dead or not is_instance_valid(player):
		return false

	if not is_player_alive():
		return false

	return shoot_range.overlaps_body(player)


func update_shooting() -> void:
	if not can_shoot_player():
		if not shoot_timer.is_stopped():
			shoot_timer.stop()
		return

	if shoot_timer.is_stopped():
		_shoot_projectile()
		shoot_timer.start()


func _on_shoot_timer_timeout() -> void:
	if not can_shoot_player():
		return

	_shoot_projectile()

	if can_shoot_player():
		shoot_timer.start()


func _shoot_projectile() -> void:
	if not is_instance_valid(player):
		return

	if projectile_scene == null:
		push_warning(
			"Enemy2: asigna plant_projectile.tscn en Projectile Scene."
		)
		return

	var projectile = projectile_scene.instantiate()

	var direction: Vector2 = (
		player.global_position - muzzle.global_position
	).normalized()

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = muzzle.global_position + direction * 55.0

	if projectile.has_method("launch"):
		projectile.launch(direction, self, projectile_damage)
	else:
		push_warning(
			"El proyectil no tiene la función launch(). Revisa su script."
		)
		projectile.queue_free()


# ANIMACIONES Y ORIENTACIÓN

func update_animation() -> void:
	if sprite.sprite_frames == null:
		return

	if sprite.animation == "hurt" and sprite.is_playing():
		return

	if sprite.animation == "attack" and sprite.is_playing():
		return

	if absf(velocity.x) > 5.0:
		update_facing_direction(Vector2(velocity.x, 0.0))

		if sprite.animation != "walk" or not sprite.is_playing():
			sprite.play("walk")
	else:
		if sprite.animation != "idle" or not sprite.is_playing():
			sprite.play("idle")


func update_facing_direction(direction: Vector2) -> void:
	if absf(direction.x) < 0.001:
		return

	if direction.x > 0.0:
		facing_direction = "right"
		sprite.flip_h = false
	else:
		facing_direction = "left"
		sprite.flip_h = true

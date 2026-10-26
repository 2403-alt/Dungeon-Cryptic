
extends CharacterBody2D

@export var health: int = 50
@export var projectile_scene: PackedScene
@export var fire_rate: float = 0.5
@export var projectile_damage: int = 10

@onready var detection_area: Area2D = $DetectionArea
@onready var cannon: Node2D = $Cannon
@onready var muzzle: Marker2D = $Cannon/Muzzle
@onready var fire_timer: Timer = $Timer

var player: Node2D = null
var defeated: bool = false


func _ready() -> void:
	add_to_group("enemies")

	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

	fire_timer.timeout.connect(_on_fire_timer_timeout)
	fire_timer.wait_time = fire_rate
	fire_timer.one_shot = false


func _physics_process(_delta: float) -> void:
	if defeated:
		return

	if not is_instance_valid(player):
		return

	# No apuntar si el jugador está por encima.
	if player.global_position.y <= global_position.y:
		return

	# Calcular la dirección hacia el jugador.
	var direction: Vector2 = (
		player.global_position - muzzle.global_position
	).normalized()

	# Girar únicamente el cañón.
	cannon.global_rotation = direction.angle() - PI / 2


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	# Detectar únicamente al jugador que está debajo.
	if body.global_position.y <= global_position.y:
		return

	player = body
	fire_timer.start()


func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		fire_timer.stop()


func _on_fire_timer_timeout() -> void:
	if defeated or not is_instance_valid(player):
		return

	# No disparar hacia arriba.
	if player.global_position.y <= global_position.y:
		return

	if projectile_scene == null:
		push_warning("Asigna la escena del proyectil en el Inspector.")
		return

	# Calcular la dirección del disparo.
	var direction: Vector2 = (
		player.global_position - muzzle.global_position
	).normalized()

	# Crear el proyectil.
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = muzzle.global_position

	# Configurar y lanzar el proyectil.
	if projectile.has_method("launch"):
		projectile.launch(direction, self, projectile_damage)


func take_damage(amount: int) -> void:
	if defeated:
		return

	health -= amount

	if health <= 0:
		defeated = true
		fire_timer.stop()
		queue_free()

extends Area2D

@export var speed: float = 600.0
@export var gravity_force: float = 300.0
@export var damage: int = 20
@export var lifetime: float = 4.0
@export var impact_scene: PackedScene
@onready var impact_sound: AudioStreamPlayer2D = $ImpactSound

var direction: float = 1.0
var vertical_speed: float = -150.0
var shooter: Node2D
var has_hit: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	await get_tree().create_timer(lifetime).timeout

	if is_inside_tree():
		queue_free()


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	position.x += speed * direction * delta

	vertical_speed += gravity_force * delta
	position.y += vertical_speed * delta

	rotation += direction * 8.0 * delta


func launch(start_direction: float, owner_node: Node2D) -> void:
	direction = sign(start_direction)

	if direction == 0:
		direction = 1.0

	shooter = owner_node


func _on_body_entered(body: Node2D) -> void:
	if has_hit or body == shooter:
		return

	has_hit = true

	# Crear partículas en el impacto
	spawn_impact()

	# Reproducir sonido de impacto
	if impact_sound.stream != null:
		impact_sound.play()

	# Aplicar daño si golpeó a un enemigo
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)

	# Esperar a que termine el sonido antes de borrar la piedra
	if impact_sound.stream != null:
		await impact_sound.finished

	if is_inside_tree():
		queue_free()
		
func spawn_impact() -> void:
	if impact_scene == null:
		return
	var effect = impact_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position

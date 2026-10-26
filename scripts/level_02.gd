
extends Node2D

@export var time_limit_seconds: float = 180.0
@export var required_search_items: int = 13
@export var max_health: int = 50
@export var health: int = 50

var score: int = 0
var collected_orb_ids: Array[String] = []
var killed_enemy_ids: Array[String] = []
var time_remaining: float = 180.0
var timer_running: bool = false
var search_completed: bool = false
var time_expired: bool = false

signal winner
signal orbe_collected
signal score_changed(new_score: int)
signal search_finished
signal time_limit_reached

@onready var orbs_container: Node2D = $Orbes

var timer_label: Label


func _ready() -> void:
	time_remaining = time_limit_seconds
	timer_label = get_tree().current_scene.get_node_or_null("UI/TimerLabel")

	for coin in orbs_container.get_children():
		if coin.has_signal("collected"):
			coin.collected.connect(_on_orbe_collected.bind(coin))

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_ancestor_of(enemy):
			continue
		if enemy.has_signal("killed"):
			enemy.killed.connect(_on_enemy_killed.bind(enemy))

	_update_orb_visibility()
	_update_timer_label()


func _process(delta: float) -> void:
	if not timer_running or search_completed or time_expired:
		return

	time_remaining = maxf(0.0, time_remaining - delta)
	_update_timer_label()

	if time_remaining <= 0.0:
		timer_running = false
		time_expired = true
		_update_orb_visibility()
		time_limit_reached.emit()

		var npc = get_node_or_null("NPC2")
		if npc != null and npc.has_method("show_timeout_dialogue"):
			npc.show_timeout_dialogue()


func start_search() -> void:
	if search_completed or time_expired:
		return

	if time_remaining <= 0.0:
		time_remaining = time_limit_seconds

	timer_running = true
	_update_orb_visibility()
	_update_timer_label()


func _update_timer_label() -> void:
	if not is_instance_valid(timer_label):
		timer_label = get_tree().current_scene.get_node_or_null("UI/TimerLabel")

	if not is_instance_valid(timer_label):
		return

	if search_completed:
		timer_label.text = "Search completed!"
	elif time_expired:
		timer_label.text = "Time is up!"
	else:
		var seconds := int(ceil(time_remaining))
		var minutes := int(seconds / 60)
		var remaining_seconds := seconds % 60
		timer_label.text = "Time: %02d:%02d" % [minutes, remaining_seconds]


func _update_orb_visibility() -> void:
	for coin in orbs_container.get_children():
		var already_collected := collected_orb_ids.has(str(coin.name))
		var can_collect := not already_collected and not search_completed and not time_expired

		coin.visible = can_collect

		if coin is Area2D:
			coin.set_deferred("monitoring", can_collect)


func _on_orbe_collected(coin: Node2D) -> void:
	var orb_id: String = str(coin.name)

	if collected_orb_ids.has(orb_id) or search_completed or time_expired:
		return

	collected_orb_ids.append(orb_id)
	_play_collection_sound()
	score_add(10)
	orbe_collected.emit()

	if collected_orb_ids.size() >= required_search_items:
		_complete_search()


func _play_collection_sound() -> void:
	var player_node = get_tree().current_scene.get_node_or_null("player")

	if player_node != null and player_node.has_method("collect_orbe"):
		player_node.collect_orbe()


func _complete_search() -> void:
	if search_completed or time_expired:
		return

	search_completed = true
	timer_running = false
	_update_orb_visibility()
	_update_timer_label()
	search_finished.emit()
	winner.emit()


func score_add(points: int) -> void:
	score += points
	score_changed.emit(score)


func _on_enemy_killed(enemy: Node2D) -> void:
	if not is_ancestor_of(enemy):
		return

	var enemy_id: String = str(enemy.name)

	if not killed_enemy_ids.has(enemy_id):
		killed_enemy_ids.append(enemy_id)
		score_add(20)


# Comprueba si un objeto tiene una propiedad.
func _has_property(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if property_info["name"] == property_name:
			return true

	return false


# GUARDAR
func get_save_data() -> Dictionary:
	var enemy_data: Dictionary = {}

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not is_ancestor_of(enemy):
			continue

		var saved_enemy: Dictionary = {
			"position_x": enemy.global_position.x,
			"position_y": enemy.global_position.y
		}

		if _has_property(enemy, "health"):
			saved_enemy["health"] = int(enemy.get("health"))

		enemy_data[str(enemy.name)] = saved_enemy

	return {
		"score": score,
		"collected_orb_ids": collected_orb_ids.duplicate(),
		"killed_enemy_ids": killed_enemy_ids.duplicate(),
		"enemy_data": enemy_data,
		"time_remaining": time_remaining,
		"timer_running": timer_running,
		"search_completed": search_completed,
		"time_expired": time_expired
	}


# CARGAR
func apply_save_data(data: Dictionary) -> void:
	score = int(data.get("score", 0))

	collected_orb_ids.clear()
	killed_enemy_ids.clear()

	for orb_id in data.get("collected_orb_ids", []):
		collected_orb_ids.append(str(orb_id))

	for enemy_id in data.get("killed_enemy_ids", []):
		killed_enemy_ids.append(str(enemy_id))

	var saved_enemies: Dictionary = data.get("enemy_data", {})

	time_remaining = clampf(
		float(data.get("time_remaining", time_limit_seconds)),
		0.0,
		time_limit_seconds
	)

	search_completed = bool(data.get("search_completed", false))
	time_expired = bool(data.get("time_expired", false))

	timer_running = (
		bool(data.get("timer_running", false))
		and not search_completed
		and not time_expired
	)

	for coin in orbs_container.get_children():
		if collected_orb_ids.has(str(coin.name)):
			coin.queue_free()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not is_ancestor_of(enemy):
			continue

		var enemy_id: String = str(enemy.name)

		if killed_enemy_ids.has(enemy_id):
			enemy.queue_free()
			continue

		if not saved_enemies.has(enemy_id):
			continue

		var saved: Dictionary = saved_enemies[enemy_id]

		enemy.global_position = Vector2(
			float(saved.get("position_x", enemy.global_position.x)),
			float(saved.get("position_y", enemy.global_position.y))
		)

		# Restaurar vida solo si el enemigo tiene esa propiedad.
		if saved.has("health") and _has_property(enemy, "health"):
			var saved_health: int = int(saved["health"])
			var current_max_health: int = saved_health

			if _has_property(enemy, "max_health"):
				current_max_health = int(enemy.get("max_health"))

			current_max_health = maxi(current_max_health, 1)

			enemy.set(
				"health",
				clampi(saved_health, 1, current_max_health)
			)

			# La barra de vida es opcional.
			if _has_property(enemy, "healthbar"):
				var bar = enemy.get("healthbar")

				if is_instance_valid(bar):
					bar.value = int(enemy.get("health"))

	score_changed.emit(score)
	_update_orb_visibility()
	_update_timer_label()


func _on_quest_completed() -> void:
	winner.emit()


func get_search_progress() -> Dictionary:
	return {
		"collected": collected_orb_ids.size(),
		"required": required_search_items,
		"time_remaining": time_remaining,
		"timer_running": timer_running,
		"completed": search_completed,
		"time_expired": time_expired
	}

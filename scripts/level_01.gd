
extends Node2D

var score: int = 0
var collected_orb_ids: Array[String] = []
var killed_enemy_ids: Array[String] = []

signal winner
signal orbe_collected
signal score_changed(new_score: int)


func _ready() -> void:
	QuestManager.quest_updated.connect(_on_quest_updated)

	for coin in $orbes.get_children():
		if coin.has_signal("collected"):
			coin.collected.connect(_on_orbe_collected.bind(coin))

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_ancestor_of(enemy):
			continue
		if enemy.has_signal("killed"):
			enemy.killed.connect(_on_enemy_killed.bind(enemy))

	_update_orb_visibility()


func _on_quest_updated() -> void:
	_update_orb_visibility()


func _update_orb_visibility() -> void:
	var mission_active = QuestManager.quest_state == QuestManager.QuestState.ACTIVE

	for coin in $orbes.get_children():
		coin.visible = mission_active
		coin.set_deferred("monitoring", mission_active)


func _on_orbe_collected(coin: Node2D) -> void:
	if not QuestManager.collect_crystal():
		return

	_play_collection_sound()

	var orb_id: String = str(coin.name)
	if not collected_orb_ids.has(orb_id):
		collected_orb_ids.append(orb_id)

	score_add(10)
	orbe_collected.emit()


func _play_collection_sound() -> void:
	var player = get_tree().current_scene.get_node_or_null("player")
	if player != null and player.has_method("collect_orbe"):
		player.collect_orbe()


func score_add(points: int) -> void:
	score += points
	score_changed.emit(score)
	print("Point: ", score)


func _on_enemy_killed(enemy: Node2D) -> void:
	var enemy_id: String = str(enemy.name)
	if not killed_enemy_ids.has(enemy_id):
		killed_enemy_ids.append(enemy_id)
		score_add(20)


func get_save_data() -> Dictionary:
	var enemy_data: Dictionary = {}

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not is_ancestor_of(enemy):
			continue

		enemy_data[str(enemy.name)] = {
			"health": enemy.health,
			"position_x": enemy.global_position.x,
			"position_y": enemy.global_position.y
		}

	return {
		"score": score,
		"collected_orb_ids": collected_orb_ids.duplicate(),
		"killed_enemy_ids": killed_enemy_ids.duplicate(),
		"enemy_data": enemy_data
	}


func apply_save_data(data: Dictionary) -> void:
	score = int(data.get("score", 0))
	collected_orb_ids.clear()
	killed_enemy_ids.clear()

	for orb_id in data.get("collected_orb_ids", []):
		collected_orb_ids.append(str(orb_id))

	for enemy_id in data.get("killed_enemy_ids", []):
		killed_enemy_ids.append(str(enemy_id))

	var saved_enemies: Dictionary = data.get("enemy_data", {})

	for coin in $orbes.get_children():
		if collected_orb_ids.has(str(coin.name)):
			coin.queue_free()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_ancestor_of(enemy):
			continue
		var enemy_id: String = str(enemy.name)

		if killed_enemy_ids.has(enemy_id):
			enemy.queue_free()
			continue

		if saved_enemies.has(enemy_id):
			var saved: Dictionary = saved_enemies[enemy_id]
			enemy.global_position = Vector2(
				float(saved.get("position_x", enemy.global_position.x)),
				float(saved.get("position_y", enemy.global_position.y))
			)
			enemy.health = clampi(
				int(saved.get("health", enemy.max_health)),
				1,
				enemy.max_health
			)
			enemy.healthbar.value = enemy.health

	score_changed.emit(score)
	_update_orb_visibility()


func _on_quest_completed() -> void:
	winner.emit()

extends Node

const SAVE_DIR: String = "user://saves/"
const LEGACY_SAVE_PATH: String = "user://savegame.json"
var pending_data: Dictionary = {}

func get_save_path(slot_id: int) -> String:
	return SAVE_DIR + "partida_%03d.json" % slot_id

func get_saved_games() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.begins_with("partida_") and filename.ends_with(".json"):
			var slot_text := filename.trim_prefix("partida_").trim_suffix(".json")
			if slot_text.is_valid_int():
				var data := read_save(int(slot_text))
				if not data.is_empty():
					data["slot_id"] = int(slot_text)
					saves.append(data)
		filename = dir.get_next()
	dir.list_dir_end()
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["slot_id"]) < int(b["slot_id"]))
	return saves

func get_next_slot_id() -> int:
	var highest := 0
	for data in get_saved_games():
		highest = maxi(highest, int(data["slot_id"]))
	return highest + 1

func read_save(slot_id: int) -> Dictionary:
	var path := get_save_path(slot_id)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

func save_game(player: CharacterBody2D, level_path: String, slot_id: int = 0) -> bool:
	if player == null or get_tree().current_scene == null:
		return false

	var current_scene := get_tree().current_scene
	var level: Node = null
	if current_scene.has_method("get_active_level"):
		level = current_scene.get_active_level()
	if level == null:
		level = current_scene.get_node_or_null("Level01")
	if level == null or not level.has_method("get_save_data"):
		push_error("No se encontró el nivel activo para guardar")
		return false

	if slot_id <= 0:
		slot_id = get_next_slot_id()
	var data: Dictionary = {
		"version": 3,
		"slot_id": slot_id,
		"saved_at": Time.get_datetime_string_from_system(),
		"level_path": level_path,
		"active_level_name": str(level.name),
		"health": player.health,
		"position_x": player.global_position.x,
		"position_y": player.global_position.y,
		"quest_state": int(QuestManager.quest_state),
		"collected_crystals": QuestManager.collected_crystals,
		"level_data": level.get_save_data()
	}
	if DirAccess.make_dir_recursive_absolute(SAVE_DIR) != OK:
		push_error("No se pudo crear el directorio de partidas")
		return false
	var file := FileAccess.open(get_save_path(slot_id), FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar la partida")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func load_game(slot_id: int = 0) -> bool:
	var data: Dictionary = {}
	if slot_id > 0:
		data = read_save(slot_id)
	else:
		var saves := get_saved_games()
		if not saves.is_empty():
			data = saves.back()
		elif FileAccess.file_exists(LEGACY_SAVE_PATH):
			var file := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
			if file != null:
				var parsed: Variant = JSON.parse_string(file.get_as_text())
				if parsed is Dictionary:
					data = parsed
	if data.is_empty():
		push_warning("No existe esa partida guardada")
		return false
	var scene_path := str(data.get("level_path", ""))
	if not ResourceLoader.exists(scene_path):
		push_error("No existe la escena guardada: " + scene_path)
		return false
	pending_data = data
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(scene_path)
	return true

func apply_save_data(player: CharacterBody2D) -> void:
	if pending_data.is_empty():
		return

	var current_scene := get_tree().current_scene
	QuestManager.collected_crystals = int(pending_data.get("collected_crystals", 0))
	QuestManager.quest_state = int(pending_data.get("quest_state", 0)) as QuestManager.QuestState
	QuestManager.quest_updated.emit()

	var active_level_name := str(pending_data.get("active_level_name", "Level01"))
	if current_scene.has_method("set_active_level_by_name"):
		current_scene.set_active_level_by_name(active_level_name, false)

	player.health = clampi(int(pending_data.get("health", player.health_max)), 0, player.health_max)
	player.global_position = Vector2(
		float(pending_data.get("position_x", player.global_position.x)),
		float(pending_data.get("position_y", player.global_position.y))
	)
	player.health_changed.emit(player.health, player.health_max)

	var level: Node = current_scene.get_node_or_null(active_level_name)
	if level == null:
		level = current_scene.get_node_or_null("Level01")
	if level != null and level.has_method("apply_save_data"):
		var level_data: Dictionary = pending_data.get("level_data", {})
		level.apply_save_data(level_data)

	pending_data.clear()

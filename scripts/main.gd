extends Node2D

@export var level_2_spawn_position: Vector2 = Vector2(231, 579)

var game_over: bool = false
var active_level

@onready var player: CharacterBody2D = $player
@onready var level = $Level01
@onready var level_2 = $Level02
@onready var score_label: Label = $UI/ScoreLabel
@onready var win_label: Label = $UI/WinLabel
@onready var dead_label: Label = $UI/DeadLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var mission_label: Label = $UI/MissionLabel
@onready var health_bar: TextureProgressBar = $HealthBar/ProgressBar
@onready var background_sound: AudioStreamPlayer = $backgroundSound
@onready var pause_menu = $PauseMenu
@onready var restart_button: Button = $UI/RestartButton



func _ready() -> void:
	var restart_level_name := "Level01"

	if get_tree().has_meta("restart_level_name"):
		restart_level_name = str(
			get_tree().get_meta("restart_level_name")
		)
		get_tree().remove_meta("restart_level_name")

	active_level = level

	_set_level_active(level, restart_level_name != "Level02")
	_set_level_active(level_2, restart_level_name == "Level02")

	if restart_level_name == "Level02":
		active_level = level_2
		player.global_position = level_2_spawn_position

	restart_button.hide()
	restart_button.pressed.connect(_on_restart_button_pressed)

	score_label.text = "Point: %d" % level.score
	win_label.visible = false
	dead_label.visible = false
	timer_label.hide()

	if not QuestManager.quest_updated.is_connected(_update_mission_label):
		QuestManager.quest_updated.connect(_update_mission_label)

	_update_mission_label()

	health_bar.min_value = 0
	health_bar.max_value = player.health_max
	health_bar.value = player.health

	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	level.score_changed.connect(_on_score_changed)
	level.winner.connect(_on_level_winner)
	level_2.score_changed.connect(_on_score_changed)
	level_2.time_limit_reached.connect(_on_level_2_time_expired)
	level_2.search_finished.connect(_on_level_2_search_finished)
	
	SaveManager.apply_save_data.call_deferred(player)
	
	if restart_level_name == "Level02":
		level_2.time_remaining = level_2.time_limit_seconds
		level_2.timer_running = false
		level_2.search_completed = false
		level_2.time_expired = false

		timer_label.show()
		level_2.start_search()

func _set_level_active(level_node: Node2D, active: bool) -> void:
	level_node.visible = active
	level_node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_set_collision_state_recursive(level_node, active)


func _set_collision_state_recursive(node: Node, active: bool) -> void:
	if node is CollisionObject2D:
		if not node.has_meta("original_collision_layer"):
			node.set_meta("original_collision_layer", node.collision_layer)
		if not node.has_meta("original_collision_mask"):
			node.set_meta("original_collision_mask", node.collision_mask)

		if active:
			node.set_deferred("collision_layer", int(node.get_meta("original_collision_layer")))
			node.set_deferred("collision_mask", int(node.get_meta("original_collision_mask")))
		else:
			node.set_deferred("collision_layer", 0)
			node.set_deferred("collision_mask", 0)

	for child in node.get_children():
		_set_collision_state_recursive(child, active)


func go_to_level_2() -> void:
	if active_level == level_2 or game_over:
		return
	if QuestManager.quest_state != QuestManager.QuestState.COMPLETED:
		return

	_set_level_active(level, false)
	_set_level_active(level_2, true)
	active_level = level_2
	player.global_position = level_2_spawn_position

	win_label.hide()
	dead_label.hide()
	score_label.text = "Point: %d" % level_2.score
	timer_label.hide()
	_update_mission_label()


func start_level_2_search() -> void:
	if active_level != level_2 or game_over:
		return
	if level_2.search_completed or level_2.time_expired:
		return

	timer_label.show()
	level_2.start_search()
	_update_mission_label()


func set_active_level_by_name(level_name: String, start_timer: bool = false) -> void:
	if level_name == "Level02":
		_set_level_active(level, false)
		_set_level_active(level_2, true)
		active_level = level_2
		if start_timer:
			timer_label.show()
			level_2.start_search()
		else:
			timer_label.hide()
			level_2._update_timer_label()
		_update_mission_label()
	else:
		_set_level_active(level_2, false)
		_set_level_active(level, true)
		active_level = level
		timer_label.hide()
		score_label.text = "Point: %d" % level.score
		_update_mission_label()


func get_active_level() -> Node2D:
	return active_level if is_instance_valid(active_level) else level


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Point: %d" % new_score
	_update_mission_label()


func _update_mission_label() -> void:
	if not is_instance_valid(mission_label):
		return

	if active_level == level_2:
		if level_2.search_completed:
			mission_label.text = "MISSION: Search completed!"
		elif level_2.time_expired:
			mission_label.text = "MISSION: Time is up - restart the level"
		elif level_2.timer_running:
			mission_label.text = "MISSION: Find all the orbs (%d/%d)" % [
				level_2.collected_orb_ids.size(),
				level_2.required_search_items
			]
		else:
			mission_label.text = "MISSION: Talk to the Dungeon Keeper"
		return

	match QuestManager.quest_state:
		QuestManager.QuestState.NOT_STARTED:
			mission_label.text = "MISSION: Talk to Mr. Snow"
		QuestManager.QuestState.ACTIVE:
			mission_label.text = "MISSION: Collect the crystals (%d/%d)" % [
				QuestManager.collected_crystals,
				QuestManager.required_crystals
			]
		QuestManager.QuestState.READY_TO_DELIVER:
			mission_label.text = "MISSION: Return to Mr. Snow"
		QuestManager.QuestState.COMPLETED:
			mission_label.text = "MISSION: Enter the sealed portal"


func _on_player_health_changed(health_current: int, health_max: int) -> void:
	health_bar.max_value = health_max
	health_bar.value = health_current


func _on_orbe_collected() -> void:
	score_label.text = "Puntos: %d" % get_active_level().score


func _on_level_2_search_finished() -> void:
	timer_label.text = "Search completed!"
	_update_mission_label()


func _on_level_2_time_expired() -> void:
	if game_over:
		return

	game_over = true
	dead_label.text = "TIME'S UP!"
	dead_label.show()
	restart_button.show()

	player.set_physics_process(false)
	_update_mission_label()


func _on_level_winner() -> void:
	if game_over:
		return
	win_label.text = "YOU WIN!"
	win_label.visible = true
	game_over = true
	player.set_physics_process(false)
	_update_mission_label()


func _on_player_died() -> void:
	if game_over:
		return

	game_over = true
	dead_label.text = "GAME OVER"
	dead_label.show()
	restart_button.show()
	print("GAME OVER")

func _on_save_buttom_pressed() -> void:
	pause_menu.pause_game()
	pause_menu.save_game()


func _on_load_button_pressed() -> void:
	pause_menu.pause_game()
	pause_menu.load_game()
	
func _on_restart_button_pressed() -> void:
	var level_name := "Level01"
	if is_instance_valid(active_level):
		level_name = str(active_level.name)

	SaveManager.pending_data.clear()
	get_tree().set_meta("restart_level_name", level_name)
	get_tree().reload_current_scene()

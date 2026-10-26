
extends CanvasLayer

@onready var background: ColorRect = $Background
@onready var resume_button: TextureButton = \
$Background/CenterContainer/PausePanel/VBoxContainer/ResumeButton
@onready var save_button: TextureButton = \
$Background/CenterContainer/PausePanel/VBoxContainer/SaveButton
@onready var load_button: TextureButton = \
$Background/CenterContainer/PausePanel/VBoxContainer/LoadButton
@onready var restart_button: TextureButton = \
$Background/CenterContainer/PausePanel/VBoxContainer/RestartButton
@onready var exit_button: TextureButton = \
$Background/CenterContainer/PausePanel/VBoxContainer/ExitButton
@onready var save_slots = $SaveSlots

var is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	is_paused = false
	background.hide()
	save_slots.hide()
	
	resume_button.pressed.connect(resume_game)
	save_button.pressed.connect(save_game)
	load_button.pressed.connect(load_game)
	restart_button.pressed.connect(restart_level)
	exit_button.pressed.connect(exit_game)

	save_slots.closed.connect(_on_save_slots_closed)


#func _unhandled_input(event: InputEvent) -> void:
	#if event.is_action_pressed("pause"):
		#if event is InputEventKey and event.echo:
			#return
#
		#toggle_pause()
		#get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel")):
		return

	if event is InputEventKey and event.echo:
		return

	get_viewport().set_input_as_handled()

	if save_slots.visible:
		save_slots.close_menu()
		return

	toggle_pause()

func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	is_paused = true
	background.show()
	get_tree().paused = true


func resume_game() -> void:
	get_tree().paused = false

	is_paused = false
	background.hide()
	save_slots.hide()


#func save_game() -> void:
	#var player = get_tree().get_first_node_in_group("player")
#
	#if player == null:
		#push_warning("No se encontró al jugador")
		#return
#
	#var current_level: String = \
		#get_tree().current_scene.scene_file_path
#
	#if SaveManager.save_game(player, current_level):
		#print("Partida guardada correctamente")
	#else:
		#push_warning("No se pudo guardar la partida")
func save_game() -> void:
	save_slots.open_menu(
		save_slots.Mode.SAVE
	)


#func load_game() -> void:
	#if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		#print("No existe una partida guardada")
		#return
#
	#resume_game()
	#SaveManager.load_game()

func load_game() -> void:
	save_slots.open_menu(
		SaveSlots.Mode.LOAD
	)

func restart_level() -> void:
	resume_game()

	get_tree().reload_current_scene.call_deferred()


func exit_game() -> void:
	get_tree().paused = false
	get_tree().quit()

func _on_save_slots_closed() -> void:
	pass

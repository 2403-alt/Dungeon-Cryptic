
class_name SaveSlots
extends Control

signal closed

enum Mode {
	SAVE,
	LOAD
}

var mode: Mode = Mode.LOAD
var selected_slot_id: int = 0

@onready var title_label: Label = \
	$Overlay/CenterContainer/PanelContainer/VBoxContainer/TitleLabel

@onready var save_list: ItemList = \
	$Overlay/CenterContainer/PanelContainer/VBoxContainer/SaveList

@onready var new_save_button: Button = \
	$Overlay/CenterContainer/PanelContainer/VBoxContainer/NewSaveButton

@onready var confirm_button: Button = \
	$Overlay/CenterContainer/PanelContainer/VBoxContainer/ConfirmButton

@onready var cancel_button: Button = \
	$Overlay/CenterContainer/PanelContainer/VBoxContainer/CancelButton

var displayed_saves: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	hide()

	save_list.item_selected.connect(
		_on_item_selected
	)

	new_save_button.pressed.connect(
		_on_new_save_pressed
	)

	confirm_button.pressed.connect(
		_on_confirm_pressed
	)

	cancel_button.pressed.connect(close_menu)


func open_menu(selected_mode: Mode) -> void:
	mode = selected_mode
	selected_slot_id = 0

	title_label.text = (
		"SAVE GAME"
		if mode == Mode.SAVE
		else "LOAD GAME"
	)

	new_save_button.text = "CREATE NEW SAVE"
	new_save_button.visible = mode == Mode.SAVE

	confirm_button.text = (
		"OVERWRITE SAVE"
		if mode == Mode.SAVE
		else "LOAD GAME"
	)

	refresh_saves()
	show()


func refresh_saves() -> void:
	save_list.clear()
	selected_slot_id = 0

	title_label.text = (
		"SAVE GAME"
		if mode == Mode.SAVE
		else "LOAD GAME"
	)

	displayed_saves = SaveManager.get_saved_games()

	for data in displayed_saves:
		var slot_id: int = int(data["slot_id"])
		var level_path: String = str(
			data.get("level_path", "")
		)

		var level_name := level_path.get_file().get_basename()

		var health := int(data.get("health", 0))
		var date := str(data.get("saved_at", ""))

		var description := (
			"Save %03d | %s | Health: %d | %s"
			% [slot_id, level_name, health, date]
		)

		save_list.add_item(description)

	confirm_button.disabled = true

	if displayed_saves.is_empty():
		title_label.text = (
			"SAVE GAME (NO SAVES)"
			if mode == Mode.SAVE
			else "LOAD GAME (NO SAVES)"
		)


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= displayed_saves.size():
		return

	selected_slot_id = int(
		displayed_saves[index]["slot_id"]
	)

	confirm_button.disabled = false


func _on_new_save_pressed() -> void:
	if mode != Mode.SAVE:
		return

	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	var level_path: String = \
		get_tree().current_scene.scene_file_path

	if SaveManager.save_game(player, level_path, 0):
		refresh_saves()
		print("New save created")


func _on_confirm_pressed() -> void:
	if selected_slot_id <= 0:
		return

	if mode == Mode.LOAD:
		if SaveManager.load_game(selected_slot_id):
			close_menu()

	elif mode == Mode.SAVE:
		var player = get_tree().get_first_node_in_group("player")

		if player == null:
			return

		var level_path: String = \
			get_tree().current_scene.scene_file_path

		if SaveManager.save_game(
			player,
			level_path,
			selected_slot_id
		):
			refresh_saves()
			print("Save overwritten")


func close_menu() -> void:
	hide()
	closed.emit()

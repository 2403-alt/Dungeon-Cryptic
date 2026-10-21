extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var name_label: Label = $PanelContainer/VBoxContainer/NameLabel
@onready var dialogue_label: Label = $PanelContainer/VBoxContainer/DialogueLabel
@onready var continue_button: Button = $PanelContainer/VBoxContainer/ContinueButton

var current_dialogues: Array[String] = []
var dialogue_index: int = 0
var is_open: bool = false

func _ready() -> void:
	hide()
	continue_button.hide()
	continue_button.pressed.connect(next_dialogue)

func show_dialogue(character_name: String, dialogues: Array) -> void:
	if dialogues.is_empty():
		return
	current_dialogues.clear()
	for line in dialogues:
		current_dialogues.append(str(line))
	dialogue_index = 0
	is_open = true
	name_label.text = character_name
	dialogue_label.text = current_dialogues[0]

	show()
	continue_button.show()

func next_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index >= current_dialogues.size():
		close_dialogue()
		return
	dialogue_label.text = current_dialogues[dialogue_index]

func close_dialogue() -> void:
	hide()
	continue_button.hide()
	is_open = false

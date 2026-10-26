
extends Area2D

var activated: bool = false
var transitioning: bool = false
var door_dialogue_active: bool = false
var player_inside: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if QuestManager.quest_state == QuestManager.QuestState.COMPLETED:
		activate_portal()

	if not QuestManager.quest_completed.is_connected(activate_portal):
		QuestManager.quest_completed.connect(activate_portal)

	# Detectar cuando el jugador sale del área
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func activate_portal() -> void:
	activated = true


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or transitioning:
		return

	player_inside = true

	if not activated:
		var dialogue_ui = get_tree().current_scene.get_node_or_null("dialogue_ui")

		if dialogue_ui != null and not dialogue_ui.is_open:
			door_dialogue_active = true

			dialogue_ui.show_dialogue(
				"Sealed Door",
				[
					"This door is sealed by an ancient magic.",
					"Complete Mr. Snow's quest and return here."
				]
			)
		return

	var main_scene = get_tree().current_scene

	if main_scene != null and main_scene.has_method("go_to_level_2"):
		transitioning = true
		set_deferred("monitoring", false)
		main_scene.call_deferred("go_to_level_2")
	else:
		push_warning("The door must be inside the main scene, Main.")


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_inside = false

	if not door_dialogue_active:
		return

	var dialogue_ui = get_tree().current_scene.get_node_or_null("dialogue_ui")

	if dialogue_ui != null and dialogue_ui.is_open:
		if dialogue_ui.name_label.text == "Sealed Door":
			dialogue_ui.close_dialogue()

	door_dialogue_active = false

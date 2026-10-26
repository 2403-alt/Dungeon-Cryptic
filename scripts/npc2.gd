
extends Node2D

@onready var interactive_area: Area2D = $InteractiveArea
@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

var player_nearby: bool = false
var briefing_shown: bool = false


func _ready() -> void:
	animation.play("idle")
	interactive_area.body_entered.connect(_on_body_entered)
	interactive_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not player_nearby or not Input.is_action_just_pressed("interact"):
		return

	var dialogue_ui = _get_dialogue_ui()
	if dialogue_ui == null:
		return

	if dialogue_ui.is_open:
		dialogue_ui.next_dialogue()
	else:
		interact()


func interact() -> void:
	var dialogue_ui = _get_dialogue_ui()
	if dialogue_ui == null or dialogue_ui.is_open:
		return

	var level = get_parent()
	if level == null or not level.has_method("get_search_progress"):
		push_warning("NPC2: el padre no tiene get_search_progress(). Comprueba que NPC2 sea hijo directo de Level02.")
		return

	var progress: Dictionary = level.get_search_progress()

	var remaining: int = maxi(
		0,
		int(progress.get("required", 0)) -
		int(progress.get("collected", 0))
	)

	var seconds: int = int(ceil(float(progress.get("time_remaining", 0.0))))
	var minutes: int = int(seconds / 60)
	var remaining_seconds: int = seconds % 60

	if bool(progress.get("completed", false)):
		dialogue_ui.show_dialogue(
			"Dungeon Keeper",
			[
				"You did it! You found all the orbs.",
				"You completed the search before time ran out.",
				"Thanks for helping me. You can rest; you’ve earned it."
			]
		)

	elif bool(progress.get("time_expired", false)):
		show_timeout_dialogue()

	elif not briefing_shown:
		briefing_shown = true

		dialogue_ui.show_dialogue(
			"Dungeon Keeper",
			[
				"I need you to find all the orbs hidden in this part of the dungeon.",
				"You must complete the search before time runs out.",
				"You are still missing %d orbs." % remaining,
				"You have %02d:%02d left. Hurry!" % [
					minutes,
					remaining_seconds
				]
			],
			true
		)

	else:
		dialogue_ui.show_dialogue(
			"Dungeon Keeper",
			[
				"You still need to find the remaining orbs!"
			]
		)


func show_timeout_dialogue() -> void:
	var dialogue_ui = _get_dialogue_ui()
	if dialogue_ui == null:
		return

	dialogue_ui.show_dialogue(
		"Dungeon Keeper",
		[
			"Time’s up!",
			"You failed to complete the search before the clock reached zero.",
			"You can restart the level from the pause menu and try again."
		]
	)


func _get_dialogue_ui():
	var current_scene = get_tree().current_scene
	if current_scene != null:
		var dialogue = current_scene.get_node_or_null("dialogue_ui")
		if dialogue != null:
			return dialogue
	return get_tree().root.find_child("dialogue_ui", true, false)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_nearby = true


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_nearby = false

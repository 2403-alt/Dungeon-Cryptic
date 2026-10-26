extends Node2D

@onready var interactive_area: Area2D = $InteractiveArea
@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

var player_nearby: bool = false

func _ready() -> void:
	animation.play("idle")
	interactive_area.body_entered.connect(
		_on_body_entered
	)
	interactive_area.body_exited.connect(
		_on_body_exited
	)

func _process(_delta: float) -> void:
	if player_nearby and Input.is_action_just_pressed("interact"):
		var dialogue_ui = get_tree().current_scene.get_node_or_null("dialogue_ui")
		if dialogue_ui == null:
			return
		if dialogue_ui.is_open:
			dialogue_ui.next_dialogue()
		else:
			interact()


func interact() -> void:
	var dialogue_ui = get_tree().current_scene.get_node_or_null("dialogue_ui")

	if dialogue_ui == null:
		return

	if dialogue_ui.is_open:
		return

	match QuestManager.quest_state:
		QuestManager.QuestState.NOT_STARTED:
			dialogue_ui.show_dialogue(
				"Mr. Snow",
				[
					"AAAAAH! DON'T KILL ME!!!",
					"Wait... you're not with them?",
					"Phew, what a relief! Those guys are dangerous.",
					"Can you help me recover some special orbs?",
					"The orbs are scattered throughout the dungeon.",
					"Bring them back to me, and I'll reward you.",
					"Please be careful around the guards!"
				]
			)
			QuestManager.start_quest()

		QuestManager.QuestState.ACTIVE:
			dialogue_ui.show_dialogue(
				"Mr. Snow",
				[
					"You're still missing some orbs!",
					"You have collected %d out of %d orbs." % [
						QuestManager.collected_crystals,
						QuestManager.required_crystals
					],
					"Keep exploring the dungeon!"
				]
			)

		QuestManager.QuestState.READY_TO_DELIVER:
			dialogue_ui.show_dialogue(
				"Mr. Snow",
				[
					"You found all the orbs!",
					"Thank you for recovering all of them.",
					"The mission is complete. Take this key.",
					"Now you can go to the next room through the door at the end."
				]
			)
			QuestManager.complete_quest()

		QuestManager.QuestState.COMPLETED:
			dialogue_ui.show_dialogue(
				"Mr. Snow",
				[
					"Thank you for your help!",
					"You can now enter through the door.",
					"Have a good trip!"
				]
			)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_nearby = false

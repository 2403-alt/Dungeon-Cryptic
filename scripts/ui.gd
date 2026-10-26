extends CanvasLayer

@onready var stones_label: Label = $StoneLabel

var player: CharacterBody2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_warning("No se encontró al jugador.")
		return

	player.stones_changed.connect(_update_stones_label)

	_update_stones_label(player.stones, player.max_stones)


func _update_stones_label(current: int, maximum: int) -> void:
	stones_label.text = "%d/%d" % [current, maximum]

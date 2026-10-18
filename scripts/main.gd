extends Node2D

var game_over: bool = false

@onready var player: CharacterBody2D = $player
@onready var level = $Level01
@onready var score_label: Label = $UI/ScoreLabel
@onready var win_label: Label = $UI/WinLabel
@onready var dead_label: Label = $UI/DeadLabel
@onready var health_bar: ProgressBar = $HealthBar/ProgressBar

func _ready() -> void:
	score_label.text = "Puntos: 0"
	win_label.visible = false
	dead_label.visible = false

	health_bar.min_value = 0
	health_bar.max_value = 3
	health_bar.value = 3

	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	level.orbe_collected.connect(_on_orbe_collected)
	level.winner.connect(_on_level_winner)

func _on_player_health_changed(health_current: int, health_max: int) -> void:
	health_bar.max_value = health_max
	health_bar.value = health_current

func _on_orbe_collected() -> void:
	score_label.text = "Puntos: %d" % level.score

func _on_level_winner() -> void:
	if game_over:
		return
	win_label.text = "¡GANASTE!"
	win_label.visible = true
	game_over = true
	#_stop_enemy() --------------------------------corregir
	player.set_physics_process(false)

func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	dead_label.text = "GAME OVER"
	dead_label.visible = true
	#_stop_enemy() --------------------------corregir
	print("GAME OVER")

#func _stop_enemy() -> void: -----------------------------------corregir
	#for enemy in level.get_node("enemys").get_children():
	#	enemy.set_physics_process(false)

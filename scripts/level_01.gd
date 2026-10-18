extends Node2D

var score: int = 0
signal winner
signal orbe_collected

func _ready() -> void:
	for coin in $orbes.get_children():
		if coin.has_signal("collected"):
			coin.collected.connect(_on_orbe_collected)

func _on_orbe_collected() -> void:
	score_add()
	orbe_collected.emit()

func score_add() -> void:
	score += 1
	print("Puntos: ", score)
	if score >= 6:
		print("¡Ganaste!")
		winner.emit()

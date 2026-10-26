extends AudioStreamPlayer

func _ready() -> void:
	finished.connect(_on_finished)
	play()

func _on_finished() -> void:
	play()

extends AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = "Master"
	volume_db = 0.0

	finished.connect(_on_finished)
	play()


func _on_finished() -> void:
	play()

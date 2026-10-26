extends Control

@onready var play_button: TextureButton = $ButtonsBox/PlayButton
@onready var quit_button: TextureButton = $ButtonsBox/QuitButton
@onready var sound_inicio: AudioStreamPlayer = $SoundInicio

func _ready()-> void:
	print("Menu listo")
	sound_inicio.play()
	play_button.pressed.connect(_on_play_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func _on_play_button_pressed() -> void:
	print("play pulsado")
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	
func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_sound_inicio_finished() -> void:
	pass # Replace with function body.

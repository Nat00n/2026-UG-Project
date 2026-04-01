extends CanvasLayer

@onready var playButton: Button = $CenterContainer/VBoxContainer/PlayButton

func _ready():
	playButton.pressed.connect(onPlay)

func onPlay():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

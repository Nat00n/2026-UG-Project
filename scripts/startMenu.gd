extends CanvasLayer

@onready var playButton: Button = $CenterContainer/VBoxContainer/PlayButton
@export var mainScene: PackedScene

func _ready():
	playButton.pressed.connect(onPlay)

func onPlay():
	get_tree().change_scene_to_packed(mainScene)

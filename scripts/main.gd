extends Node2D

@onready var IDE: CanvasLayer = $IDE
@onready var roomManager: Node2D = $RoomManager
@onready var pauseMenu: CanvasLayer = $PauseMenu
@onready var pauseButton: Button = $RoomUI/PauseButton

func _ready():
	pauseButton.pressed.connect(onPause)
	roomManager.init(IDE)

func onPause():
	pauseMenu.openPause()

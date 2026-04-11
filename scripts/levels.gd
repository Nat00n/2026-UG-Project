extends Node2D


@onready var roomManager: Node2D = $RoomManager
@onready var pauseButton: Button = $RoomUI/PauseButton
@onready var pauseMenu: CanvasLayer = $PauseMenu
@onready var IDE: CanvasLayer = $IDE

@export var levelId: String = "1-1"

var progressionManager

func _ready():
	progressionManager = get_node("/root/LevelProgressionManager")
	pauseButton.pressed.connect(onPause)
	roomManager.init(IDE)

func onPause():
	pauseMenu.openPause()

# Call this when the player completes the level's objective
func completeLevelObjective():
	progressionManager.completeLevel(levelId)
	
	# Show completion screen or return to level selection
	# You might want to show a "Level Complete!" screen first
	await get_tree().create_timer(2.0).timeout
	returnToLevelSelection()

func returnToLevelSelection():
	get_tree().change_scene_to_file("res://scenes/LevelSelectionScreen.tscn")

# Example: Complete level when player presses a button
func _on_finish_button_pressed():
	completeLevelObjective()

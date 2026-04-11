extends Control

@onready var levelMap: Control = $Map

@onready var levelInfo: Panel = $LevelInfo

@onready var levelName: Label = $LevelInfo/VBoxContainer/LevelName

@onready var startButton: Button = $LevelInfo/VBoxContainer/StartButton

@onready var pauseButton: Button = $PauseButton
@onready var pauseMenu: CanvasLayer = $PauseMenu


var progressionManager

func _ready():
	progressionManager = get_node("/root/LevelProgressionManager")
	
	# Connect signals
	levelMap.levelSelected.connect(_onLevelSelected)
	startButton.pressed.connect(_onStartButtonPressed)
	pauseButton.pressed.connect(_onPause)
	
	# Hide info panel initially
	levelInfo.visible = false

func _onLevelSelected(levelId: String):
	var level = progressionManager.levels[levelId]
	
	# Update info panel
	levelName.text = level.levelName
	
	if level.isCompleted:
		startButton.text = "Replay"
	else:
		startButton.text = "Start"
	
	startButton.set_meta("levelId", levelId)
	levelInfo.visible = true

func _onStartButtonPressed():
	var levelId = startButton.get_meta("levelId")
	var level = progressionManager.levels[levelId]
	
	# Load the level scene
	get_tree().change_scene_to_file(level.scenePath)
	
func _onPause():
	pauseMenu.openPause()

# Call this when a level is completed
func onLevelCompleted(levelId: String):
	progressionManager.completeLevel(levelId)
	levelMap.refreshDisplay()

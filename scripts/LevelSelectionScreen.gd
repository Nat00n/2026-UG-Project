extends Control

@onready var levelMap = $LevelSelectionMap
@onready var levelInfoPanel = $LevelInfoPanel
@onready var levelNameLabel = $LevelInfoPanel/VBoxContainer/LevelName
@onready var startButton = $LevelInfoPanel/VBoxContainer/StartButton
@onready var backButton = $BackButton

var progressionManager

func _ready():
	progressionManager = get_node("/root/LevelProgressionManager")
	
	# Connect signals
	levelMap.levelSelected.connect(_onLevelSelected)
	startButton.pressed.connect(_onStartButtonPressed)
	backButton.pressed.connect(_onBackButtonPressed)
	
	# Hide info panel initially
	levelInfoPanel.visible = false

func _onLevelSelected(levelId: String):
	var level = progressionManager.levels[levelId]
	
	# Update info panel
	levelNameLabel.text = level.levelName
	
	if level.isCompleted:
		startButton.text = "Replay"
	else:
		startButton.text = "Start"
	
	startButton.set_meta("levelId", levelId)
	levelInfoPanel.visible = true

func _onStartButtonPressed():
	var levelId = startButton.get_meta("levelId")
	var level = progressionManager.levels[levelId]
	
	# Load the level scene
	get_tree().change_scene_to_file(level.scenePath)

func _onBackButtonPressed():
	# Return to main menu or previous screen
	get_tree().change_scene_to_file("res://main_menu.tscn")

# Call this when a level is completed
func onLevelCompleted(levelId: String):
	progressionManager.completeLevel(levelId)
	levelMap.refreshDisplay()

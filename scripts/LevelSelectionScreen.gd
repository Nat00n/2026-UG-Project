extends Control


@onready var levelMap: Control = $CanvasLayer/Map
@onready var levelInfo: Panel = $CanvasLayer/LevelInfo
@onready var levelName: Label = $CanvasLayer/LevelInfo/VBoxContainer/LevelName
@onready var startButton: Button = $CanvasLayer/LevelInfo/VBoxContainer/StartButton
@onready var pauseButton: Button = $CanvasLayer/PauseButton
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
	
	AudioManager.playMusic("level_select")
	
	# Refresh display on ready
	refreshDisplay()

# Refresh display when screen becomes visible
func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		if not progressionManager:
			return
		refreshDisplay()

func refreshDisplay():
	if not progressionManager:
		return
	if levelMap:
		levelMap.refreshDisplay()

func _onLevelSelected(levelId: String):
	
	var level = progressionManager.levels[levelId]
	
	# Update level name
	levelName.text = level.levelName
	
	# Update button text based on completion state
	if level.isFullyComplete():
		startButton.text = "Replay *"
	elif level.isMinimumComplete():
		var roomsComplete = level.completedRooms.size()
		var totalRooms = level.totalRooms
		startButton.text = "Continue (%d/%d)" % [roomsComplete, totalRooms]
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

# Call this when a level is completed (if needed)
func onLevelCompleted(levelId: String):
	levelMap.refreshDisplay()

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
	
	# CRITICAL: Refresh display on ready
	refreshDisplay()

# CRITICAL: Refresh display when screen becomes visible
func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		if not progressionManager:
			return
		print("\n[LevelSelect] Screen shown - refreshing display")
		refreshDisplay()

func refreshDisplay():
	if not progressionManager:
		return
	print("[LevelSelect] Refreshing display with current progression:")
	for levelId in progressionManager.levels:
		var level = progressionManager.levels[levelId]
		print("  ", levelId, ": ", level.completedRooms.size(), "/", level.totalRooms, " (unlocked: ", level.isUnlocked, ")")
	if levelMap:
		levelMap.refreshDisplay()

func _onLevelSelected(levelId: String):
	print("\n[LevelSelect] Level selected: ", levelId)
	
	var level = progressionManager.levels[levelId]
	
	# Update level name
	levelName.text = level.levelName
	
	# Update button text based on completion state
	if level.isFullyComplete():
		startButton.text = "Replay *"
		print("  Status: Fully complete")
	elif level.isMinimumComplete():
		var roomsComplete = level.completedRooms.size()
		var totalRooms = level.totalRooms
		startButton.text = "Continue (%d/%d)" % [roomsComplete, totalRooms]
		print("  Status: ", roomsComplete, "/", totalRooms, " rooms complete")
	else:
		startButton.text = "Start"
		print("  Status: Not started")
	
	startButton.set_meta("levelId", levelId)
	levelInfo.visible = true

func _onStartButtonPressed():
	var levelId = startButton.get_meta("levelId")
	var level = progressionManager.levels[levelId]
	
	print("[LevelSelect] Starting level: ", levelId)
	
	# Load the level scene
	get_tree().change_scene_to_file(level.scenePath)
	
func _onPause():
	pauseMenu.openPause()

# Call this when a level is completed (if needed)
func onLevelCompleted(levelId: String):
	levelMap.refreshDisplay()

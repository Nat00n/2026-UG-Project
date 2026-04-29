extends Control # Level Selection Screen Script
# Manages the level selection UI, listens for a level being chosen on the map,
# displays level info (name, completion state), and loads the selected level scene
 
@onready var levelMap: Control = $CanvasLayer/Map
@onready var levelInfo: Panel = $CanvasLayer/LevelInfo
@onready var levelName: Label = $CanvasLayer/LevelInfo/VBoxContainer/LevelName
@onready var startButton: Button = $CanvasLayer/LevelInfo/VBoxContainer/StartButton
@onready var pauseButton: Button = $CanvasLayer/PauseButton
@onready var pauseMenu: CanvasLayer = $PauseMenu
 
var progressionManager
 
func _ready():
	progressionManager = get_node("/root/LevelProgressionManager")
	levelMap.levelSelected.connect(_onLevelSelected)
	startButton.pressed.connect(_onStartButtonPressed)
	pauseButton.pressed.connect(_onPause)
	levelInfo.visible = false
	AudioManager.playMusic("level_select")
	refreshDisplay()
 
func _notification(what):
	# Refresh the map whenever this screen becomes visible (e.g. after returning from a level)
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
	# Populates the info panel with the selected level's name and button text depending on progress
	var level = progressionManager.levels[levelId]
	levelName.text = level.levelName
	if level.isFullyComplete():
		startButton.text = "Replay *"
	elif level.isMinimumComplete():
		startButton.text = "Continue (%d/%d)" % [level.completedRooms.size(), level.totalRooms]
	else:
		startButton.text = "Start"
	startButton.set_meta("levelId", levelId)
	levelInfo.visible = true
 
func _onStartButtonPressed():
	var levelId = startButton.get_meta("levelId")
	var level = progressionManager.levels[levelId]
	get_tree().change_scene_to_file(level.scenePath)
 
func _onPause():
	pauseMenu.openPause()
 
func onLevelCompleted(levelId: String):
	levelMap.refreshDisplay()

extends Node2D # Level Script
# Root script for a level scene, Responsibilities:
#   - Initialises the room system and IDE reference
#   - Connects each interactable object's roomTaskCompleted signal
#   - Maps object IDs to room indices so completion is recorded for the correct room
#   - Updates the progress indicator and Return button as rooms are completed
#   - Delegates persistence to LevelProgressionManager
 
@onready var roomManager: Node2D = $RoomManager
@onready var pauseButton: Button = $RoomUI/PauseButton
@onready var pauseMenu: CanvasLayer = $PauseMenu
@onready var IDE: CanvasLayer = $IDE
@onready var roomProgressIndicator: RoomProgressIndicator = $RoomUI/RoomProgressIndicator
@onready var returnButton: Button = $RoomUI/ReturnButton
@onready var introLabel: RichTextLabel = $RoomUI/IntroContainer/IntroLabel
@onready var startButton: Button = $RoomUI/IntroContainer/StartButton
@onready var introContainer: VBoxContainer = $RoomUI/IntroContainer
 
@export var levelId: String = "1-1"
@export var totalRooms: int = 4
@export_multiline var introContext: String = ""
 
var progressionManager
var currentRoomIndex: int = 0
var objectToRoomMap: Dictionary = {}  # Maps objectID -> room index for completion routing
 
func _ready():
	progressionManager = get_node("/root/LevelProgressionManager")
	pauseButton.pressed.connect(onPause)
	roomManager.init(IDE)
	introLabel.text = introContext
	startButton.pressed.connect(onStartPressed)
	AudioManager.playMusic(levelId)
	setupReturnButton()
 
	var level = progressionManager.levels.get(levelId)
	if level:
		roomProgressIndicator.setup(totalRooms, level.completedRooms, currentRoomIndex)
		updateReturnButtonVisibility()
	else:
		roomProgressIndicator.setup(totalRooms, [], currentRoomIndex)
 
	if roomManager.has_signal("roomChanged"):
		roomManager.roomChanged.connect(onRoomChanged)
 
	connectObjectSignals()
 
func onStartPressed():
	introContainer.visible = false
 
func setupReturnButton():
	returnButton.visible = false
	returnButton.text = "Return to Level Select"
	returnButton.pressed.connect(onReturnPressed)
 
func updateReturnButtonVisibility():
	# Shows the return button with a pulsing animation once the level is minimally complete
	var level = progressionManager.levels.get(levelId)
	if not level:
		return
	if level.isMinimumComplete():
		if not returnButton.visible:
			returnButton.visible = true
			returnButton.pivot_offset = returnButton.size / 2
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(returnButton, "scale", Vector2(1.1, 1.1), 1.2)
			tween.parallel().tween_property(returnButton, "modulate", Color(1.3, 1.3, 1.0), 1.2)
			tween.tween_property(returnButton, "scale", Vector2(1.0, 1.0), 1.2)
			tween.parallel().tween_property(returnButton, "modulate", Color.WHITE, 1.2)
 
func onReturnPressed():
	get_tree().change_scene_to_file("res://scenes/LevelSelectionScreen.tscn")
 
func connectObjectSignals():
	# Iterates every room's interactables, connects the completion signal, and records
	# which room each object belongs to so onObjectCompleted routes correctly
	for roomIndex in range(roomManager.rooms.size()):
		var room = roomManager.rooms[roomIndex]
		for obj in room.getInteractables():
			if obj.has_signal("roomTaskCompleted"):
				if not obj.roomTaskCompleted.is_connected(onObjectCompleted):
					obj.roomTaskCompleted.connect(onObjectCompleted)
				objectToRoomMap[obj.objectID] = roomIndex
				Analytics.registerObject(obj.objectID, levelId)
 
	var level = progressionManager.levels.get(levelId)
	if level and level.completedRooms.size() > 0:
		roomProgressIndicator.updateCompletion(level.completedRooms, currentRoomIndex)
 
func onObjectCompleted(objectId: String):
	# Routes completion to the correct room, regardless of which room is currently visible
	if not objectToRoomMap.has(objectId):
		return
	markRoomComplete(objectToRoomMap[objectId])
 
func markRoomComplete(roomIndex: int):
	var level = progressionManager.levels.get(levelId)
	if not level or level.isRoomCompleted(roomIndex):
		return
	progressionManager.completeRoom(levelId, roomIndex)
	roomProgressIndicator.updateCompletion(level.completedRooms, currentRoomIndex)
	updateReturnButtonVisibility()
	if level.isFullyComplete():
		AudioManager.playSFX("task_complete")
 
func onRoomChanged(newRoomIndex: int):
	currentRoomIndex = newRoomIndex
	var level = progressionManager.levels.get(levelId)
	if level:
		roomProgressIndicator.updateCompletion(level.completedRooms, currentRoomIndex)
 
func onPause():
	pauseMenu.openPause()

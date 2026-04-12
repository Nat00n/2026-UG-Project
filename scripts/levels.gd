extends Node2D

@onready var roomManager: Node2D = $RoomManager
@onready var pauseButton: Button = $RoomUI/PauseButton
@onready var pauseMenu: CanvasLayer = $PauseMenu
@onready var IDE: CanvasLayer = $IDE
@onready var roomProgressIndicator: RoomProgressIndicator = $RoomUI/RoomProgressIndicator

@export var levelId: String = "1-1"
@export var totalRooms: int = 3  # Set this to match your room count

var progressionManager
var currentRoomIndex: int = 0
var completedObjectsThisSession: Array[String] = []

func _ready():
	progressionManager = get_node("/root/LevelProgressionManager")
	pauseButton.pressed.connect(onPause)
	roomManager.init(IDE)
	
	# Initialize room progress indicator
	var level = progressionManager.levels.get(levelId)
	if level:
		roomProgressIndicator.setup(totalRooms, level.completedRooms, currentRoomIndex)
	else:
		roomProgressIndicator.setup(totalRooms, [], currentRoomIndex)
	
	# Connect room change signal if available
	if roomManager.has_signal("roomChanged"):
		roomManager.roomChanged.connect(onRoomChanged)
	
	# Connect all object completion signals
	connectObjectSignals()

func connectObjectSignals():
	# Get all interactable objects in all rooms
	for room in roomManager.rooms:
		for obj in room.getInteractables():
			if obj.has_signal("roomTaskCompleted"):
				obj.roomTaskCompleted.connect(onObjectCompleted)

func onObjectCompleted(objectId: String):
	# Prevent double-counting in same session
	if completedObjectsThisSession.has(objectId):
		return
	
	completedObjectsThisSession.append(objectId)
	print("[Level] Object completed: " + objectId)
	
	# Mark current room as complete
	markCurrentRoomComplete()

func markCurrentRoomComplete():
	var level = progressionManager.levels.get(levelId)
	if level and not level.isRoomCompleted(currentRoomIndex):
		progressionManager.completeRoom(levelId, currentRoomIndex)
		roomProgressIndicator.updateCompletion(level.completedRooms, currentRoomIndex)
		
		print("[Level] Room " + str(currentRoomIndex) + " completed!")
		showRoomCompleteMessage()

func showRoomCompleteMessage():
	var level = progressionManager.levels.get(levelId)
	if level.isFullyComplete():
		print("★ All rooms completed! Perfect score!")
		# Optionally show UI message or return to level select after delay
	elif level.completedRooms.size() == 1:
		print("✓ First room complete! Level unlocked!")

func onRoomChanged(newRoomIndex: int):
	currentRoomIndex = newRoomIndex
	var level = progressionManager.levels.get(levelId)
	if level:
		roomProgressIndicator.updateCompletion(level.completedRooms, currentRoomIndex)

func onPause():
	pauseMenu.openPause()

func returnToLevelSelection():
	get_tree().change_scene_to_file("res://scenes/LevelSelectionScreen.tscn")

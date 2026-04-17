extends Node2D

@onready var roomManager: Node2D = $RoomManager
@onready var pauseButton: Button = $RoomUI/PauseButton
@onready var pauseMenu: CanvasLayer = $PauseMenu
@onready var IDE: CanvasLayer = $IDE
@onready var roomProgressIndicator: RoomProgressIndicator = $RoomUI/RoomProgressIndicator
@onready var returnButton: Button = $RoomUI/ReturnButton

@export var levelId: String = "1-1"
@export var totalRooms: int = 4

var progressionManager
var currentRoomIndex: int = 0
var objectToRoomMap: Dictionary = {}  # Maps objectID -> room index

func _ready():
	progressionManager = get_node("/root/LevelProgressionManager")
	pauseButton.pressed.connect(onPause)
	roomManager.init(IDE)
	
	AudioManager.playMusic(levelId)
	
	# Setup return button
	setupReturnButton()
	
	# Load saved progress and initialize room indicator
	var level = progressionManager.levels.get(levelId)
	if level:
		print("[Level] Loading saved progress for ", levelId)
		print("  Completed rooms: ", level.completedRooms)
		roomProgressIndicator.setup(totalRooms, level.completedRooms, currentRoomIndex)
		
		# Show return button if minimum already complete
		updateReturnButtonVisibility()
	else:
		print("[Level] WARNING: Level ", levelId, " not found in progression manager!")
		roomProgressIndicator.setup(totalRooms, [], currentRoomIndex)
	
	# Connect room change signal
	if roomManager.has_signal("roomChanged"):
		roomManager.roomChanged.connect(onRoomChanged)
	
	# Connect all object completion signals AND map objects to rooms
	connectObjectSignals()

func setupReturnButton():
	# Configure the return button
	returnButton.visible = false
	returnButton.text = "Return to Level Select"
	returnButton.pressed.connect(onReturnPressed)

func updateReturnButtonVisibility():
	# Show button if minimum rooms are complete
	var level = progressionManager.levels.get(levelId)
	if not level:
		return
	
	if level.isMinimumComplete():
		if not returnButton.visible:
			print("[Level] Showing return button (minimum complete)")
			returnButton.visible = true
			
			# Set pivot to center so it scales from the middle
			returnButton.pivot_offset = returnButton.size / 2
			
			# Pulse animation - slower with color change
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(returnButton, "scale", Vector2(1.1, 1.1), 1.2)
			tween.parallel().tween_property(returnButton, "modulate", Color(1.3, 1.3, 1.0), 1.2)  # Slight yellow tint
			tween.tween_property(returnButton, "scale", Vector2(1.0, 1.0), 1.2)
			tween.parallel().tween_property(returnButton, "modulate", Color.WHITE, 1.2)

func onReturnPressed():
	"""Return to level selection screen"""
	print("[Level] Returning to level select...")
	get_tree().change_scene_to_file("res://scenes/LevelSelectionScreen.tscn")

func connectObjectSignals():
	print("[Level] Connecting object signals and mapping to rooms...")
	
	for roomIndex in range(roomManager.rooms.size()):
		var room = roomManager.rooms[roomIndex]
		for obj in room.getInteractables():
			if obj.has_signal("roomTaskCompleted"):
				# Connect the signal (avoid duplicate connections)
				if not obj.roomTaskCompleted.is_connected(onObjectCompleted):
					obj.roomTaskCompleted.connect(onObjectCompleted)

				# CRITICAL: Map this object to its room index
				objectToRoomMap[obj.objectID] = roomIndex
				Analytics.registerObject(obj.objectID, levelId)
				print("  o ", obj.objectID, " → Room ", roomIndex)
			else:
				print("  x ", obj.objectID, " has no signal!")
	
	print("[Level] Total objects mapped: ", objectToRoomMap.size())
	print("[Level] Object-to-room mapping complete")
	print()
	
	# Show which rooms are already complete from saved data
	var level = progressionManager.levels.get(levelId)
	if level and level.completedRooms.size() > 0:
		print("[Level] Previously completed rooms: ", level.completedRooms)
		roomProgressIndicator.updateCompletion(level.completedRooms, currentRoomIndex)

func onObjectCompleted(objectId: String):
	print("\n[Level] 🎯 Object completed: ", objectId)
	
	if not objectToRoomMap.has(objectId):
		print("  ERROR: Object not in room map!")
		print("  Available objects: ", objectToRoomMap.keys())
		return
	
	var objectRoomIndex = objectToRoomMap[objectId]
	print("  Object is in Room ", objectRoomIndex)
	print("  Current room showing: ", currentRoomIndex)
	
	# Mark the OBJECT'S room as complete, not the current room
	markRoomComplete(objectRoomIndex)

func markRoomComplete(roomIndex: int):
	print("[Level] Marking Room ", roomIndex, " complete")
	
	var level = progressionManager.levels.get(levelId)
	if not level:
		print("  ERROR: Level not found!")
		return
	
	if level.isRoomCompleted(roomIndex):
		print("  Already complete, skipping")
		return
	
	# Complete the room
	progressionManager.completeRoom(levelId, roomIndex)
	
	print("  o Room ", roomIndex, " marked complete")
	print("  Progress: ", level.completedRooms.size(), "/", level.totalRooms)
	
	# Update the indicator
	roomProgressIndicator.updateCompletion(level.completedRooms, currentRoomIndex)
	
	# Show return button if minimum complete
	updateReturnButtonVisibility()
	
	# Show message
	if level.isFullyComplete():
		print("  ! ALL ROOMS COMPLETE!")
		AudioManager.playSFX("task_complete")
	elif level.completedRooms.size() == 1:
		print("  o First room complete - next level unlocked!")
		print("  o Return button now available!")

func onRoomChanged(newRoomIndex: int):
	print("[Level] Room changed: ", currentRoomIndex, " → ", newRoomIndex)
	currentRoomIndex = newRoomIndex
	var level = progressionManager.levels.get(levelId)
	if level:
		roomProgressIndicator.updateCompletion(level.completedRooms, currentRoomIndex)

func onPause():
	pauseMenu.openPause()

func returnToLevelSelection():
	get_tree().change_scene_to_file("res://scenes/LevelSelectionScreen.tscn")

extends Node2D

signal roomChanged(newRoomIndex: int)  # NEW: Signal when room changes

@onready var leftButton: Button = $"../RoomUI/LeftButton"
@onready var rightButton: Button = $"../RoomUI/RightButton"
@onready var IDE: CanvasLayer = $"../IDE"

var rooms: Array = []
var currentRoomIndex: int = 0

func _ready():
	# Collect all child rooms
	for child in get_children():
		rooms.append(child)
	leftButton.pressed.connect(goLeft)
	rightButton.pressed.connect(goRight)
	_showRoom(0)
	
func init(popupRef: CanvasLayer):
	IDE = popupRef
	_showRoom(0)

func _showRoom(index: int):
	for i in range(rooms.size()):
		rooms[i].visible = (i == index)
	rooms[index].onShow()
	# Pass popup reference to all interactables in the current room
	for interactable in rooms[index].getInteractables():
		interactable._popup = IDE
	leftButton.disabled = (index == 0)
	rightButton.disabled = (index == rooms.size() - 1)

func goLeft():
	if currentRoomIndex > 0:
		currentRoomIndex -= 1
		_showRoom(currentRoomIndex)
		roomChanged.emit(currentRoomIndex)  # NEW: Emit signal

func goRight():
	if currentRoomIndex < rooms.size() - 1:
		currentRoomIndex += 1
		_showRoom(currentRoomIndex)
		roomChanged.emit(currentRoomIndex)  # NEW: Emit signal

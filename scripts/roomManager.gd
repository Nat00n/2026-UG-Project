extends Node2D # Room Manager Script
# Controls which room is currently visible and provides left/right navigation buttons
# Emits roomChanged whenever the player navigates so the Level script can update the indicator
 
signal roomChanged(newRoomIndex: int)
 
@onready var leftButton: Button = $"../RoomUI/LeftButton"
@onready var rightButton: Button = $"../RoomUI/RightButton"
@onready var IDE: CanvasLayer = $"../IDE"
 
var rooms: Array = []
var currentRoomIndex: int = 0
 
func _ready():
	for child in get_children():
		rooms.append(child)
	leftButton.pressed.connect(goLeft)
	rightButton.pressed.connect(goRight)
	_showRoom(0)
 
func init(popupRef: CanvasLayer):
	# Receives the IDE reference from the Level script so it can inject it into each object
	IDE = popupRef
	_showRoom(0)
 
func _showRoom(index: int):
	# Hides all rooms except the one at 'index', then injects the IDE popup reference
	# into every interactable in the newly visible room
	for i in range(rooms.size()):
		rooms[i].visible = (i == index)
	rooms[index].onShow()
	for interactable in rooms[index].getInteractables():
		interactable._popup = IDE
	leftButton.disabled = (index == 0)
	rightButton.disabled = (index == rooms.size() - 1)
 
func goLeft():
	if currentRoomIndex > 0:
		currentRoomIndex -= 1
		_showRoom(currentRoomIndex)
		roomChanged.emit(currentRoomIndex)
 
func goRight():
	if currentRoomIndex < rooms.size() - 1:
		currentRoomIndex += 1
		_showRoom(currentRoomIndex)
		roomChanged.emit(currentRoomIndex)

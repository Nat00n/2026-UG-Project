class_name SearchObject # Search Object Script
extends InteractableObject
# Implements the search algorithm visualisation task
# The player writes a Python search algorithm using check() to highlight visited indices and commitSelect() to mark the found element
# The object verifies the result afterwards
# Can operate standalone (with its own random array) or receive a sorted array from a SortObject

@onready var selectionBeam: Line2D = $selectionBeam  # Line drawn from the object to the selected card

var targetValue         # The value the player's algorithm must locate
@export var sortReq: bool = false  # If true, generate a pre-sorted array (for binary search tasks)

var checkQueue: Array = []   # Queued animation steps: check (cyan highlight) or select (yellow + beam)
var isAnimating: bool = false
var checkTimer: float = 0.0
var checkDelay: float = 0.3  # Seconds between each animated step
var foundPosition: int = -1  # The index passed to commitSelect(), verified after animation

### Setup

func _init_object():
	if is_instance_valid(selectionBeam):
		selectionBeam.visible = false
		selectionBeam.width = 3
		selectionBeam.default_color = Color.YELLOW

func _ready():
	super._ready()
	# Only generate a standalone array if no SortObject is present in the room
	var hasSortObject = false
	for node in get_parent().get_children():
		if node is SortObject:
			hasSortObject = true
			break
	if not hasSortObject:
		for i in range(10):
			dataNodes.append({
				"name": "node%d" % i,
				"value": i + 1 if sortReq else randi_range(1, 10)
			})
		initialDataNodes = dataNodes.duplicate(true)
		targetValue = dataNodes[randi() % dataNodes.size()]["value"]
		_buildDisplay()

func resetDisplay():
	checkQueue.clear()
	isAnimating = false
	checkTimer = 0.0
	foundPosition = -1
	for card in cardNodes:
		if is_instance_valid(card):
			card.modulate = Color.WHITE
	if is_instance_valid(selectionBeam):
		selectionBeam.visible = false
	if initialDataNodes.is_empty():
		return
	super.resetDisplay()

func receiveArray(sortedNodes: Array):
	# Called by SortObject after its animation completes, replaces the local array with the sorted one
	dataNodes = sortedNodes.duplicate(true)
	initialDataNodes = dataNodes.duplicate(true)
	checkQueue.clear()
	isAnimating = false
	checkTimer = 0.0
	if is_instance_valid(selectionBeam):
		selectionBeam.visible = false
	targetValue = dataNodes[randi() % dataNodes.size()]["value"]
	
	_buildDisplay()

### Animation

func _process(delta):
	super._process(delta)  # handles hover

	if isAnimating and not checkQueue.is_empty():
		checkTimer += delta
		if checkTimer >= checkDelay:
			checkTimer = 0.0
			_stepCheck()
	elif isAnimating and checkQueue.is_empty():
		isAnimating = false

func _restoreTileStyle(card: PanelContainer):
	# Reverts a card's background to the default tile texture after highlighting
	var tileStyle = StyleBoxTexture.new()
	tileStyle.texture = _getCardTileTexture()
	card.add_theme_stylebox_override("panel", tileStyle)

func _stepCheck():
	# Processes one step from the queue, highlights the checked or selected card
	if checkQueue.is_empty():
		isAnimating = false
		return
	var step = checkQueue.pop_front()
	# Clear all highlights before applying the new one
	for i in range(cardNodes.size()):
		cardNodes[i].get_child(0).remove_theme_color_override("font_color")
		cardNodes[i].modulate = Color.WHITE
		_restoreTileStyle(cardNodes[i])

	if step["type"] == "check":
		# Cyan = currently inspecting
		var card = cardNodes[step["index"]]
		card.get_child(0).add_theme_color_override("font_color", Color.CYAN)
		card.modulate = Color(0.5, 1.0, 1.0)
	elif step["type"] == "select":
		# Yellow = found result, also draws the selection beam from the object to the card
		var card = cardNodes[step["index"]]
		card.get_child(0).add_theme_color_override("font_color", Color.YELLOW)
		card.modulate = Color(1.0, 1.0, 0.5)
		var cardCentre = card.global_position + Vector2(cardWidth / 2.0, 0)
		var spriteSize = visual.texture.get_size() * visual.scale
		var spritePos = visual.global_position
		if visual.centered:
			spritePos -= spriteSize / 2.0
		var objectCentre = spritePos + spriteSize / 2.0
		selectionBeam.clear_points()
		selectionBeam.add_point(to_local(objectCentre))
		selectionBeam.add_point(to_local(cardCentre))
		selectionBeam.visible = true

### Bridge Methods

func queueCheck(index: int):
	checkQueue.append({"type": "check", "index": index})
	isAnimating = true

func queueSelect(index: int):
	foundPosition = index  # Record selected index for post-animation verification.
	checkQueue.append({"type": "select", "index": index})
	isAnimating = true

func commitSearch():
	# Waits for all animation steps to complete, then verifies the result.
	isAnimating = true
	await get_tree().create_timer(checkDelay * checkQueue.size() + 0.3).timeout
	verifySearchResult()

### Verification

func verifySearchResult():
	if foundPosition == -1:
		AudioManager.playSFX("error")
		return
	if foundPosition < 0 or foundPosition >= dataNodes.size():
		AudioManager.playSFX("error")
		return
	# The player's selected index must contain the target value
	if dataNodes[foundPosition]["value"] != targetValue:
		AudioManager.playSFX("error")
		return

	Global.submitScore()
	roomTaskCompleted.emit(objectID)
	Analytics.recordComplete(objectID)
	AudioManager.playSFX("task_complete")

### Preamble & Guide

func getPreambleFunctions() -> String:
	return """
array = %s
targetValue = %d

def check(index):
	talk("__check__:" + str(index))

def commitSelect(index):
	talk("__commitSelect__:" + str(index))
""" % [getArrayString(), targetValue]

func getBaseGuide() -> String:
	return """[b]Available Data:[/b]

[code]array[/code]
A list of integers representing the values to search through.
Example: [2, 5, 7, 9, 12]
The array might first need to be sourced from another system.

[code]targetValue[/code]
The integer value you are searching for within the array.

[b]Available Functions:[/b]

[code]check(index)[/code]
Highlights the element at index as currently being inspected (shown in cyan).

[code]commitSelect(index)[/code]
Marks the element at index as the found result and ends the search animation.
Call this once you have located the target value and ended the search."""

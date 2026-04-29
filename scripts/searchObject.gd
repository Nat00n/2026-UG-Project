class_name SearchObject
extends InteractableObject

@onready var selectionBeam: Line2D = $selectionBeam

var targetValue
@export var sortReq: bool = false

var checkQueue: Array = []
var isAnimating: bool = false
var checkTimer: float = 0.0
var checkDelay: float = 0.3
var foundPosition: int = -1  # Track the position user selected

# Track if array was received from sort
var arrayReceivedFromSort: bool = false
var expectedPosition: int = -1

func _init_object():
	if is_instance_valid(selectionBeam):
		selectionBeam.visible = false
		selectionBeam.width = 3
		selectionBeam.default_color = Color.YELLOW

func _ready():
	super._ready()
	# Generate own data only if no sort object in the same room
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
	arrayReceivedFromSort = false
	expectedPosition = -1
	foundPosition = -1  # Reset found position
	for card in cardNodes:
		if is_instance_valid(card):
			card.modulate = Color.WHITE
	if is_instance_valid(selectionBeam):
		selectionBeam.visible = false
	if initialDataNodes.is_empty():
		return
	super.resetDisplay()

# Called by SortObject when it sends the sorted array
func receiveArray(sortedNodes: Array):
	dataNodes = sortedNodes.duplicate(true)
	initialDataNodes = dataNodes.duplicate(true)
	checkQueue.clear()
	isAnimating = false
	checkTimer = 0.0
	arrayReceivedFromSort = true
	
	if is_instance_valid(selectionBeam):
		selectionBeam.visible = false
	
	targetValue = dataNodes[randi() % dataNodes.size()]["value"]
	
	# Find expected position for verification
	expectedPosition = -1
	for i in range(dataNodes.size()):
		if dataNodes[i]["value"] == targetValue:
			expectedPosition = i
			break
	
	_buildDisplay()

func _process(delta):
	# Mouse hover handled by base class
	var mouse = get_global_mouse_position()
	# Calculate Sprite2D bounds
	var sprite_size = Vector2.ZERO
	if visual.texture:
		sprite_size = visual.texture.get_size() * visual.scale

	# Account for centered sprite
	var sprite_pos = visual.global_position
	if visual.centered:
		sprite_pos -= sprite_size / 2.0

	var rect = Rect2(sprite_pos, sprite_size)
	var wasHovered = _hovered
	_hovered = rect.has_point(mouse)
	if _hovered != wasHovered:
		hoverLabel.visible = _hovered

	if isAnimating and not checkQueue.is_empty():
		checkTimer += delta
		if checkTimer >= checkDelay:
			checkTimer = 0.0
			_stepCheck()
	elif isAnimating and checkQueue.is_empty():
		isAnimating = false

func _restoreTileStyle(card: PanelContainer):
	var tileStyle = StyleBoxTexture.new()
	tileStyle.texture = _getCardTileTexture()
	card.add_theme_stylebox_override("panel", tileStyle)

func _stepCheck():
	if checkQueue.is_empty():
		isAnimating = false
		return

	var step = checkQueue.pop_front()

	# Clear all highlights — restore tile style instead of removing it
	for i in range(cardNodes.size()):
		cardNodes[i].get_child(0).remove_theme_color_override("font_color")
		cardNodes[i].modulate = Color.WHITE
		_restoreTileStyle(cardNodes[i])

	if step["type"] == "check":
		var card = cardNodes[step["index"]]
		card.get_child(0).add_theme_color_override("font_color", Color.CYAN)
		card.modulate = Color(0.5, 1.0, 1.0)

	elif step["type"] == "select":
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

func _makeStyleBox(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func queueCheck(index: int):
	checkQueue.append({"type": "check", "index": index})
	isAnimating = true

func queueSelect(index: int):
	foundPosition = index
	checkQueue.append({"type": "select", "index": index})
	isAnimating = true

# Verify position is correct
func commitSearch():
	isAnimating = true
	# Wait for animation to finish, then verify
	await get_tree().create_timer(checkDelay * checkQueue.size() + 0.3).timeout
	verifySearchResult()

func verifySearchResult():
	
	# If we're in standalone mode (no sort object), we need to find expected position
	if not arrayReceivedFromSort:
		expectedPosition = -1
		for i in range(dataNodes.size()):
			if dataNodes[i]["value"] == targetValue:
				expectedPosition = i
				break
	
	# Check if commitSelect was called
	if foundPosition == -1:
		AudioManager.playSFX("error")
		return
	
	# Verify correctness
	if foundPosition < 0 or foundPosition >= dataNodes.size():
		AudioManager.playSFX("error")
		return
	
	var valueAtFound = dataNodes[foundPosition]["value"]
	
	if valueAtFound != targetValue:
		AudioManager.playSFX("error")
		return

	Global.submitScore()
	roomTaskCompleted.emit(objectID)  # Complete room
	Analytics.recordComplete(objectID)
	AudioManager.playSFX("task_complete")

func getPreambleFunctions() -> String:
	return """
targetValue = %d

def check(index):
	talk("__check__:" + str(index))

def commitSelect(index):
	talk("__commitSelect__:" + str(index))
""" % targetValue

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

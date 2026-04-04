class_name SearchObject
extends InteractableObject

@onready var selectionBeam: Line2D = $selectionBeam
@export var targetValue: int = 5
@export var sortedReq: bool = false

var checkQueue: Array = []  # holds steps: {type: "check"/"select", index: int}
var isAnimating: bool = false

func _ready():
	super._ready()
	var hasSortObject = false
	for node in get_parent().get_children():
		if node is SortObject:
			hasSortObject = true
			break
	if not hasSortObject:
		if sortedReq:
			for i in range(10):
				dataNodes.append({
					"name": "node%d" % i,
					"value": i+1
				})
		else:
			for i in range(10):
				dataNodes.append({
					"name": "node%d" % i,
					"value": randi_range(1, 10)
				})
		_buildDisplay()

func _init_object():
	selectionBeam.visible = false
	selectionBeam.width = 3
	selectionBeam.default_color = Color.YELLOW

func getPreambleFunctions() -> String:
	return """
targetValue = %d

def check(index):
	talk("__check__:" + str(index))

def commitSelect(index):
	talk("__commitSelect__:" + str(index))
""" % targetValue

func receiveArray(sortedNodes: Array):
	dataNodes = sortedNodes.duplicate(true)
	selectionBeam.visible = false
	checkQueue.clear()
	_buildDisplay()

func queueCheck(index: int):
	checkQueue.append({"type": "check", "index": index})

func queueSelect(index: int):
	checkQueue.append({"type": "select", "index": index})

func commitSearch():
	if not isAnimating:
		isAnimating = true
		_playNextStep()

func _playNextStep():
	if checkQueue.is_empty():
		isAnimating = false
		return

	var step = checkQueue.pop_front()

	if step["type"] == "check":
		_animateCheck(step["index"])
	elif step["type"] == "select":
		_animateSelect(step["index"])

func _animateCheck(index: int):
	if index < 0 or index >= cardNodes.size():
		_playNextStep()
		return

	# Flash the card cyan to show it's being examined
	var card = cardNodes[index]
	var label = card.get_child(0)

	label.add_theme_color_override("font_color", Color.CYAN)
	card.add_theme_stylebox_override("panel", _makeStyleBox(Color(0.2, 0.6, 0.8, 0.4)))

	await get_tree().create_timer(0.3).timeout

	# Fade back unless it will be selected next
	var nextIsSelect = not checkQueue.is_empty() and \
		checkQueue[0]["type"] == "select" and \
		checkQueue[0]["index"] == index

	if not nextIsSelect:
		label.remove_theme_color_override("font_color")
		card.remove_theme_stylebox_override("panel")

	await get_tree().create_timer(0.1).timeout
	_playNextStep()

func _animateSelect(index: int):
	if index < 0 or index >= cardNodes.size():
		_playNextStep()
		return

	# Clear all highlights first
	for i in range(cardNodes.size()):
		cardNodes[i].get_child(0).remove_theme_color_override("font_color")
		cardNodes[i].remove_theme_stylebox_override("panel")

	# Highlight selected card yellow
	var card = cardNodes[index]
	card.get_child(0).add_theme_color_override("font_color", Color.YELLOW)
	card.add_theme_stylebox_override("panel", _makeStyleBox(Color(0.8, 0.7, 0.0, 0.4)))

	# Draw beam to selected card
	var cardCentre = card.global_position + Vector2(cardWidth / 2.0, 0)
	var objectCentre = visual.global_position + visual.size / 2.0
	selectionBeam.clear_points()
	selectionBeam.add_point(to_local(objectCentre))
	selectionBeam.add_point(to_local(cardCentre))
	selectionBeam.visible = true

	await get_tree().create_timer(0.15).timeout
	_playNextStep()

func _makeStyleBox(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

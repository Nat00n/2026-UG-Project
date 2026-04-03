class_name SearchObject
extends InteractableObject

@onready var selectionBeam: Line2D = $selectionBeam
@export var targetValue: int = 5

func _ready():
	super._ready()
	var hasSortObject = false
	for node in get_parent().get_children():
		if node is SortObject:
			hasSortObject = true
			break
	if not hasSortObject:
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

def commitSelect(index):
	talk("__commitSelect__:" + str(index))
""" % targetValue

func receiveArray(sortedNodes: Array):
	print("receiveArray called with ", sortedNodes.size(), " nodes")
	dataNodes = sortedNodes.duplicate(true)

	var totalWidth = dataNodes.size() * (cardWidth + cardGap) - cardGap
	var startX = -totalWidth / 2.0

	# Build cards but start them all at the object centre, then fly to position
	for child in nodeDisplay.get_children():
		child.queue_free()

	var tween = create_tween()
	tween.set_parallel(true)

	for i in range(dataNodes.size()):
		var node = dataNodes[i]
		var scaledHeight = (1.0 + node["value"] / 10.0) * cardHeight

		var card = PanelContainer.new()
		card.size = Vector2(cardWidth, scaledHeight)
		# Start at centre
		card.position = Vector2(0, 2.0 * cardHeight - scaledHeight)

		var label = Label.new()
		label.text = "%s\n%d" % [node["name"], node["value"]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		card.add_child(label)
		nodeDisplay.add_child(card)
		node["card"] = card

		# Fly to final position
		var finalX = startX + i * (cardWidth + cardGap)
		tween.tween_property(card, "position",
			Vector2(finalX, 2.0 * cardHeight - scaledHeight), 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
			.set_delay(i * 0.05)

	nodeDisplay.size = Vector2(totalWidth, 2.0 * cardHeight)
	selectionBeam.visible = false

func commitSelect(index: int):
	if index < 0 or index >= dataNodes.size():
		return

	selectNode(index)

	var cardCentre = cardNodes[index].global_position + Vector2(cardWidth / 2.0, 0)
	var objectCentre = visual.global_position + visual.size / 2.0

	selectionBeam.clear_points()
	selectionBeam.add_point(to_local(objectCentre))
	selectionBeam.add_point(to_local(cardCentre))
	selectionBeam.visible = true

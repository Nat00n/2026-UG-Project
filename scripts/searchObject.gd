class_name SearchObject
extends InteractableObject

@onready var selectionBeam: Line2D = $displayRoot/selectionBeam
@export var targetValue: int = 5

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
	dataNodes = sortedNodes.duplicate(true)
	selectionBeam.visible = false
	_buildDisplay()

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

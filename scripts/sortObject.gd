class_name SortObject
extends InteractableObject

@export var searchTarget: NodePath

var swapQueue: Array = []
var isAnimating: bool = false

func _init_object():
	for i in range(10):
		dataNodes.append({
			"name": "node%d" % i,
			"value": randi_range(1, 10)
		})
	_buildDisplay()

func getPreambleFunctions() -> String:
	return """
def swap(i, j):
	talk("__swap__:" + str(i) + ":" + str(j))
	array[i], array[j] = array[j], array[i]

def commitSort():
	talk("__commit__")
"""

func queueSwap(i: int, j: int):
	swapQueue.append([i, j])

func commitSort():
	if not isAnimating:
		isAnimating = true
		_playNextSwap()
		_sendToSearch()

func _sendToSearch():
	for node in get_parent().get_children():
		if node is SearchObject:
			node.receiveArray(dataNodes)
			break

func _playNextSwap():
	if swapQueue.is_empty():
		isAnimating = false
		return
	var step = swapQueue.pop_front()
	var i = step[0]
	var j = step[1]
	var temp = dataNodes[i]
	dataNodes[i] = dataNodes[j]
	dataNodes[j] = temp
	_animateSwap(i, j)

func _animateSwap(i: int, j: int):
	var totalWidth = dataNodes.size() * (cardWidth + cardGap) - cardGap
	var startX = -totalWidth / 2.0

	var cardA = cardNodes[i]
	var cardB = cardNodes[j]

	var scaledHeightA = (1.0 + dataNodes[i]["value"] / 10.0) * cardHeight
	var scaledHeightB = (1.0 + dataNodes[j]["value"] / 10.0) * cardHeight

	var posA = Vector2(startX + i * (cardWidth + cardGap), 2.0 * cardHeight - scaledHeightA)
	var posB = Vector2(startX + j * (cardWidth + cardGap), 2.0 * cardHeight - scaledHeightB)

	cardA.z_index = 1
	cardB.z_index = 1

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(cardA, "position", posB, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cardB, "position", posA, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(false)

	tween.tween_callback(func():
		var temp = cardNodes[i]
		cardNodes[i] = cardNodes[j]
		cardNodes[j] = temp
		cardNodes[i].get_child(0).text = "%s\n%d" % [dataNodes[i]["name"], dataNodes[i]["value"]]
		cardNodes[j].get_child(0).text = "%s\n%d" % [dataNodes[j]["name"], dataNodes[j]["value"]]
		cardNodes[i].z_index = 0
		cardNodes[j].z_index = 0
		await get_tree().create_timer(0.15).timeout
		_playNextSwap()
	)

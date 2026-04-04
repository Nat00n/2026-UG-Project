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
	print(f"swapping {array[i]} and {array[j]}")
	talk("__swap__:" + str(i) + ":" + str(j))
	array[i], array[j] = array[j], array[i]
	print(f"array now: {array}")

def commitSort():
	talk("__commit__")
"""

func queueSwap(i: int, j: int):
	swapQueue.append([i, j])

func commitSort():
	if not isAnimating:
		isAnimating = true
		_playNextSwap()

func _sendToSearch():
	var searchNode: SearchObject = null
	for node in get_parent().get_children():
		if node is SearchObject:
			searchNode = node
			break
	if searchNode == null:
		return

	var targetPos = searchNode.visual.global_position + searchNode.visual.size / 2.0

	var tween = create_tween()
	tween.set_parallel(true)

	for i in range(cardNodes.size()):
		tween.tween_property(cardNodes[i], "global_position", targetPos, 0.6)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)\
			.set_delay(i * 0.05)

	tween.set_parallel(false)
	tween.tween_callback(func():
		for child in nodeDisplay.get_children():
			child.queue_free()
		cardNodes.clear()
		searchNode.receiveArray(dataNodes.duplicate(true))
	)

func _playNextSwap():
	if swapQueue.is_empty():
		isAnimating = false
		_sendToSearch()
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

	# Only swap x — each card keeps its own y the whole time
	var posA = Vector2(startX + i * (cardWidth + cardGap), cardA.position.y)
	var posB = Vector2(startX + j * (cardWidth + cardGap), cardB.position.y)

	cardA.z_index = 1
	cardB.z_index = 1

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(cardA, "position", Vector2(posB.x, posA.y), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cardB, "position", Vector2(posA.x, posB.y), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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

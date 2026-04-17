class_name SortObject
extends InteractableObject

var swapQueue: Array = []
var isAnimating: bool = false
var pivotIndex: int = -1
var hasSentToSearch: bool = false

# NEW: Search object linking
var linkedSearchObject: SearchObject = null

func _ready():
	super._ready()
	# Check for linked search object in the same room
	await get_tree().process_frame  # Wait for scene to be ready
	for node in get_parent().get_children():
		if node is SearchObject:
			linkedSearchObject = node
			print("[" + objectID + "] Linked to search object: " + node.objectID)
			break

func _init_object():
	for i in range(10):
		dataNodes.append({
			"name": "node%d" % i,
			"value": randi_range(1, 10)
		})
	initialDataNodes = dataNodes.duplicate(true)
	_buildDisplay()

func _buildDisplay():
	if hasSentToSearch:
		return
	super._buildDisplay()

func resetDisplay():
	if hasSentToSearch:
		return
	swapQueue.clear()
	isAnimating = false
	pivotIndex = -1
	hasSentToSearch = false
	super.resetDisplay()

func getPreambleFunctions() -> String:
	return """
def swap(i, j):
	talk("__swap__:" + str(i) + ":" + str(j))
	array[i], array[j] = array[j], array[i]

def move(fromIndex, toIndex):
	talk("__move__:" + str(fromIndex) + ":" + str(toIndex))
	val = array.pop(fromIndex)
	array.insert(toIndex, val)

def setPivot(index):
	talk("__pivot__:" + str(index))
	
def showSplit(start, mid, end):
	talk("__split__:" + str(start) + ":" + str(mid) + ":" + str(end))

def commitSort():
	talk("__commit__")
"""

func queueSwap(i: int, j: int):
	swapQueue.append({"type": "swap", "i": i, "j": j})

func queuePivot(index: int):
	swapQueue.append({"type": "pivot", "index": index})

func queueMove(fromIndex: int, toIndex: int):
	swapQueue.append({"type": "move", "from": fromIndex, "to": toIndex})
	
func queueHighlightSplit(start: int, mid: int, end: int):
	swapQueue.append({"type": "split", "start": start, "mid": mid, "end": end})

func commitSort():
	if not isAnimating:
		isAnimating = true
		_playNextSwap()

func _playNextSwap():
	if swapQueue.is_empty():
		isAnimating = false
		_applyPivot(-1)
		for i in range(cardNodes.size()):
			cardNodes[i].get_child(0).remove_theme_color_override("font_color")

		var tween = createTrackedTween()
		tween.set_parallel(true)
		for i in range(cardNodes.size()):
			var baseY = 2.0 * cardHeight - cardNodes[i].size.y
			tween.tween_property(cardNodes[i], "position:y", baseY, 0.2)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween.tween_callback(func():
			# NEW: Verify sorting is correct before completing
			if not hasSentToSearch:
				verifyAndComplete()
		)
		return

	var step = swapQueue.pop_front()

	if step["type"] == "swap":
		var i = step["i"]
		var j = step["j"]
		var temp = dataNodes[i]
		dataNodes[i] = dataNodes[j]
		dataNodes[j] = temp
		_animateSwap(i, j)
	elif step["type"] == "pivot":
		_applyPivot(step["index"])
		await get_tree().create_timer(0.15).timeout
		_playNextSwap()
	elif step["type"] == "move":
		_animateMove(step["from"], step["to"])
	elif step["type"] == "split":
		var tween = createTrackedTween()
		tween.set_parallel(true)
		for i in range(cardNodes.size()):
			var baseY = 2.0 * cardHeight - cardNodes[i].size.y
			if i >= step["start"] and i < step["mid"]:
				cardNodes[i].get_child(0).add_theme_color_override("font_color", Color.CYAN)
				tween.tween_property(cardNodes[i], "position:y", baseY - 30.0, 0.2)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			elif i >= step["mid"] and i < step["end"]:
				cardNodes[i].get_child(0).add_theme_color_override("font_color", Color.ORANGE)
				tween.tween_property(cardNodes[i], "position:y", baseY - 30.0, 0.2)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			else:
				cardNodes[i].get_child(0).add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
				tween.tween_property(cardNodes[i], "position:y", baseY, 0.2)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween.tween_callback(func():
			_playNextSwap()
		)

# NEW: Verification function
func _isSorted() -> bool:
	for i in range(dataNodes.size() - 1):
		if dataNodes[i]["value"] > dataNodes[i + 1]["value"]:
			return false
	return true

# NEW: Verify correctness before completing
func verifyAndComplete():
	if not _isSorted():
		print("[" + objectID + "] Array is NOT sorted correctly!")
		AudioManager.playSFX("error")
		return
	
	print("[" + objectID + "] Array sorted correctly!")
	
	# Check if we should send to search or complete room
	if linkedSearchObject != null:
		# Has linked search - send array, DON'T complete room
		_sendToSearch()
	else:
		# No linked search - complete room now
		Global.submitScore()
		roomTaskCompleted.emit(objectID)
	Analytics.recordComplete(objectID)
	AudioManager.playSFX("task_complete")

func _applyPivot(index: int):
	if pivotIndex >= 0 and pivotIndex < cardNodes.size():
		cardNodes[pivotIndex].get_child(0).remove_theme_color_override("font_color")
	pivotIndex = index
	if index >= 0 and index < cardNodes.size():
		cardNodes[index].get_child(0).add_theme_color_override("font_color", Color.ORANGE)

func _animateSwap(i: int, j: int):
	var totalWidth = dataNodes.size() * (cardWidth + cardGap) - cardGap
	var startX = -totalWidth / 2.0

	var cardA = cardNodes[i]
	var cardB = cardNodes[j]

	var posA = Vector2(startX + i * (cardWidth + cardGap), cardA.position.y)
	var posB = Vector2(startX + j * (cardWidth + cardGap), cardB.position.y)

	cardA.get_child(0).add_theme_color_override("font_color", Color.CYAN)
	cardB.get_child(0).add_theme_color_override("font_color", Color.CYAN)
	cardA.z_index = 1
	cardB.z_index = 1

	var tween = createTrackedTween()
	tween.set_parallel(true)
	tween.tween_property(cardA, "position", Vector2(posB.x, cardA.position.y), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cardB, "position", Vector2(posA.x, cardB.position.y), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(false)

	tween.tween_callback(func():
		if not is_instance_valid(cardA) or not is_instance_valid(cardB):
			return
		var temp = cardNodes[i]
		cardNodes[i] = cardNodes[j]
		cardNodes[j] = temp
		cardNodes[i].get_child(0).text = "%s\n%d" % [dataNodes[i]["name"], dataNodes[i]["value"]]
		cardNodes[j].get_child(0).text = "%s\n%d" % [dataNodes[j]["name"], dataNodes[j]["value"]]
		cardNodes[i].z_index = 0
		cardNodes[j].z_index = 0
		if i != pivotIndex:
			cardNodes[i].get_child(0).remove_theme_color_override("font_color")
		if j != pivotIndex:
			cardNodes[j].get_child(0).remove_theme_color_override("font_color")
		await get_tree().create_timer(0.05).timeout
		_playNextSwap()
	)
	
	AudioManager.playSFX("swap")

func _animateMove(fromIndex: int, toIndex: int):
	var totalWidth = dataNodes.size() * (cardWidth + cardGap) - cardGap
	var startX = -totalWidth / 2.0

	var movedNode = dataNodes[fromIndex]
	var movedCard = cardNodes[fromIndex]
	dataNodes.remove_at(fromIndex)
	dataNodes.insert(toIndex, movedNode)
	cardNodes.remove_at(fromIndex)
	cardNodes.insert(toIndex, movedCard)

	movedCard.z_index = 1
	movedCard.get_child(0).add_theme_color_override("font_color", Color.CYAN)

	var tween = createTrackedTween()
	tween.set_parallel(true)
	for i in range(cardNodes.size()):
		var destX = startX + i * (cardWidth + cardGap)
		tween.tween_property(cardNodes[i], "position:x", destX, 0.25)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(false)

	tween.tween_callback(func():
		if not is_instance_valid(movedCard):
			return
		movedCard.z_index = 0
		movedCard.get_child(0).remove_theme_color_override("font_color")
		for i in range(cardNodes.size()):
			cardNodes[i].get_child(0).text = "%s\n%d" % [dataNodes[i]["name"], dataNodes[i]["value"]]
		await get_tree().create_timer(0.05).timeout
		_playNextSwap()
	)
	
	AudioManager.playSFX("swap")

func _sendToSearch():
	if linkedSearchObject == null:
		return

	var sprite = linkedSearchObject.visual
	var spriteSize = sprite.texture.get_size() * sprite.scale
	var spritePos = sprite.global_position
	if sprite.centered:
		spritePos -= spriteSize / 2.0
	var targetPos = spritePos + spriteSize / 2.0
	
	var tween = createTrackedTween()
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
		linkedSearchObject.receiveArray(dataNodes.duplicate(true))
		print("[" + objectID + "] Sorted array sent to search. Room NOT complete yet.")
	)
	
	hasSentToSearch = true
	AudioManager.playSFX("swap")
	
func getBaseGuide() -> String:
	return """[b]Available Data:[/b]

[code]array[/code]
A list of integers representing the current values to be sorted.
Example: [3, 1, 4, 1, 5]

[b]Available Functions:[/b]

[code]swap(i, j)[/code]
Swaps the elements at index i and j in the array and triggers the swap animation.

[code]move(fromIndex, toIndex)[/code]
Removes the element at fromIndex and inserts it at toIndex. Useful for insertion sort.

[code]setPivot(index)[/code]
Highlights the element at index as the current pivot (shown in orange).

[code]showSplit(start, mid, end)[/code]
Visually splits the array into two halves: [start, mid) in cyan and [mid, end) in orange.

[code]commitSort()[/code]
Call once the array is fully sorted. Confirms the final order and ends the animation."""

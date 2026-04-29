class_name SortObject # Sort Object Script
extends InteractableObject
# Implements the sorting algorithm visualisation task
# The player writes a Python sorting algorithm that calls swap(), move(), setPivot(), showSplit(), and commitSort().
# Each call is queued and animated in sequence
# If a SearchObject exists in the same room, the sorted array is passed to it on completion

var swapQueue: Array = []     # Queue of pending animation steps (swaps, moves, pivots, splits)
var isAnimating: bool = false
var pivotIndex: int = -1      # Index of the current pivot element (highlighted in orange)
var hasSentToSearch: bool = false  # Prevents the display from being rebuilt after handoff

var linkedSearchObject: SearchObject = null  # Populated at ready if a SearchObject is in the room

### Setup

func _ready():
	super._ready()
	# Scan siblings for a SearchObject to chain into after sorting completes
	await get_tree().process_frame
	for node in get_parent().get_children():
		if node is SearchObject:
			linkedSearchObject = node
			break

func _init_object():
	# Generate 10 random values for the player to sort
	for i in range(10):
		dataNodes.append({
			"name": "node%d" % i,
			"value": randi_range(1, 10)
		})
	initialDataNodes = dataNodes.duplicate(true)
	_buildDisplay()

func _buildDisplay():
	if hasSentToSearch:
		return  # Don't rebuild once the array has been handed off
	super._buildDisplay()

func resetDisplay():
	if hasSentToSearch:
		return
	swapQueue.clear()
	isAnimating = false
	pivotIndex = -1
	hasSentToSearch = false
	super.resetDisplay()

### Python Bridge (called via talk() in IDE.gd)

func queueSwap(i: int, j: int):
	swapQueue.append({"type": "swap", "i": i, "j": j})

func queuePivot(index: int):
	swapQueue.append({"type": "pivot", "index": index})

func queueMove(fromIndex: int, toIndex: int):
	swapQueue.append({"type": "move", "from": fromIndex, "to": toIndex})

func queueHighlightSplit(start: int, mid: int, end: int):
	swapQueue.append({"type": "split", "start": start, "mid": mid, "end": end})

func commitSort():
	# Begins draining the animation queue, called from the player's script typically when it finishes
	if not isAnimating:
		isAnimating = true
		_playNextSwap()

### Animation

func _playNextSwap():
	# Recursively processes one step from the queue, then schedules the next
	if swapQueue.is_empty():
		isAnimating = false
		_applyPivot(-1)  # Clear any lingering pivot highlight
		for i in range(cardNodes.size()):
			cardNodes[i].get_child(0).remove_theme_color_override("font_color")

		# Animate all cards back to their baseline Y before verifying
		var tween = createTrackedTween()
		tween.set_parallel(true)
		for i in range(cardNodes.size()):
			var baseY = 2.0 * cardHeight - cardNodes[i].size.y
			tween.tween_property(cardNodes[i], "position:y", baseY, 0.2)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween.tween_callback(func():
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
		# Raise and colour two sub-array halves to visualise a divide step (e.g. merge sort)
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
		tween.tween_callback(func(): _playNextSwap())

### Verification

func _isSorted() -> bool:
	# Checks whether dataNodes is in ascending order by value
	for i in range(dataNodes.size() - 1):
		if dataNodes[i]["value"] > dataNodes[i + 1]["value"]:
			return false
	return true

func verifyAndComplete():
	# Validates the sort, on success either chains into SearchObject or completes the room
	if not _isSorted():
		AudioManager.playSFX("error")
		return

	if linkedSearchObject != null:
		# Pass sorted array to the linked SearchObject instead of completing immediately
		_sendToSearch()
	else:
		Global.submitScore()
		roomTaskCompleted.emit(objectID)
	Analytics.recordComplete(objectID)
	AudioManager.playSFX("task_complete")

### Animation Helpers

func _applyPivot(index: int):
	# Updates the pivot highlight, clears the previous card, highlights the new one
	if pivotIndex >= 0 and pivotIndex < cardNodes.size():
		cardNodes[pivotIndex].get_child(0).remove_theme_color_override("font_color")
	pivotIndex = index
	if index >= 0 and index < cardNodes.size():
		cardNodes[index].get_child(0).add_theme_color_override("font_color", Color.ORANGE)

func _animateSwap(i: int, j: int):
	# Slides cards at index i and j to each other's positions, then updates labels
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
	# Removes a card from its position and reflows all cards to their new targets
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
	# Animates all cards flying to the SearchObject's sprite, then hands off the sorted array
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
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(i * 0.05)
	tween.set_parallel(false)
	tween.tween_callback(func():
		for child in nodeDisplay.get_children():
			child.queue_free()
		cardNodes.clear()
		linkedSearchObject.receiveArray(dataNodes.duplicate(true))
	)
	hasSentToSearch = true
	AudioManager.playSFX("swap")

### Preamble & Guide

func getPreambleFunctions() -> String:
	# Python helpers injected before the player's code
	# Swaps and moves update the local array mirror so the player's algorithm can reference array indices correctly
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

class_name KnapsackObject # Knapsack Object Script
extends InteractableObject
# Implements the 0/1 knapsack dynamic programming visualisation task
# A DP grid is displayed showing items vs. available weight capacity
# The player fills cells via setCell(), marks taken/skipped items, and calls
# commitKnapsack() with their final item selection to verify the solution

@export var capacity: int = 10  # Maximum weight the knapsack can hold
var items: Array = []           # List of {name, weight, value} dicts generated at init

var cellNodes: Array = []    # 2D array of PanelContainers for the DP grid cells
var itemShapes: Array = []   # Visual representations of each item on the left panel
var fillQueue: Array = []    # Sequential animation steps to process
var isFilling: bool = false

const CELL_W = 52
const CELL_H = 44
const GRID_OFFSET_X = 260   # X offset to the DP grid, leaving room for item shapes
const GRID_OFFSET_Y = 40

# Distinct colours for each item row in the grid
const ITEM_COLORS = [
	Color(0.85, 0.35, 0.35),
	Color(0.35, 0.65, 0.85),
	Color(0.45, 0.8, 0.45),
	Color(0.85, 0.65, 0.2),
	Color(0.7, 0.4, 0.85)
]

### Setup

func _init_object():
	items = []
	for i in range(5):
		items.append({
			"name": "item%d" % i,
			"weight": randi_range(1, 4),
			"value": randi_range(1, 10)
		})
	initialDataNodes = items.duplicate(true)
	_buildDisplay()

func _buildDisplay():
	for child in nodeDisplay.get_children():
		child.queue_free()
	cellNodes.clear()
	itemShapes.clear()
	fillQueue.clear()
	isFilling = false

	var rows = items.size() + 1
	var cols = capacity + 1
	var totalH = max(rows * CELL_H + GRID_OFFSET_Y + 60, items.size() * 70 + 80)
	nodeDisplay.size = Vector2(GRID_OFFSET_X + cols * CELL_W + 20, totalH)

	var bg = ColorRect.new()
	bg.color = Color(0.3, 0.3, 0.3, 0.6)
	bg.size = nodeDisplay.size
	nodeDisplay.add_child(bg)
	bg.z_index = -1

	_buildItemShapes()
	_buildGrid(rows, cols)
	_buildKnapsackBar()

func _buildItemShapes():
	# Draws item rectangles on the left panel where width scales with item weight
	var title = Label.new()
	title.text = "Items"
	title.position = Vector2(0, 8)
	title.size = Vector2(GRID_OFFSET_X - 20, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	nodeDisplay.add_child(title)

	for i in range(items.size()):
		var item = items[i]
		var color = ITEM_COLORS[i % ITEM_COLORS.size()]
		var shapeW = item["weight"] * (CELL_W - 4)
		var shapeH = 52
		var y = 36 + i * (shapeH + 12)
		var shape = PanelContainer.new()
		shape.size = Vector2(shapeW, shapeH)
		shape.position = Vector2(10, y)
		shape.add_theme_stylebox_override("panel", _makeRoundedStyle(color.darkened(0.3), color, 8, 3))

		var vbox = VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 0)
		var nameLabel = Label.new()
		nameLabel.text = item["name"]
		nameLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameLabel.add_theme_font_size_override("font_size", 10)
		nameLabel.add_theme_color_override("font_color", Color.WHITE)
		var statLabel = Label.new()
		statLabel.text = "w:%d v:%d" % [item["weight"], item["value"]]
		statLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		statLabel.add_theme_font_size_override("font_size", 10)
		statLabel.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		vbox.add_child(nameLabel)
		vbox.add_child(statLabel)
		shape.add_child(vbox)
		nodeDisplay.add_child(shape)
		itemShapes.append(shape)

func _buildGrid(rows: int, cols: int):
	# Creates the DP table header row (capacity values) and each item's row of cells
	var axisTitle = Label.new()
	axisTitle.text = "Weight Available"
	axisTitle.position = Vector2(GRID_OFFSET_X, GRID_OFFSET_Y - 44)
	axisTitle.size = Vector2(cols * CELL_W, 20)
	axisTitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	axisTitle.add_theme_font_size_override("font_size", 12)
	axisTitle.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	nodeDisplay.add_child(axisTitle)

	for c in range(cols):
		var hdr = Label.new()
		hdr.text = str(c)
		hdr.position = Vector2(GRID_OFFSET_X + c * CELL_W, GRID_OFFSET_Y - 22)
		hdr.size = Vector2(CELL_W, 20)
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_theme_font_size_override("font_size", 11)
		hdr.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		nodeDisplay.add_child(hdr)

	# Row 0 is the baseline (empty knapsack), display starts from row 1
	for r in range(1, rows):
		var hdr = Label.new()
		hdr.text = items[r - 1]["name"]
		hdr.position = Vector2(GRID_OFFSET_X - 58, GRID_OFFSET_Y + (r - 1) * CELL_H + 10)
		hdr.size = Vector2(54, 22)
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hdr.add_theme_font_size_override("font_size", 10)
		hdr.add_theme_color_override("font_color", ITEM_COLORS[(r - 1) % ITEM_COLORS.size()])
		nodeDisplay.add_child(hdr)

		var row = []
		for c in range(cols):
			var cell = PanelContainer.new()
			cell.size = Vector2(CELL_W - 3, CELL_H - 3)
			cell.position = Vector2(GRID_OFFSET_X + c * CELL_W + 1, GRID_OFFSET_Y + (r - 1) * CELL_H + 1)
			cell.add_theme_stylebox_override("panel", _makeRoundedStyle(Color(0.82, 0.82, 0.82), Color(0.65, 0.65, 0.65), 6, 1))
			var label = Label.new()
			label.text = ""
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
			cell.add_child(label)
			nodeDisplay.add_child(cell)
			row.append(cell)
		cellNodes.append(row)

func _makeRoundedStyle(bg: Color, border: Color, radius: int, borderWidth: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	for corner in ["corner_radius_top_left", "corner_radius_top_right",
				   "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		style.set(corner, radius)
	style.border_width_left = borderWidth; style.border_width_right = borderWidth
	style.border_width_top = borderWidth; style.border_width_bottom = borderWidth
	style.border_color = border
	return style

### Animation System
# Each step type has a distinct visual treatment, an animGeneration counter ensures
# stale steps from a previous run are discarded on reset.

var animGeneration := 0
var slotNodes: Array = []       # PanelContainers forming the knapsack bar slots
var slotOffsetMap: Dictionary = {}  # Maps item index -> starting slot index in the bar

func resetDisplay():
	fillQueue.clear()
	isFilling = false
	animGeneration += 1  # Invalidate all in-progress animations
	slotOffsetMap.clear()
	items = initialDataNodes.duplicate(true)
	super.resetDisplay()

func _buildKnapsackBar():
	# Draws a row of empty slots at the bottom representing the knapsack's capacity
	slotNodes.clear()
	var rows = items.size()
	var barY = GRID_OFFSET_Y + rows * CELL_H + 16

	var barLabel = Label.new()
	barLabel.text = "Knapsack (cap: %d)" % capacity
	barLabel.position = Vector2(GRID_OFFSET_X, barY - 20)
	barLabel.size = Vector2(capacity * CELL_W, 18)
	barLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	barLabel.add_theme_font_size_override("font_size", 11)
	barLabel.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	nodeDisplay.add_child(barLabel)

	for c in range(capacity):
		var slot = PanelContainer.new()
		slot.size = Vector2(CELL_W - 3, CELL_H + 8)
		slot.position = Vector2(GRID_OFFSET_X + c * CELL_W + 1, barY)
		slot.add_theme_stylebox_override("panel", _makeRoundedStyle(Color(0.78, 0.78, 0.78), Color(0.6, 0.6, 0.6), 8, 1))
		nodeDisplay.add_child(slot)
		slotNodes.append(slot)

func _playNextFill():
	# Processes one animation step and schedules itself recursively
	if fillQueue.is_empty():
		isFilling = false
		return
	var step = fillQueue.pop_front()
	var gen = step.get("gen", 0)
	if gen != animGeneration:  # Skip steps from before the last reset
		_playNextFill()
		return

	var cell = cellNodes[step["row"]][step["col"]]
	var rowColor = ITEM_COLORS[(step["row"]) % ITEM_COLORS.size()]

	if step["type"] == "fill":
		# Flash cell bright then settle to item colour
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(rowColor.lightened(0.5), rowColor, 6, 2))
		cell.get_child(0).text = str(step["value"])
		await get_tree().create_timer(0.05).timeout
		if animGeneration != gen: return
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(rowColor.lightened(0.35), rowColor, 6, 2))
		await get_tree().create_timer(0.04).timeout

	elif step["type"] == "backtrack":
		# Briefly highlight white to show re-examination
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(Color(0.95, 0.95, 0.95), Color.WHITE, 6, 3))
		await get_tree().create_timer(0.18).timeout
		if animGeneration != gen: return
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(rowColor.lightened(0.35), rowColor, 6, 2))
		await get_tree().create_timer(0.05).timeout

	elif step["type"] == "taken":
		# Highlight green and animate the item shape flying into the knapsack bar slots
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(Color(0.2, 0.7, 0.3), Color(0.4, 0.9, 0.5), 6, 3))
		AudioManager.playSFX("swap")
		var idx = step["row"]
		if idx >= 0 and idx < itemShapes.size() and idx in slotOffsetMap:
			var item = items[idx]
			var color = ITEM_COLORS[idx % ITEM_COLORS.size()]
			var capturedOffset = slotOffsetMap[idx]
			var capturedGen = gen
			itemShapes[idx].add_theme_stylebox_override("panel", _makeRoundedStyle(color, Color.WHITE, 8, 3))
			var sourcePos = itemShapes[idx].global_position
			var rows = items.size()
			var barY = GRID_OFFSET_Y + rows * CELL_H + 16
			var targetX = nodeDisplay.global_position.x + GRID_OFFSET_X + capturedOffset * CELL_W + 1
			var targetY = nodeDisplay.global_position.y + barY
			# Create a flying copy that travels from the item shape to its bar slot
			var copy = PanelContainer.new()
			copy.size = Vector2(item["weight"] * (CELL_W - 4), 52)
			copy.global_position = sourcePos
			copy.add_theme_stylebox_override("panel", _makeRoundedStyle(color.darkened(0.2), color, 8, 2))
			var copyLabel = Label.new()
			copyLabel.text = "w:%d v:%d" % [item["weight"], item["value"]]
			copyLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			copyLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			copyLabel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			copyLabel.add_theme_font_size_override("font_size", 10)
			copyLabel.add_theme_color_override("font_color", Color.WHITE)
			copy.add_child(copyLabel)
			get_tree().current_scene.add_child(copy)
			var tween = create_tween()
			tween.tween_property(copy, "global_position", Vector2(targetX, targetY), 0.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_callback(func():
				copy.queue_free()
				if capturedGen != animGeneration: return
				# Fill the bar slots this item occupies
				for w in range(item["weight"]):
					var slotIdx = capturedOffset + w
					if slotIdx < slotNodes.size():
						slotNodes[slotIdx].add_theme_stylebox_override("panel",
							_makeRoundedStyle(color.darkened(0.1), color, 8, 2))
						var slotLabel = Label.new()
						slotLabel.text = item["name"] if w == 0 else ""
						slotLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						slotLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
						slotLabel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
						slotLabel.add_theme_font_size_override("font_size", 9)
						slotLabel.add_theme_color_override("font_color", Color.WHITE)
						slotNodes[slotIdx].add_child(slotLabel)
			)
		await get_tree().create_timer(0.5).timeout

	elif step["type"] == "skipped":
		# Red tint indicates the item was not selected at this capacity
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(Color(0.5, 0.2, 0.2), Color(0.7, 0.3, 0.3), 6, 2))
		await get_tree().create_timer(0.18).timeout

	if animGeneration != gen: return
	_playNextFill()

### Bridge Methods

func queueCellFill(row: int, col: int, value: int):
	fillQueue.append({"type": "fill", "row": row, "col": col, "value": value, "gen": animGeneration})
	if not isFilling:
		isFilling = true
		_playNextFill()

func queueBacktrack(row: int, col: int):
	fillQueue.append({"type": "backtrack", "row": row, "col": col, "gen": animGeneration})
	if not isFilling:
		isFilling = true
		_playNextFill()

func queueTaken(row: int, col: int):
	fillQueue.append({"type": "taken", "row": row, "col": col, "gen": animGeneration})
	if not isFilling:
		isFilling = true
		_playNextFill()

func queueSkipped(row: int, col: int):
	fillQueue.append({"type": "skipped", "row": row, "col": col, "gen": animGeneration})
	if not isFilling:
		isFilling = true
		_playNextFill()

### Verification

func commitKnapsack(selectedIndices: Array):
	# Validates the selection does not exceed capacity, then emits the completion signal
	slotOffsetMap.clear()
	if selectedIndices.is_empty():
		AudioManager.playSFX("error")
		return
	var totalWeight = 0
	for idx in selectedIndices:
		if idx < items.size():
			totalWeight += items[idx]["weight"]
	if totalWeight > capacity:
		AudioManager.playSFX("error")
		return
	# Build slot offset map so taken animations know where to fly each item
	var offset = 0
	for idx in selectedIndices:
		if idx < items.size():
			slotOffsetMap[idx] = offset
			offset += items[idx]["weight"]
	roomTaskCompleted.emit(objectID)
	Analytics.recordComplete(objectID)
	AudioManager.playSFX("task_complete")

### Preamble & Guide

func getPreambleFunctions() -> String:
	var itemsStr = "["
	for item in items:
		itemsStr += '{"name": "%s", "weight": %d, "value": %d},' \
			% [item["name"], item["weight"], item["value"]]
	itemsStr += "]"
	return """
items = %s
capacity = %d

def setCell(row, col, value):
	talk("__cell__:" + str(row - 1) + ":" + str(col) + ":" + str(value))

def backtrackCell(row, col):
	talk("__backtrack__:" + str(row - 1) + ":" + str(col))

def takenCell(row, col):
	talk("__taken__:" + str(row - 1) + ":" + str(col))

def skippedCell(row, col):
	talk("__skipped__:" + str(row - 1) + ":" + str(col))

def commitKnapsack(selectedItems):
	talk("__knapsack__:" + ",".join(str(i) for i in selectedItems))
""" % [itemsStr, capacity]

func getBaseGuide() -> String:
	return """[b]Available Data:[/b]

[code]items[/code]
A list of dictionaries, each with keys: "name", "weight", and "value".
Example: [{"name": "item0", "weight": 2, "value": 6}, ...]

[code]capacity[/code]
The maximum total weight the knapsack can hold.

[b]Available Functions:[/b]

[code]setCell(row, col, value)[/code]
Fills a cell in the DP grid at (row, col) with the given integer value.
Row corresponds to the item index (1-based), col to the weight available.

[code]backtrackCell(row, col)[/code]
Briefly highlights a cell during backtracking to show it is being re-examined.

[code]takenCell(row, col)[/code]
Marks a cell as one where the item was taken. Triggers the item flight animation into the knapsack bar.

[code]skippedCell(row, col)[/code]
Marks a cell as one where the item was skipped (not included at this capacity).

[code]commitKnapsack(selectedItems)[/code]
Accepts a list of item indices representing the final selection.
Call this after filling the DP table to animate items into their knapsack slots."""

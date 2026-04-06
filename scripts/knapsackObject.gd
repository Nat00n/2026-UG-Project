class_name KnapsackObject
extends InteractableObject

@export var capacity: int = 10
var items: Array = []

var cellNodes: Array = []
var itemShapes: Array = []
var fillQueue: Array = []
var isFilling: bool = false

const CELL_W = 52
const CELL_H = 44
const GRID_OFFSET_X = 220
const GRID_OFFSET_Y = 60
const ITEM_COLORS = [
	Color(0.85, 0.35, 0.35),
	Color(0.35, 0.65, 0.85),
	Color(0.45, 0.8, 0.45),
	Color(0.85, 0.65, 0.2),
	Color(0.7, 0.4, 0.85),
	Color(0.85, 0.6, 0.35)
]

func _init_object():
	items = []
	for i in range(5):
		items.append({
			"name": "item%d" % i,
			"weight": randi_range(1, 4),
			"value": randi_range(1, 10)
		})
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

	_buildItemShapes()
	_buildGrid(rows, cols)
	_buildKnapsackBar()

func _buildItemShapes():
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

		# Width scales with weight, height is fixed
		var shapeW = item["weight"] * (CELL_W - 4)
		var shapeH = 52
		var y = 36 + i * (shapeH + 12)

		var shape = PanelContainer.new()
		shape.size = Vector2(shapeW, shapeH)
		shape.position = Vector2(10, y)

		var style = _makeRoundedStyle(color.darkened(0.3), color, 8, 3)
		shape.add_theme_stylebox_override("panel", style)

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
	# X axis title
	var axisTitle = Label.new()
	axisTitle.text = "Weight Available"
	axisTitle.position = Vector2(GRID_OFFSET_X, GRID_OFFSET_Y - 44)
	axisTitle.size = Vector2(cols * CELL_W, 20)
	axisTitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	axisTitle.add_theme_font_size_override("font_size", 12)
	axisTitle.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	nodeDisplay.add_child(axisTitle)

	# Capacity column headers
	for c in range(cols):
		var hdr = Label.new()
		hdr.text = str(c)
		hdr.position = Vector2(GRID_OFFSET_X + c * CELL_W, GRID_OFFSET_Y - 22)
		hdr.size = Vector2(CELL_W, 20)
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_theme_font_size_override("font_size", 11)
		hdr.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		nodeDisplay.add_child(hdr)

	# Row headers and cells — start from row 1, skip the blank row 0
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

			var style = _makeRoundedStyle(Color(0.82, 0.82, 0.82), Color(0.65, 0.65, 0.65), 6, 1)
			cell.add_theme_stylebox_override("panel", style)

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

func _buildKnapsackBar():
	var rows = items.size() + 1
	var barY = GRID_OFFSET_Y + rows * CELL_H + 16

	var barLabel = Label.new()
	barLabel.text = "Knapsack (cap: %d)" % capacity
	barLabel.position = Vector2(GRID_OFFSET_X, barY - 20)
	barLabel.size = Vector2(capacity * CELL_W, 18)
	barLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	barLabel.add_theme_font_size_override("font_size", 11)
	barLabel.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	nodeDisplay.add_child(barLabel)

	# Empty slot cells for the knapsack bar
	for c in range(capacity):
		var slot = PanelContainer.new()
		slot.name = "slot_%d" % c
		slot.size = Vector2(CELL_W - 3, CELL_H + 8)
		slot.position = Vector2(GRID_OFFSET_X + c * CELL_W + 1, barY)
		var style = _makeRoundedStyle(Color(0.78, 0.78, 0.78), Color(0.6, 0.6, 0.6), 8, 1)
		slot.add_theme_stylebox_override("panel", style)
		nodeDisplay.add_child(slot)

func _makeRoundedStyle(bg: Color, border: Color, radius: int, borderWidth: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = borderWidth
	style.border_width_right = borderWidth
	style.border_width_top = borderWidth
	style.border_width_bottom = borderWidth
	style.border_color = border
	return style

func queueCellFill(row: int, col: int, value: int):
	fillQueue.append({"type": "fill", "row": row, "col": col, "value": value})
	if not isFilling:
		isFilling = true
		_playNextFill()

func queueBacktrack(row: int, col: int):
	fillQueue.append({"type": "backtrack", "row": row, "col": col})
	if not isFilling:
		isFilling = true
		_playNextFill()

func queueTaken(row: int, col: int):
	fillQueue.append({"type": "taken", "row": row, "col": col})
	if not isFilling:
		isFilling = true
		_playNextFill()

func queueSkipped(row: int, col: int):
	fillQueue.append({"type": "skipped", "row": row, "col": col})
	if not isFilling:
		isFilling = true
		_playNextFill()

func _playNextFill():
	if fillQueue.is_empty():
		isFilling = false
		return

	var step = fillQueue.pop_front()
	var cell = cellNodes[step["row"]][step["col"]]
	var rowColor = ITEM_COLORS[(step["row"] - 1) % ITEM_COLORS.size()] if step["row"] > 0 else Color(0.5, 0.75, 0.9)

	if step["type"] == "fill":
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(
			rowColor.lightened(0.5), rowColor, 6, 2))
		cell.get_child(0).text = str(step["value"])
		await get_tree().create_timer(0.05).timeout
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(
			rowColor.lightened(0.35), rowColor, 6, 2))
		await get_tree().create_timer(0.04).timeout

	elif step["type"] == "backtrack":
		# White pulsing cursor showing where we are in the traceback
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(
			Color(0.95, 0.95, 0.95), Color.WHITE, 6, 3))
		await get_tree().create_timer(0.18).timeout
		# Restore to filled colour
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(
			rowColor.lightened(0.35), rowColor, 6, 2))
		await get_tree().create_timer(0.05).timeout

	elif step["type"] == "taken":
		# Green — this item was selected
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(
			Color(0.2, 0.7, 0.3), Color(0.4, 0.9, 0.5), 6, 3))
		# Also highlight the item shape on the left
		if step["row"] > 0:
			var idx = step["row"] - 1
			itemShapes[idx].add_theme_stylebox_override("panel",
				_makeRoundedStyle(ITEM_COLORS[idx % ITEM_COLORS.size()], Color.WHITE, 8, 3))
		await get_tree().create_timer(0.25).timeout

	elif step["type"] == "skipped":
		# Dim red — this item was not selected
		cell.add_theme_stylebox_override("panel", _makeRoundedStyle(
			Color(0.5, 0.2, 0.2), Color(0.7, 0.3, 0.3), 6, 2))
		await get_tree().create_timer(0.18).timeout

	_playNextFill()

func commitKnapsack(selectedIndices: Array):
	var rows = items.size() + 1
	var barY = GRID_OFFSET_Y + rows * CELL_H + 16
	var slotOffset = 0

	for idx in selectedIndices:
		if idx >= items.size():
			continue

		var item = items[idx]
		var color = ITEM_COLORS[idx % ITEM_COLORS.size()]

		# Highlight item shape
		itemShapes[idx].add_theme_stylebox_override("panel",
			_makeRoundedStyle(color, Color.WHITE, 8, 3))

		# Animate item shape flying into knapsack bar
		var sourcePos = itemShapes[idx].global_position
		var targetX = GRID_OFFSET_X + slotOffset * CELL_W + 1
		var targetY = nodeDisplay.global_position.y + barY

		# Create a flying copy
		var copy = PanelContainer.new()
		var shapeW = item["weight"] * (CELL_W - 4)
		copy.size = Vector2(shapeW, 52)
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
		tween.tween_property(copy, "global_position",
			Vector2(nodeDisplay.global_position.x + targetX, targetY), 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)\
			.set_delay(selectedIndices.find(idx) * 0.2)

		tween.tween_callback(func():
			copy.queue_free()
			# Fill the bar slots with item colour
			for w in range(item["weight"]):
				var slotName = "slot_%d" % (slotOffset + w)
				var slot = nodeDisplay.find_child(slotName, false, false)
				if slot:
					slot.add_theme_stylebox_override("panel",
						_makeRoundedStyle(color.darkened(0.1), color, 8, 2))
					var slotLabel = Label.new()
					slotLabel.text = item["name"] if w == 0 else ""
					slotLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					slotLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					slotLabel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
					slotLabel.add_theme_font_size_override("font_size", 9)
					slotLabel.add_theme_color_override("font_color", Color.WHITE)
					slot.add_child(slotLabel)
		)

		slotOffset += item["weight"]

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

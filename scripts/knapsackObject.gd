class_name KnapsackObject
extends InteractableObject

@export var capacity: int = 10
var items: Array = []
# Each: {name, weight, value}

var cellNodes: Array = []  # 2D: cellNodes[row][col]
const CELL_W = 52
const CELL_H = 40

func _init_object():
	items = []
	for i in range(6):
		items.append({
			"name": "item%d" % i,
			"weight": randi_range(1, 5),
			"value": randi_range(1, 10)
		})
	_buildGrid()

func _buildGrid():
	for child in nodeDisplay.get_children():
		child.queue_free()
	cellNodes.clear()

	var rows = items.size() + 1
	var cols = capacity + 1

	nodeDisplay.size = Vector2(cols * CELL_W, rows * CELL_H)

	for r in range(rows):
		var row = []
		for c in range(cols):
			var cell = PanelContainer.new()
			cell.size = Vector2(CELL_W, CELL_H)
			cell.position = Vector2(c * CELL_W, r * CELL_H)

			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.15, 0.25)
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.3, 0.3, 0.3)
			cell.add_theme_stylebox_override("panel", style)

			var label = Label.new()
			label.text = "0" if r == 0 or c == 0 else ""
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			label.add_theme_font_size_override("font_size", 11)
			cell.add_child(label)
			nodeDisplay.add_child(cell)
			row.append(cell)
		cellNodes.append(row)

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
    talk("__cell__:" + str(row) + ":" + str(col) + ":" + str(value))

def highlightCell(row, col):
    talk("__highlight__:" + str(row) + ":" + str(col))

def commitKnapsack(selectedItems):
    talk("__knapsack__:" + ",".join(str(i) for i in selectedItems))
""" % [itemsStr, capacity]

func setCell(row: int, col: int, value: int):
	if row >= cellNodes.size() or col >= cellNodes[row].size():
		return
	var cell = cellNodes[row][col]
	cell.get_child(0).text = str(value)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.35, 0.5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.3)
	cell.add_theme_stylebox_override("panel", style)

func highlightCell(row: int, col: int):
	if row >= cellNodes.size() or col >= cellNodes[row].size():
		return
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.4, 0.1)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.9, 0.6, 0.1)
	cellNodes[row][col].add_theme_stylebox_override("panel", style)

func commitKnapsack(selectedIndices: Array):
	for idx in selectedIndices:
		if idx < items.size():
			var label = cellNodes[idx + 1][0].get_child(0)
			label.add_theme_color_override("font_color", Color.YELLOW)

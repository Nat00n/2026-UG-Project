class_name GraphObject
extends InteractableObject

@export var nodeCount: int = 30
@export var startNodeId: int = 0
@export var goalNodeId: int = randi_range(22,30)

var graphNodes: Array = []
# Each: {id, pos, neighbours: [{id, weight}]}

var nodeCircles: Array = []
var edgeLines: Dictionary = {}
var weightLabels: Dictionary = {}
var visitQueue: Array = []
var pendingPath: Array = []
var isAnimating: bool = false

const NODE_RADIUS = 22
const GRAPH_WIDTH = 1260
const GRAPH_HEIGHT = 840
const MAX_NEIGHBOURS = 4

func _init_object():
	_generateGraph()
	_buildGraphDisplay()

func _generateGraph():
	graphNodes.clear()
	var positions: Array = []
	var attempts = 0

	while positions.size() < nodeCount and attempts < 1000:
		var pos = Vector2(
			randf_range(NODE_RADIUS + 20, GRAPH_WIDTH - NODE_RADIUS - 20),
			randf_range(NODE_RADIUS + 20, GRAPH_HEIGHT - NODE_RADIUS - 20)
		)
		var valid = true
		for existing in positions:
			if pos.distance_to(existing) < NODE_RADIUS * 3.5:
				valid = false
				break
		if valid:
			positions.append(pos)
		attempts += 1

	nodeCount = positions.size()

	for i in range(nodeCount):
		graphNodes.append({
			"id": i,
			"pos": positions[i],
			"neighbours": []
		})

	# Spanning tree first to guarantee full connectivity
	var connected = [0]
	var unconnected = []
	for i in range(1, nodeCount):
		unconnected.append(i)

	while not unconnected.is_empty():
		# Find the closest connected node to any unconnected node
		var bestFrom = -1
		var bestTo = -1
		var bestDist = INF

		for toId in unconnected:
			for fromId in connected:
				var d = graphNodes[fromId]["pos"].distance_to(graphNodes[toId]["pos"])
				if d < bestDist:
					bestDist = d
					bestFrom = fromId
					bestTo = toId

		_addEdge(bestFrom, bestTo)
		connected.append(bestTo)
		unconnected.erase(bestTo)

	# Add extra nearby edges up to MAX_NEIGHBOURS per node
	# Sort all possible pairs by distance
	var pairs = []
	for i in range(nodeCount):
		for j in range(i + 1, nodeCount):
			if not _hasEdge(i, j):
				var d = graphNodes[i]["pos"].distance_to(graphNodes[j]["pos"])
				pairs.append({"i": i, "j": j, "dist": d})

	pairs.sort_custom(func(a, b): return a["dist"] < b["dist"])

	for pair in pairs:
		var i = pair["i"]
		var j = pair["j"]
		# Only add if both nodes are under the neighbour cap
		if graphNodes[i]["neighbours"].size() < MAX_NEIGHBOURS and \
		   graphNodes[j]["neighbours"].size() < MAX_NEIGHBOURS:
			_addEdge(i, j)

func _addEdge(fromId: int, toId: int):
	var weight = int(graphNodes[fromId]["pos"].distance_to(graphNodes[toId]["pos"]) / 10)
	weight = max(1, weight)
	graphNodes[fromId]["neighbours"].append({"id": toId, "weight": weight})
	graphNodes[toId]["neighbours"].append({"id": fromId, "weight": weight})

func _hasEdge(fromId: int, toId: int) -> bool:
	for n in graphNodes[fromId]["neighbours"]:
		if n["id"] == toId:
			return true
	return false

func _buildGraphDisplay():
	for child in nodeDisplay.get_children():
		child.queue_free()
	nodeCircles.clear()
	edgeLines.clear()
	weightLabels.clear()

	nodeDisplay.size = Vector2(GRAPH_WIDTH, GRAPH_HEIGHT)

	# Draw edges first so nodes appear on top
	for i in range(graphNodes.size()):
		for neighbour in graphNodes[i]["neighbours"]:
			var j = neighbour["id"]
			if i < j:
				var key = "%d_%d" % [i, j]

				var line = Line2D.new()
				line.width = clamp(neighbour["weight"] / 6.0, 1.5, 6.0)
				line.default_color = Color(0.45, 0.45, 0.45)
				line.add_point(graphNodes[i]["pos"])
				line.add_point(graphNodes[j]["pos"])
				nodeDisplay.add_child(line)
				edgeLines[key] = line

				# Weight label at edge midpoint
				var mid = (graphNodes[i]["pos"] + graphNodes[j]["pos"]) / 2.0
				var wLabel = Label.new()
				wLabel.text = str(neighbour["weight"])
				wLabel.position = mid + Vector2(-8, -14)
				wLabel.add_theme_font_size_override("font_size", 11)
				wLabel.add_theme_color_override("font_color", Color.WHITE)
				nodeDisplay.add_child(wLabel)
				weightLabels[key] = wLabel

	# Draw nodes on top
	for i in range(graphNodes.size()):
		var circle = _makeNodeCircle(i)
		circle.position = graphNodes[i]["pos"] - Vector2(NODE_RADIUS, NODE_RADIUS)
		nodeDisplay.add_child(circle)
		nodeCircles.append(circle)

func _makeNodeCircle(id: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
	panel.custom_minimum_size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)

	var style = StyleBoxFlat.new()
	if id == startNodeId:
		style.bg_color = Color(0.2, 0.75, 0.2)
	elif id == goalNodeId:
		style.bg_color = Color(0.8, 0.2, 0.2)
	else:
		style.bg_color = Color(0.25, 0.25, 0.55)

	for corner in ["corner_radius_top_left", "corner_radius_top_right",
				   "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		style.set(corner, NODE_RADIUS)

	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.8, 0.3)

	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = str(id)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 13)
	panel.add_child(label)

	return panel

# --- Python bridge ---

func getPreambleFunctions() -> String:
	var graphStr = "{"
	for node in graphNodes:
		graphStr += "%d: [" % node["id"]
		for n in node["neighbours"]:
			graphStr += "[%d, %d]," % [n["id"], n["weight"]]
		graphStr += "],"
	graphStr += "}"

	return """
graph = %s
startNode = %d
goalNode = %d

def getNeighbours(nodeId):
	# Returns list of [neighbourId, weight]
	return graph.get(nodeId, [])

def visitNode(nodeId):
	talk("__visit__:" + str(nodeId))

def commitPath(path):
	# path is a list of node ids from start to goal
	talk("__path__:" + ",".join(str(n) for n in path))
""" % [graphStr, startNodeId, goalNodeId]

# --- Animation ---

func queueVisit(nodeId: int):
	visitQueue.append(nodeId)
	if not isAnimating:
		isAnimating = true
		_playNextVisit()

func queuePath(pathIds: Array):
	pendingPath = pathIds

func startPathAnimation():
	# Wait for all visit steps to finish, then animate path
	var delay = visitQueue.size() * 0.35 + 0.3
	await get_tree().create_timer(delay).timeout
	_animatePath(pendingPath)

func _playNextVisit():
	if visitQueue.is_empty():
		isAnimating = false
		return

	var nodeId = visitQueue.pop_front()
	_setNodeColor(nodeId, Color(0.15, 0.55, 0.85))  # cyan-blue visited

	await get_tree().create_timer(0.35).timeout
	_playNextVisit()

func _animatePath(pathIds: Array):
	if pathIds.is_empty():
		return

	# Reset non-start/goal nodes to neutral first
	for i in range(nodeCircles.size()):
		if i != startNodeId and i != goalNodeId:
			_setNodeColor(i, Color(0.25, 0.25, 0.55))
	for key in edgeLines:
		edgeLines[key].default_color = Color(0.45, 0.45, 0.45)

	# Animate path nodes and edges one step at a time
	for i in range(pathIds.size()):
		var nodeId = pathIds[i]
		_setNodeColor(nodeId, Color.YELLOW)

		if i > 0:
			var prevId = pathIds[i - 1]
			var key = "%d_%d" % [min(prevId, nodeId), max(prevId, nodeId)]
			if edgeLines.has(key):
				var line = edgeLines[key]
				line.default_color = Color.YELLOW
				line.width += 2.0

		await get_tree().create_timer(0.45).timeout

func _setNodeColor(nodeId: int, color: Color):
	if nodeId < 0 or nodeId >= nodeCircles.size():
		return
	var style = StyleBoxFlat.new()
	style.bg_color = color
	for corner in ["corner_radius_top_left", "corner_radius_top_right",
				   "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		style.set(corner, NODE_RADIUS)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.8, 0.3)
	nodeCircles[nodeId].add_theme_stylebox_override("panel", style)

class_name GraphObject
extends InteractableObject

@export var nodeCount: int = 30
@export var startNodeId: int = 0
@export var goalNodeId: int = randi_range(24,30)

var graphNodes: Array = []
var nodeCircles: Array = []
var edgeLines: Dictionary = {}
var weightLabels: Dictionary = {}

var visitQueue: Array = []
var pendingPath: Array = []
var pathCommitted: bool = false
var totalVisitCount: int = 0
var currentNodeId: int = -1

# _process driven animation — no chained timers
var visitTimer: float = 0.0
var visitDelay: float = 0.35
var isVisiting: bool = false

var pathTimer: float = 0.0
var pathDelay: float = 0.45
var pathIndex: int = -1
var isPathAnimating: bool = false

var waitingForPath: bool = false
var waitTimer: float = 0.0
var waitDuration: float = 0.0

const NODE_RADIUS = 22
const GRAPH_WIDTH = 900
const GRAPH_HEIGHT = 600
const MAX_NEIGHBOURS = 4

func _init_object():
	_generateGraph()
	_buildGraphDisplay()

func resetDisplay():
	visitQueue.clear()
	pendingPath.clear()
	isVisiting = false
	isPathAnimating = false
	waitingForPath = false
	pathCommitted = false
	pathIndex = -1
	currentNodeId = -1
	visitTimer = 0.0
	pathTimer = 0.0
	waitTimer = 0.0
	totalVisitCount = 0
	super.resetDisplay()

func _buildDisplay():
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

	# Spanning tree — always connect to nearest unconnected node
	var connected = [0]
	var unconnected = []
	for i in range(1, nodeCount):
		unconnected.append(i)

	while not unconnected.is_empty():
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

	# Extra nearby edges sorted by distance up to MAX_NEIGHBOURS
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

				var mid = (graphNodes[i]["pos"] + graphNodes[j]["pos"]) / 2.0
				var wLabel = Label.new()
				wLabel.text = str(neighbour["weight"])
				wLabel.position = mid + Vector2(-8, -14)
				wLabel.add_theme_font_size_override("font_size", 11)
				wLabel.add_theme_color_override("font_color", Color.WHITE)
				nodeDisplay.add_child(wLabel)
				weightLabels[key] = wLabel

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

func _setNodeColor(nodeId: int, color: Color):
	if nodeId < 0 or nodeId >= nodeCircles.size():
		return
	if not is_instance_valid(nodeCircles[nodeId]):
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

# --- _process driven animation ---

func _process(delta):
	# Mouse hover
	var mouse = get_global_mouse_position()
	var rect = Rect2(visual.global_position, visual.size)
	var wasHovered = _hovered
	_hovered = rect.has_point(mouse)
	if _hovered != wasHovered:
		hoverLabel.visible = _hovered

	# Visit animation
	if isVisiting and not visitQueue.is_empty():
		visitTimer += delta
		if visitTimer >= visitDelay:
			visitTimer = 0.0
			_stepVisit()
	elif isVisiting and visitQueue.is_empty():
		isVisiting = false

	# Wait before path animation
	if waitingForPath:
		waitTimer += delta
		if waitTimer >= waitDuration:
			waitingForPath = false
			isPathAnimating = true
			pathIndex = 0
			_resetPathColors()

	# Path animation
	if isPathAnimating:
		pathTimer += delta
		if pathTimer >= pathDelay:
			pathTimer = 0.0
			_stepPath()

func _stepVisit():
	if visitQueue.is_empty():
		isVisiting = false
		return
	var nodeId = visitQueue.pop_front()
	if currentNodeId != -1 and currentNodeId != startNodeId and currentNodeId != goalNodeId:
		_setNodeColor(currentNodeId, Color(0.15, 0.55, 0.85))
	currentNodeId = nodeId
	if nodeId != startNodeId and nodeId != goalNodeId:
		_setNodeColor(nodeId, Color(0.95, 0.55, 0.1))

func _resetPathColors():
	for i in range(nodeCircles.size()):
		if i != startNodeId and i != goalNodeId:
			_setNodeColor(i, Color(0.25, 0.25, 0.55))
	for key in edgeLines:
		if is_instance_valid(edgeLines[key]):
			edgeLines[key].default_color = Color(0.45, 0.45, 0.45)

func _stepPath():
	if pathIndex >= pendingPath.size():
		isPathAnimating = false
		return

	var nodeId = pendingPath[pathIndex]
	_setNodeColor(nodeId, Color.YELLOW)

	if pathIndex > 0:
		var prevId = pendingPath[pathIndex - 1]
		var key = "%d_%d" % [min(prevId, nodeId), max(prevId, nodeId)]
		if edgeLines.has(key) and is_instance_valid(edgeLines[key]):
			edgeLines[key].default_color = Color.YELLOW
			edgeLines[key].width += 2.0

	pathIndex += 1

# --- Python bridge ---

func queueVisit(nodeId: int):
	if pathCommitted:
		return
	visitQueue.append(nodeId)
	isVisiting = true

func queuePath(pathIds: Array):
	pendingPath = pathIds
	pathCommitted = true
	totalVisitCount = visitQueue.size()

func startPathAnimation():
	waitDuration = totalVisitCount * visitDelay + 0.5
	waitTimer = 0.0
	waitingForPath = true
	pathCommitted = false

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
	return graph.get(nodeId, [])

def visitNode(nodeId):
	talk("__visit__:" + str(nodeId))

def commitPath(path):
	talk("__path__:" + ",".join(str(n) for n in path))
""" % [graphStr, startNodeId, goalNodeId]

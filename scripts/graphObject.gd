class_name GraphObject # Graph Object Script
extends InteractableObject
# Implements the graph traversal visualisation task
# A random connected graph is procedurally generated each time the object initialises
# The player writes a pathfinding algorithm using visitNode() to animate node exploration,
# and commitPath() to declare the final route from startNode to goalNode

@export var nodeCount: int = 15
@export var startNodeId: int = 0
@export var goalNodeId: int = nodeCount - 1

var graphNodes: Array = []      # Array of dicts: {id, pos (Vector2), neighbours: [{id, weight}]}
var nodeCircles: Array = []     # PanelContainer nodes representing each graph node on screen
var edgeLines: Dictionary = {}  # "i_j" -> Line2D for each undirected edge
var weightLabels: Dictionary = {}

# Visit animation state
var visitQueue: Array = []
var totalVisitCount: int = 0
var currentNodeId: int = -1
var isVisiting: bool = false
var visitTimer: float = 0.0
var visitDelay: float = 0.35

# Path animation state
var pendingPath: Array = []
var pathCommitted: bool = false
var pathIndex: int = -1
var isPathAnimating: bool = false
var pathTimer: float = 0.0
var pathDelay: float = 0.45

# Delay between visit animation finishing and path animation starting
var waitingForPath: bool = false
var waitTimer: float = 0.0
var waitDuration: float = 0.0

const NODE_RADIUS = 22
const GRAPH_WIDTH = 900
const GRAPH_HEIGHT = 450
const MAX_NEIGHBOURS = 4  # Degree cap to keep the graph readable

### Setup

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

### Graph Generation

func _generateGraph():
	# Places nodes on a jittered grid, connects them into a spanning tree (guaranteeing connectivity),
	# then adds short extra edges up to MAX_NEIGHBOURS per node
	graphNodes.clear()
	var cols = int(ceil(sqrt(nodeCount * float(GRAPH_WIDTH) / GRAPH_HEIGHT)))
	var rows = int(ceil(float(nodeCount) / cols))
	var cellW = float(GRAPH_WIDTH) / cols
	var cellH = float(GRAPH_HEIGHT) / rows
	var jitterX = cellW * 0.28
	var jitterY = cellH * 0.28

	var cells = []
	for r in range(rows):
		for c in range(cols):
			cells.append(Vector2(c, r))
	cells.shuffle()

	var positions = []
	for k in range(nodeCount):
		var cell = cells[k]
		var cx = (cell.x + 0.5) * cellW
		var cy = (cell.y + 0.5) * cellH
		positions.append(Vector2(
			clamp(cx + randf_range(-jitterX, jitterX), NODE_RADIUS + 20, GRAPH_WIDTH - NODE_RADIUS - 20),
			clamp(cy + randf_range(-jitterY, jitterY), NODE_RADIUS + 20, GRAPH_HEIGHT - NODE_RADIUS - 20)
		))

	nodeCount = positions.size()
	for i in range(nodeCount):
		graphNodes.append({"id": i, "pos": positions[i], "neighbours": []})

	# spanning tree to ensure the graph is always connected
	var connected = [0]
	var unconnected = Array(range(1, nodeCount))
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

	# Greedily add the shortest remaining edges up to the degree cap
	var pairs = []
	for i in range(nodeCount):
		for j in range(i + 1, nodeCount):
			if not _hasEdge(i, j):
				pairs.append({"i": i, "j": j, "dist": graphNodes[i]["pos"].distance_to(graphNodes[j]["pos"])})
	pairs.sort_custom(func(a, b): return a["dist"] < b["dist"])
	for pair in pairs:
		if graphNodes[pair["i"]]["neighbours"].size() < MAX_NEIGHBOURS and \
		   graphNodes[pair["j"]]["neighbours"].size() < MAX_NEIGHBOURS:
			_addEdge(pair["i"], pair["j"])

	# Choose the two most spatially distant nodes as start and goal
	var maxDist = 0.0
	for i in range(nodeCount):
		for j in range(i + 1, nodeCount):
			var d = graphNodes[i]["pos"].distance_to(graphNodes[j]["pos"])
			if d > maxDist:
				maxDist = d
				startNodeId = i
				goalNodeId = j

func _addEdge(fromId: int, toId: int):
	# Edge weight is proportional to pixel distance, scaled down for readability
	var weight = max(1, int(graphNodes[fromId]["pos"].distance_to(graphNodes[toId]["pos"]) / 10))
	graphNodes[fromId]["neighbours"].append({"id": toId, "weight": weight})
	graphNodes[toId]["neighbours"].append({"id": fromId, "weight": weight})

func _hasEdge(fromId: int, toId: int) -> bool:
	for n in graphNodes[fromId]["neighbours"]:
		if n["id"] == toId:
			return true
	return false

### Display Construction

func _buildGraphDisplay():
	for child in nodeDisplay.get_children():
		child.queue_free()
	nodeCircles.clear()
	edgeLines.clear()
	weightLabels.clear()
	nodeDisplay.size = Vector2(GRAPH_WIDTH, GRAPH_HEIGHT)

	var bg = ColorRect.new()
	bg.color = Color(0.3, 0.3, 0.3, 0.6)
	bg.size = Vector2(GRAPH_WIDTH, GRAPH_HEIGHT)
	nodeDisplay.add_child(bg)
	bg.z_index = -1

	# Draw edges first so node circles render on top
	for i in range(graphNodes.size()):
		for neighbour in graphNodes[i]["neighbours"]:
			var j = neighbour["id"]
			if i < j:  # Draw each undirected edge only once
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
	# Green = start, red = goal, blue = unvisited default
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
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
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
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.8, 0.3)
	nodeCircles[nodeId].add_theme_stylebox_override("panel", style)

### Process (animation tick)

func _process(delta):
	super._process(delta)  # handles hover

	# Step through the visit queue at visitDelay intervals
	if isVisiting and not visitQueue.is_empty():
		visitTimer += delta
		if visitTimer >= visitDelay:
			visitTimer = 0.0
			_stepVisit()
	elif isVisiting and visitQueue.is_empty():
		isVisiting = false

	# After all visits have animated, wait briefly then start the path animation
	if waitingForPath:
		waitTimer += delta
		if waitTimer >= waitDuration:
			waitingForPath = false
			isPathAnimating = true
			pathIndex = 0
			_resetPathColors()

	if isPathAnimating:
		pathTimer += delta
		if pathTimer >= pathDelay:
			pathTimer = 0.0
			_stepPath()

func _stepVisit():
	# Colours visited nodes, orange while active, blue once passed
	if visitQueue.is_empty():
		isVisiting = false
		return
	var nodeId = visitQueue.pop_front()
	if currentNodeId != -1 and currentNodeId != startNodeId and currentNodeId != goalNodeId:
		_setNodeColor(currentNodeId, Color(0.15, 0.55, 0.85))
	currentNodeId = nodeId
	if nodeId != startNodeId and nodeId != goalNodeId:
		_setNodeColor(nodeId, Color(0.95, 0.55, 0.1))
		AudioManager.playSFX("jump")

func _resetPathColors():
	# Resets all nodes and edges to default colours before animating the path
	for i in range(nodeCircles.size()):
		if i != startNodeId and i != goalNodeId:
			_setNodeColor(i, Color(0.25, 0.25, 0.55))
	for key in edgeLines:
		if is_instance_valid(edgeLines[key]):
			edgeLines[key].default_color = Color(0.45, 0.45, 0.45)

func _stepPath():
	# Highlights each node and connecting edge along the committed path in yellow
	if pathIndex >= pendingPath.size():
		isPathAnimating = false
		verifyPath()
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

### Verification

func verifyPath():
	# Validates that the path starts at startNode, ends at goalNode, and uses only real edges
	if pendingPath.is_empty() or pendingPath[0] != startNodeId:
		AudioManager.playSFX("error")
		return
	if pendingPath[pendingPath.size() - 1] != goalNodeId:
		AudioManager.playSFX("error")
		return
	for i in range(pendingPath.size() - 1):
		if not _hasEdge(pendingPath[i], pendingPath[i + 1]):
			AudioManager.playSFX("error")
			return
	Global.submitScore()
	roomTaskCompleted.emit(objectID)
	Analytics.recordComplete(objectID)
	AudioManager.playSFX("task_complete")

### Bridge Methods

func queueVisit(nodeId: int):
	if pathCommitted:
		return  # Ignore visits queued after the path has been declared
	visitQueue.append(nodeId)
	isVisiting = true

func queuePath(pathIds: Array):
	pendingPath = pathIds
	pathCommitted = true
	totalVisitCount = visitQueue.size()

func startPathAnimation():
	# Delays the path animation until all visit animations have played
	waitDuration = totalVisitCount * visitDelay + 0.5
	waitTimer = 0.0
	waitingForPath = true
	pathCommitted = false

### Preamble & Guide

func getPreambleFunctions() -> String:
	# Serialises the adjacency list into a Python dict for injection into the player's script
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

func getBaseGuide() -> String:
	return """[b]Available Data:[/b]

[code]graph[/code]
A dictionary mapping each node ID to a list of its neighbours.
Each neighbour is a list: [neighbourId, edgeWeight].
Example: {0: [[1, 5], [2, 3]], 1: [[0, 5]], ...}

[code]startNode[/code]
The ID of the node to begin traversal from (shown in green).

[code]goalNode[/code]
The ID of the target node to reach (shown in red).

[b]Available Functions:[/b]

[code]getNeighbours(nodeId)[/code]
Returns the list of [neighbourId, weight] pairs for the given node.

[code]visitNode(nodeId)[/code]
Animates the traversal of a node during your search. Call this each time you explore a node.

[code]commitPath(path)[/code]
Accepts a list of node IDs representing the final path from startNode to goalNode.
Triggers the path highlight animation once all visits have played."""

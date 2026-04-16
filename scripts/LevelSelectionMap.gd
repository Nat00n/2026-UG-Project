extends Control

@onready var progressionManager = get_node("/root/LevelProgressionManager")

const NODE_RADIUS = 30
const LINE_WIDTH = 4

var levelNodes: Dictionary = {}  # levelId -> LevelData
var hoveredLevel: String = ""

signal levelSelected(levelId: String)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	setupLevels()
	call_deferred("queue_redraw")

func setupLevels():
	var levels = [
		{"id": "1-1", "name": "Level 1", "pos": Vector2(450, 950), "required": "", "rooms": 4},
		{"id": "2-1", "name": "Level 2", "pos": Vector2(1500, 700), "required": "1-1", "rooms": 3},
		{"id": "3-1", "name": "Level 3", "pos": Vector2(800, 400), "required": "2-1", "rooms": 4},
		{"id": "4-1", "name": "Level 4", "pos": Vector2(300, 220), "required": "3-1", "rooms": 1},
		{"id": "4-2", "name": "Level 5", "pos": Vector2(1250, 250), "required": "3-1", "rooms": 1},
	]
	
	for levelInfo in levels:
		# If already registered, reuse the existing LevelData (has live completion state)
		if progressionManager.levels.has(levelInfo["id"]):
			levelNodes[levelInfo["id"]] = progressionManager.levels[levelInfo["id"]]
			continue
		
		var levelData = LevelData.new()
		levelData.levelId = levelInfo["id"]
		levelData.levelName = levelInfo["name"]
		levelData.position = levelInfo["pos"]
		levelData.requiredLevelId = levelInfo["required"]
		levelData.totalRooms = levelInfo["rooms"]
		levelData.scenePath = "res://scenes/levels/" + levelInfo["id"] + ".tscn"
		
		progressionManager.registerLevel(levelData)
		levelNodes[levelData.levelId] = levelData

func _draw():
	if levelNodes.is_empty():
		return
	
	# Draw connection lines
	for levelId in levelNodes:
		var level = levelNodes[levelId]
		if level == null:
			continue
		if level.requiredLevelId != null and level.requiredLevelId != "" and level.requiredLevelId in levelNodes:
			var fromLevel = levelNodes[level.requiredLevelId]
			if fromLevel == null:
				continue
			var fromPos = fromLevel.position
			var toPos = level.position
			
			var lineColor = Color.WHITE if level.isUnlocked else Color(0.4, 0.4, 0.4)
			draw_line(fromPos, toPos, lineColor, LINE_WIDTH)
	
	# Draw level nodes
	for levelId in levelNodes:
		var level = levelNodes[levelId]
		if level == null:
			continue
		var pos = level.position
		
		var nodeColor: Color
		var outlineColor: Color
		var showHalfFill: bool = false
		var showStar: bool = false
		
		if not level.isUnlocked:
			nodeColor = Color(0.3, 0.3, 0.3)
			outlineColor = Color(0.5, 0.5, 0.5)
		elif level.isFullyComplete():
			nodeColor = Color(0.3, 0.9, 0.3)
			outlineColor = Color.WHITE
			showStar = true
		elif level.isMinimumComplete():
			nodeColor = Color(0.3, 0.9, 0.3)
			outlineColor = Color(0.9, 0.7, 0.2)
			showHalfFill = true
		else:
			nodeColor = Color.WHITE
			outlineColor = Color(0.9, 0.7, 0.2)
		
		# Enhanced hover effect for unlocked levels
		if hoveredLevel == levelId and level.isUnlocked:
			nodeColor = nodeColor.lightened(0.4)
			# Draw pulsing outer ring for unlocked levels
			draw_circle(pos, NODE_RADIUS + 6, Color(1, 1, 1, 0.5))
		elif hoveredLevel == levelId:
			nodeColor = nodeColor.lightened(0.2)
		
		# Draw outline
		draw_circle(pos, NODE_RADIUS + 3, outlineColor)
		
		# Draw node
		if showHalfFill:
			drawHalfFilledCircle(pos, NODE_RADIUS, nodeColor)
		else:
			draw_circle(pos, NODE_RADIUS, nodeColor)
		
		# Draw indicators
		if showStar:
			drawStar(pos)
		elif not level.isUnlocked:
			drawLock(pos)

func drawHalfFilledCircle(pos: Vector2, radius: float, fillColor: Color):
	draw_circle(pos, radius, Color(0.5, 0.5, 0.5))
	var points = PackedVector2Array()
	var numSegments = 32
	for i in range(numSegments / 2 + 1):
		var angle = PI / 2 + (PI * i / (numSegments / 2))
		var point = pos + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	points.append(pos)
	draw_colored_polygon(points, fillColor)

func drawStar(pos: Vector2):
	var starSize = NODE_RADIUS * 0.5
	var points = PackedVector2Array()
	var numPoints = 5
	for i in range(numPoints * 2):
		var angle = -PI / 2 + (PI * i / numPoints)
		var radius = starSize if i % 2 == 0 else starSize * 0.4
		var point = pos + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	draw_colored_polygon(points, Color(1.0, 0.85, 0.0))
	for i in range(points.size()):
		var nextI = (i + 1) % points.size()
		draw_line(points[i], points[nextI], Color(0.8, 0.6, 0.0), 1.5)

func drawLock(pos: Vector2):
	var lockSize = NODE_RADIUS * 0.5
	var bodyRect = Rect2(pos.x - lockSize * 0.4, pos.y, lockSize * 0.8, lockSize * 0.6)
	draw_rect(bodyRect, Color.BLACK)
	var shackleCenter = pos + Vector2(0, -lockSize * 0.3)
	draw_arc(shackleCenter, lockSize * 0.3, 0, PI, 16, Color.BLACK, 2.5)

func _gui_input(event):
	if levelNodes.is_empty():
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mousePos = event.position
		for levelId in levelNodes:
			var level = levelNodes[levelId]
			if level == null:
				continue
			var nodePos = level.position
			if mousePos.distance_to(nodePos) <= NODE_RADIUS:
				if level.isUnlocked:
					levelSelected.emit(levelId)
					print("[LevelMap] Selected level: " + levelId)
				else:
					print("[LevelMap] Level " + levelId + " is locked")
				accept_event()
				break

func _process(_delta):
	var mousePos = get_local_mouse_position()
	var newHovered = ""
	var overUnlockedLevel = false
	
	if Rect2(Vector2.ZERO, size).has_point(mousePos):
		for levelId in levelNodes:
			var level = levelNodes[levelId]
			if level == null:
				continue
			var nodePos = level.position
			if mousePos.distance_to(nodePos) <= NODE_RADIUS:
				newHovered = levelId
				overUnlockedLevel = level.isUnlocked
				break
	
	# Change cursor when over unlocked level
	if overUnlockedLevel:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	
	if newHovered != hoveredLevel:
		hoveredLevel = newHovered
		queue_redraw()

func refreshDisplay():
	queue_redraw()

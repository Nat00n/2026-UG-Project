extends Control

@onready var progressionManager = get_node("/root/LevelProgressionManager")

# Area colors matching the image
const AREA_COLORS = [
	Color(0.2, 0.8, 0.3),  # Green
	Color(0.95, 0.85, 0.2),  # Yellow
	Color(0.3, 0.6, 0.9),  # Blue
	Color(0.7, 0.4, 0.8)   # Purple
]

const AREA_HEIGHT = 200  # Height of each colored area
const NODE_RADIUS = 30
const LINE_WIDTH = 4

var levelNodes: Dictionary = {}  # levelId -> LevelData
var hoveredLevel: String = ""

signal levelSelected(levelId: String)

func _ready():
	# Ensure this control can receive mouse input
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	setupLevels()
	call_deferred("queue_redraw")

func setupLevels():
	# UPDATE THIS to match your actual levels and room counts
	var levels = [
		# Green area (bottom)
		{"id": "1-1", "name": "Level 1", "area": 0, "pos": Vector2(200, 100), "required": "", "rooms": 3},
		
		# Yellow area
		{"id": "2-1", "name": "Level 2", "area": 1, "pos": Vector2(250, 100), "required": "1-1", "rooms": 4},
		
		# Blue area
		{"id": "3-1", "name": "Level 3", "area": 2, "pos": Vector2(180, 130), "required": "2-1", "rooms": 2},
		
		# Purple area (top)
		{"id": "4-1", "name": "Level 4", "area": 3, "pos": Vector2(220, 120), "required": "3-1", "rooms": 5},
		{"id": "4-2", "name": "Level 5", "area": 3, "pos": Vector2(300, 120), "required": "3-1", "rooms": 3},
	]
	
	for levelInfo in levels:
		var levelData = LevelData.new()
		levelData.levelId = levelInfo["id"]
		levelData.levelName = levelInfo["name"]
		levelData.areaIndex = levelInfo["area"]
		levelData.position = levelInfo["pos"]
		levelData.requiredLevelId = levelInfo["required"]
		levelData.totalRooms = levelInfo["rooms"]
		levelData.scenePath = "res://scenes/levels/" + levelInfo["id"] + ".tscn"
		
		progressionManager.registerLevel(levelData)
		levelNodes[levelData.levelId] = levelData

func _draw():
	# Draw colored area backgrounds
	for i in range(4):
		var yPos = size.y - (i + 1) * AREA_HEIGHT
		var rect = Rect2(0, yPos, size.x, AREA_HEIGHT)
		var color = AREA_COLORS[i]
		color.a = 0.3
		draw_rect(rect, color)
	
	# Don't draw nodes if they haven't been set up yet
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
			var fromPos = getLevelScreenPosition(fromLevel)
			var toPos = getLevelScreenPosition(level)
			
			var lineColor = Color.WHITE if level.isUnlocked else Color(0.4, 0.4, 0.4)
			draw_line(fromPos, toPos, lineColor, LINE_WIDTH)
	
	# Draw level nodes
	for levelId in levelNodes:
		var level = levelNodes[levelId]
		if level == null:
			continue
		var pos = getLevelScreenPosition(level)
		
		# Determine node appearance based on completion state
		var nodeColor: Color
		var outlineColor: Color
		var showHalfFill: bool = false
		var showStar: bool = false
		
		if not level.isUnlocked:
			# Locked
			nodeColor = Color(0.3, 0.3, 0.3)
			outlineColor = Color(0.5, 0.5, 0.5)
		elif level.isFullyComplete():
			# Fully complete - all rooms done
			nodeColor = Color(0.3, 0.9, 0.3)
			outlineColor = Color.WHITE
			showStar = true
		elif level.isMinimumComplete():
			# Minimum complete - at least 1 room done
			nodeColor = Color(0.3, 0.9, 0.3)
			outlineColor = Color(0.9, 0.7, 0.2)
			showHalfFill = true
		else:
			# Unlocked but not started
			nodeColor = Color.WHITE
			outlineColor = Color(0.9, 0.7, 0.2)
		
		# Highlight if hovered
		if hoveredLevel == levelId:
			nodeColor = nodeColor.lightened(0.3)
		
		# Draw outline
		draw_circle(pos, NODE_RADIUS + 3, outlineColor)
		
		# Draw node - either full or half-filled
		if showHalfFill:
			# Draw half-filled circle for partial completion
			drawHalfFilledCircle(pos, NODE_RADIUS, nodeColor)
		else:
			# Draw full circle
			draw_circle(pos, NODE_RADIUS, nodeColor)
		
		# Draw indicators
		if showStar:
			# Star for full completion
			drawStar(pos)
		elif not level.isUnlocked:
			# Lock for locked levels
			drawLock(pos)

func getLevelScreenPosition(level: LevelData) -> Vector2:
	var areaY = size.y - (level.areaIndex + 1) * AREA_HEIGHT
	return Vector2(level.position.x, areaY + level.position.y)

func drawHalfFilledCircle(pos: Vector2, radius: float, fillColor: Color):
	# Draw left half filled (for partial completion)
	# First draw the full circle in gray
	draw_circle(pos, radius, Color(0.5, 0.5, 0.5))
	
	# Then draw the filled half
	var points = PackedVector2Array()
	var numSegments = 32
	
	# Create a half-circle on the left side
	for i in range(numSegments / 2 + 1):
		var angle = PI / 2 + (PI * i / (numSegments / 2))
		var point = pos + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	
	# Add center point
	points.append(pos)
	
	# Draw the filled polygon
	draw_colored_polygon(points, fillColor)

func drawStar(pos: Vector2):
	# Draw a star for full completion
	var starSize = NODE_RADIUS * 0.5
	var points = PackedVector2Array()
	var numPoints = 5
	
	for i in range(numPoints * 2):
		var angle = -PI / 2 + (PI * i / numPoints)
		var radius = starSize if i % 2 == 0 else starSize * 0.4
		var point = pos + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	
	# Draw star with gold color
	draw_colored_polygon(points, Color(1.0, 0.85, 0.0))
	# Add outline
	for i in range(points.size()):
		var nextI = (i + 1) % points.size()
		draw_line(points[i], points[nextI], Color(0.8, 0.6, 0.0), 1.5)

func drawLock(pos: Vector2):
	var lockSize = NODE_RADIUS * 0.5
	# Lock body
	var bodyRect = Rect2(pos.x - lockSize * 0.4, pos.y, lockSize * 0.8, lockSize * 0.6)
	draw_rect(bodyRect, Color.BLACK)
	# Lock shackle
	var shackleCenter = pos + Vector2(0, -lockSize * 0.3)
	draw_arc(shackleCenter, lockSize * 0.3, 0, PI, 16, Color.BLACK, 2.5)

func _gui_input(event):
	if levelNodes.is_empty():
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Mouse position is already local to the control in _gui_input
		var mousePos = event.position
		for levelId in levelNodes:
			var level = levelNodes[levelId]
			if level == null:
				continue
			var nodePos = getLevelScreenPosition(level)
			if mousePos.distance_to(nodePos) <= NODE_RADIUS:
				if level.isUnlocked:
					levelSelected.emit(levelId)
					print("[LevelMap] Selected level: " + levelId)
				else:
					print("[LevelMap] Level " + levelId + " is locked")
				accept_event()  # Mark event as handled
				break

func _process(_delta):
	# Handle hovering separately in _process
	var mousePos = get_local_mouse_position()
	var newHovered = ""
	
	# Only check for hover if mouse is within the control
	if Rect2(Vector2.ZERO, size).has_point(mousePos):
		for levelId in levelNodes:
			var level = levelNodes[levelId]
			if level == null:
				continue
			var nodePos = getLevelScreenPosition(level)
			if mousePos.distance_to(nodePos) <= NODE_RADIUS:
				newHovered = levelId
				break
	
	if newHovered != hoveredLevel:
		hoveredLevel = newHovered
		queue_redraw()

func refreshDisplay():
	queue_redraw()

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

var levelNodes: Dictionary = {}  # levelId -> Node2D
var hoveredLevel: String = ""

signal levelSelected(levelId: String)

func _ready():
	setupLevels()
	# Force a redraw after setup
	call_deferred("queue_redraw")

func setupLevels():
	# Example level setup - customize this for your game
	var levels = [
		# Green area (bottom)
		{"id": "1-1", "name": "Level 1", "area": 0, "pos": Vector2(200, 100), "required": ""},
		
		# Yellow area
		{"id": "2-1", "name": "Level 2", "area": 1, "pos": Vector2(250, 100), "required": "1-1"},
		
		# Blue area
		{"id": "3-1", "name": "Level 3", "area": 2, "pos": Vector2(180, 130), "required": "2-1"},
		
		# Purple area (top)
		{"id": "4-1", "name": "Level 4", "area": 3, "pos": Vector2(220, 120), "required": "3-1"},
		{"id": "4-2", "name": "Level 5", "area": 3, "pos": Vector2(300, 120), "required": "3-1"},
	]
	
	for levelInfo in levels:
		var levelData = LevelData.new()
		levelData.levelId = levelInfo["id"]
		levelData.levelName = levelInfo["name"]
		levelData.areaIndex = levelInfo["area"]
		levelData.position = levelInfo["pos"]
		levelData.requiredLevelId = levelInfo["required"]
		levelData.scenePath = "res://levels/" + levelInfo["id"] + ".tscn"
		
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
		
		# Determine node appearance
		var nodeColor: Color
		var outlineColor: Color
		
		if level.isCompleted:
			nodeColor = Color(0.3, 0.9, 0.3)  # Green for completed
			outlineColor = Color.WHITE
		elif level.isUnlocked:
			nodeColor = Color.WHITE
			outlineColor = Color(0.9, 0.7, 0.2)  # Gold outline
		else:
			nodeColor = Color(0.3, 0.3, 0.3)  # Gray for locked
			outlineColor = Color(0.5, 0.5, 0.5)
		
		# Highlight if hovered
		if hoveredLevel == levelId:
			nodeColor = nodeColor.lightened(0.3)
		
		# Draw outline
		draw_circle(pos, NODE_RADIUS + 3, outlineColor)
		# Draw node
		draw_circle(pos, NODE_RADIUS, nodeColor)
		
		# Draw checkmark if completed
		if level.isCompleted:
			drawCheckmark(pos)
		# Draw lock if locked
		elif not level.isUnlocked:
			drawLock(pos)

func getLevelScreenPosition(level: LevelData) -> Vector2:
	var areaY = size.y - (level.areaIndex + 1) * AREA_HEIGHT
	return Vector2(level.position.x, areaY + level.position.y)

func drawCheckmark(pos: Vector2):
	var checkSize = NODE_RADIUS * 0.6
	var p1 = pos + Vector2(-checkSize * 0.5, 0)
	var p2 = pos + Vector2(-checkSize * 0.2, checkSize * 0.4)
	var p3 = pos + Vector2(checkSize * 0.5, -checkSize * 0.5)
	
	draw_line(p1, p2, Color.BLACK, 3)
	draw_line(p2, p3, Color.BLACK, 3)

func drawLock(pos: Vector2):
	var lockSize = NODE_RADIUS * 0.5
	# Lock body
	var bodyRect = Rect2(pos.x - lockSize * 0.4, pos.y, lockSize * 0.8, lockSize * 0.6)
	draw_rect(bodyRect, Color.BLACK)
	# Lock shackle
	var shackleCenter = pos + Vector2(0, -lockSize * 0.3)
	draw_arc(shackleCenter, lockSize * 0.3, 0, PI, 16, Color.BLACK, 2.5)

func _input(event):
	if levelNodes.is_empty():
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mousePos = event.position
		for levelId in levelNodes:
			var level = levelNodes[levelId]
			if level == null:
				continue
			var nodePos = getLevelScreenPosition(level)
			if mousePos.distance_to(nodePos) <= NODE_RADIUS:
				if level.isUnlocked:
					levelSelected.emit(levelId)
				break
	
	elif event is InputEventMouseMotion:
		var mousePos = event.position
		var newHovered = ""
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

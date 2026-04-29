extends Control # Level Selection Map Script
# Custom-drawn map showing all levels as nodes connected by railroad-tile paths
# Handles hover detection, click-to-select, and visual states (locked, partial, complete)
 
@onready var progressionManager = get_node("/root/LevelProgressionManager")
 
const NODE_RADIUS = 30
const LINE_WIDTH = 4
const RAIL_TILE_SIZE = 16
const RAIL_SPACING = 30
const RAIL_SCALE = 2.0
 
var levelNodes: Dictionary = {}   # levelId -> LevelData
var hoveredLevel: String = ""
var railroadTexture: ImageTexture  # Single extracted tile used for all railroad segments
 
signal levelSelected(levelId: String)
 
func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	extractRailroadTile()
	setupLevels()
	call_deferred("queue_redraw")
 
func extractRailroadTile():
	# Crops a single 16×16 railroad tile from the atlas texture for use in drawRailroadPath()
	var atlasTexture = load("res://graphics/trains.png")
	if atlasTexture == null:
		push_error("Could not load railroad atlas texture")
		return
	var atlasImage = atlasTexture.get_image()
	var region = Rect2i(4 * RAIL_TILE_SIZE, 0, RAIL_TILE_SIZE, RAIL_TILE_SIZE)
	railroadTexture = ImageTexture.create_from_image(atlasImage.get_region(region))
 
func setupLevels():
	# Defines all levels with their map positions and prerequisites, then registers them
	# with LevelProgressionManager if they have not already been registered this session
	var levels = [
		{"id": "1-1", "name": "Sorting Train",         "pos": Vector2(450, 950),  "required": "",    "rooms": 4},
		{"id": "2-1", "name": "Searching Train",        "pos": Vector2(1500, 700), "required": "1-1", "rooms": 3},
		{"id": "3-1", "name": "Graph Traversal Train",  "pos": Vector2(700, 400),  "required": "2-1", "rooms": 4},
		{"id": "4-1", "name": "0/1 Knapsack Train",     "pos": Vector2(250, 250),  "required": "3-1", "rooms": 1},
		{"id": "4-2", "name": "Coin Change Train",      "pos": Vector2(1250, 250), "required": "3-1", "rooms": 1},
	]
	for levelInfo in levels:
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
	# Draw railroad connections first so node circles render on top
	for levelId in levelNodes:
		var level = levelNodes[levelId]
		if level == null or level.requiredLevelId == "" or not level.requiredLevelId in levelNodes:
			continue
		var fromLevel = levelNodes[level.requiredLevelId]
		if fromLevel == null:
			continue
		drawRailroadPath(fromLevel.position, level.position, level.isUnlocked)
 
	# Draw level nodes with state-dependent colours and icons
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
			nodeColor = Color(0.3, 0.3, 0.3); outlineColor = Color(0.5, 0.5, 0.5)
		elif level.isFullyComplete():
			nodeColor = Color(0.3, 0.9, 0.3); outlineColor = Color.WHITE; showStar = true
		elif level.isMinimumComplete():
			nodeColor = Color(0.3, 0.9, 0.3); outlineColor = Color(0.9, 0.7, 0.2); showHalfFill = true
		else:
			nodeColor = Color.WHITE; outlineColor = Color(0.9, 0.7, 0.2)
 
		if hoveredLevel == levelId and level.isUnlocked:
			nodeColor = nodeColor.lightened(0.4)
			draw_circle(pos, NODE_RADIUS + 6, Color(1, 1, 1, 0.5))
		elif hoveredLevel == levelId:
			nodeColor = nodeColor.lightened(0.2)
 
		draw_circle(pos, NODE_RADIUS + 3, outlineColor)
		if showHalfFill:
			drawHalfFilledCircle(pos, NODE_RADIUS, nodeColor)
		else:
			draw_circle(pos, NODE_RADIUS, nodeColor)
		if showStar:
			drawStar(pos)
		elif not level.isUnlocked:
			drawLock(pos)
 
func drawRailroadPath(fromPos: Vector2, toPos: Vector2, isUnlocked: bool):
	# Tiles the railroad texture along the line between two level nodes
	if railroadTexture == null:
		draw_line(fromPos, toPos, Color.WHITE if isUnlocked else Color(0.4, 0.4, 0.4), LINE_WIDTH)
		return
	var direction = (toPos - fromPos).normalized()
	var distance = fromPos.distance_to(toPos)
	var angle = direction.angle()
	var numTiles = int(distance / RAIL_SPACING)
	var shade = Color.WHITE if isUnlocked else Color(0.5, 0.5, 0.5)
	for i in range(numTiles + 1):
		var t = float(i) / max(numTiles, 1)
		var pos = fromPos.lerp(toPos, t)
		draw_set_transform(pos, angle, Vector2(RAIL_SCALE, RAIL_SCALE))
		draw_texture(railroadTexture, Vector2(-RAIL_TILE_SIZE / 2, -RAIL_TILE_SIZE / 2), shade)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
 
func drawHalfFilledCircle(pos: Vector2, radius: float, fillColor: Color):
	# Grey background + left-half fill to indicate partial completion
	draw_circle(pos, radius, Color(0.5, 0.5, 0.5))
	var points = PackedVector2Array()
	for i in range(17):
		var angle = PI / 2 + (PI * i / 16)
		points.append(pos + Vector2(cos(angle), sin(angle)) * radius)
	points.append(pos)
	draw_colored_polygon(points, fillColor)
 
func drawStar(pos: Vector2):
	var starSize = NODE_RADIUS * 0.5
	var points = PackedVector2Array()
	for i in range(10):
		var angle = -PI / 2 + (PI * i / 5)
		var radius = starSize if i % 2 == 0 else starSize * 0.4
		points.append(pos + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(1.0, 0.85, 0.0))
	for i in range(points.size()):
		draw_line(points[i], points[(i + 1) % points.size()], Color(0.8, 0.6, 0.0), 1.5)
 
func drawLock(pos: Vector2):
	var lockSize = NODE_RADIUS * 0.5
	draw_rect(Rect2(pos.x - lockSize * 0.4, pos.y, lockSize * 0.8, lockSize * 0.6), Color.BLACK)
	draw_arc(pos + Vector2(0, -lockSize * 0.3), lockSize * 0.3, 0, PI, 16, Color.BLACK, 2.5)
 
func _gui_input(event):
	if levelNodes.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mousePos = event.position
		for levelId in levelNodes:
			var level = levelNodes[levelId]
			if level == null:
				continue
			if mousePos.distance_to(level.position) <= NODE_RADIUS:
				if level.isUnlocked:
					levelSelected.emit(levelId)
				accept_event()
				break
 
func _process(_delta):
	# Updates hover state and cursor shape each frame
	var mousePos = get_local_mouse_position()
	var newHovered = ""
	var overUnlockedLevel = false
	if Rect2(Vector2.ZERO, size).has_point(mousePos):
		for levelId in levelNodes:
			var level = levelNodes[levelId]
			if level == null:
				continue
			if mousePos.distance_to(level.position) <= NODE_RADIUS:
				newHovered = levelId
				overUnlockedLevel = level.isUnlocked
				break
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if overUnlockedLevel else Control.CURSOR_ARROW
	if newHovered != hoveredLevel:
		hoveredLevel = newHovered
		queue_redraw()
 
func refreshDisplay():
	queue_redraw()

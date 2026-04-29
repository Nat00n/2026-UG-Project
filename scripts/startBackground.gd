extends Node2D

# TileMapLayer-based train background using 16x16 tiles
# Single track version

# Tile IDs from your sprite sheet
const TILE_GRASS = 0
const TILE_TRACK = 4
const SKY_TILES = [5, 6, 7, 8, 9, 10, 11] # row 0 # Random sky variations
const GROUND_TILES = [0]  # Ground
const TRANSITION_TILES = [5, 6, 7, 8, 9, 10, 11] # row 1 # Row between ground and sky

# Train configuration
const TRAIN_COLORS = ["red", "green", "blue", "yellow"]
const TRAIN_WIDTH = 160
const TRAIN_HEIGHT = 32
const TRAIN_SPEED_MIN = 60
const TRAIN_SPEED_MAX = 70
const SPAWN_INTERVAL_MIN = 3.0
const SPAWN_INTERVAL_MAX = 6.0
const MIN_TRAIN_DISTANCE = 300

# Track configuration (in 16×16 tiles)
const TRACK_ROW = 20
const SCREEN_WIDTH_TILES = 120
const SCREEN_HEIGHT_TILES = 68

var trainTexture: Texture2D
var trainsOnScreen = []
var spawnTimer = 0.0
var nextSpawnTime = 0.0

# TileMapLayer references (Godot 4 modern approach)
@onready var skyLayer: TileMapLayer = $skyLayer
@onready var groundLayer: TileMapLayer = $groundLayer
@onready var trackLayer: TileMapLayer = $trackLayer

func _ready():
	trainTexture = load("res://graphics/trains.png")
	
	paintBackground()
	
	randomize()
	nextSpawnTime = randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)

func paintBackground():
	
	# Calculate layer positions relative to track
	var grassRowAboveTrack = TRACK_ROW - 1
	var transitionRow = TRACK_ROW - 2
	
	# Paint sky (from top to transition row)
	for x in range(SCREEN_WIDTH_TILES):
		for y in range(transitionRow):
			var tileId = SKY_TILES[randi() % SKY_TILES.size()]
			skyLayer.set_cell(Vector2i(x, y), 0, Vector2i(tileId, 0))
	
	# Paint transition row (grass with foliage, above the grass row)
	for x in range(SCREEN_WIDTH_TILES):
		var tileId = TRANSITION_TILES[randi() % TRANSITION_TILES.size()]
		groundLayer.set_cell(Vector2i(x, transitionRow), 0, Vector2i(tileId, 1))
	
	# Paint grass row (plain grass, directly above track)
	for x in range(SCREEN_WIDTH_TILES):
		groundLayer.set_cell(Vector2i(x, grassRowAboveTrack), 0, Vector2i(TILE_GRASS, 0))
	
	# Paint track row
	for x in range(SCREEN_WIDTH_TILES):
		trackLayer.set_cell(Vector2i(x, TRACK_ROW), 0, Vector2i(TILE_TRACK, 0))
	
	# Paint ground below track (everything beneath = plain grass)
	for x in range(SCREEN_WIDTH_TILES):
		for y in range(TRACK_ROW, SCREEN_HEIGHT_TILES):
			groundLayer.set_cell(Vector2i(x, y), 0, Vector2i(TILE_GRASS, 0))

func _process(delta):
	spawnTimer += delta
	
	if spawnTimer >= nextSpawnTime:
		spawnTimer = 0.0
		nextSpawnTime = randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
		spawnTrain()
	
	# Move trains
	var trainsToRemove = []
	for trainData in trainsOnScreen:
		trainData.sprite.position.x += trainData.speed * delta
		
		var screenWidth = get_viewport_rect().size.x
		if trainData.sprite.position.x > screenWidth + TRAIN_WIDTH:
			trainData.sprite.queue_free()
			trainsToRemove.append(trainData)
	
	for trainData in trainsToRemove:
		trainsOnScreen.erase(trainData)

func spawnTrain():
	if not isTrackClear():
		return
	
	var colorIndex = randi() % TRAIN_COLORS.size()
	var color = TRAIN_COLORS[colorIndex]
	
	var train = Sprite2D.new()
	train.texture = trainTexture
	train.region_enabled = true
	
	# Calculate train region
	# Red=row 3, Green=row 5, Blue=row 7, Yellow=row 9
	var trainRow = 2 + (colorIndex * 2)
	var spriteY = trainRow * 16
	
	train.region_rect = Rect2(0, spriteY, TRAIN_WIDTH, TRAIN_HEIGHT)
	
	# Position on track (centered on track row)
	var trackY = TRACK_ROW * 16 - 4
	train.position = Vector2(-TRAIN_WIDTH / 2, trackY)
	train.z_index = -1
	
	add_child(train)
	
	var speed = randf_range(TRAIN_SPEED_MIN, TRAIN_SPEED_MAX)
	
	trainsOnScreen.append({
		"sprite": train,
		"color": color,
		"speed": speed
	})

func isTrackClear() -> bool:
	for trainData in trainsOnScreen:
		if trainData.sprite.position.x < MIN_TRAIN_DISTANCE:
			return false
	return true

func clearAllTrains():
	for trainData in trainsOnScreen:
		trainData.sprite.queue_free()
	trainsOnScreen.clear()

extends Node2D # Start Background Script
# Animated background for the start menu screen
# Paints a multi-layer tilemap (sky, transition foliage, ground, railroad track)
# Spawns coloured train sprites that move across the screen at random intervals
 
const TILE_GRASS = 0
const TILE_TRACK = 4
const SKY_TILES = [5, 6, 7, 8, 9, 10, 11]
const GROUND_TILES = [0]
const TRANSITION_TILES = [5, 6, 7, 8, 9, 10, 11]
 
const TRAIN_COLORS = ["red", "green", "blue", "yellow"]
const TRAIN_WIDTH = 160
const TRAIN_HEIGHT = 32
const TRAIN_SPEED_MIN = 60
const TRAIN_SPEED_MAX = 70
const SPAWN_INTERVAL_MIN = 3.0
const SPAWN_INTERVAL_MAX = 6.0
const MIN_TRAIN_DISTANCE = 300  # Minimum gap between trains to prevent overlap
 
const TRACK_ROW = 20
const SCREEN_WIDTH_TILES = 120
const SCREEN_HEIGHT_TILES = 68
 
var trainTexture: Texture2D
var trainsOnScreen = []   # Array of {sprite, color, speed} dicts
var spawnTimer = 0.0
var nextSpawnTime = 0.0
 
@onready var skyLayer: TileMapLayer = $skyLayer
@onready var groundLayer: TileMapLayer = $groundLayer
@onready var trackLayer: TileMapLayer = $trackLayer
 
func _ready():
	trainTexture = load("res://graphics/trains.png")
	paintBackground()
	randomize()
	nextSpawnTime = randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
 
func paintBackground():
	# Fills the three tile layers: random sky tiles above, transition foliage row,
	# plain grass row, a single track row, then solid ground below
	var grassRowAboveTrack = TRACK_ROW - 1
	var transitionRow = TRACK_ROW - 2
	for x in range(SCREEN_WIDTH_TILES):
		for y in range(transitionRow):
			skyLayer.set_cell(Vector2i(x, y), 0, Vector2i(SKY_TILES[randi() % SKY_TILES.size()], 0))
	for x in range(SCREEN_WIDTH_TILES):
		groundLayer.set_cell(Vector2i(x, transitionRow), 0, Vector2i(TRANSITION_TILES[randi() % TRANSITION_TILES.size()], 1))
	for x in range(SCREEN_WIDTH_TILES):
		groundLayer.set_cell(Vector2i(x, grassRowAboveTrack), 0, Vector2i(TILE_GRASS, 0))
	for x in range(SCREEN_WIDTH_TILES):
		trackLayer.set_cell(Vector2i(x, TRACK_ROW), 0, Vector2i(TILE_TRACK, 0))
	for x in range(SCREEN_WIDTH_TILES):
		for y in range(TRACK_ROW, SCREEN_HEIGHT_TILES):
			groundLayer.set_cell(Vector2i(x, y), 0, Vector2i(TILE_GRASS, 0))
 
func _process(delta):
	spawnTimer += delta
	if spawnTimer >= nextSpawnTime:
		spawnTimer = 0.0
		nextSpawnTime = randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
		spawnTrain()
 
	# Move all active trains and remove ones that have left the screen
	var toRemove = []
	for trainData in trainsOnScreen:
		trainData.sprite.position.x += trainData.speed * delta
		if trainData.sprite.position.x > get_viewport_rect().size.x + TRAIN_WIDTH:
			trainData.sprite.queue_free()
			toRemove.append(trainData)
	for trainData in toRemove:
		trainsOnScreen.erase(trainData)
 
func spawnTrain():
	# Picks a random colour and spawns a train sprite at the left edge of the track row
	if not isTrackClear():
		return
	var colorIndex = randi() % TRAIN_COLORS.size()
	var train = Sprite2D.new()
	train.texture = trainTexture
	train.region_enabled = true
	# Each colour occupies two rows in the sprite sheet, rows alternate per colour
	var trainRow = 2 + (colorIndex * 2)
	train.region_rect = Rect2(0, trainRow * 16, TRAIN_WIDTH, TRAIN_HEIGHT)
	train.position = Vector2(-TRAIN_WIDTH / 2, TRACK_ROW * 16 - 4)
	train.z_index = -1
	add_child(train)
	trainsOnScreen.append({
		"sprite": train,
		"color": TRAIN_COLORS[colorIndex],
		"speed": randf_range(TRAIN_SPEED_MIN, TRAIN_SPEED_MAX)
	})
 
func isTrackClear() -> bool:
	# Prevents a new train from spawning too close behind an existing one
	for trainData in trainsOnScreen:
		if trainData.sprite.position.x < MIN_TRAIN_DISTANCE:
			return false
	return true

extends CanvasLayer # Level Background Script
# Procedural scrolling background for all in-game levels
# Uses a biome configuration dictionary to load different art assets per level,
# creating a parallax effect with three layers (sky, clouds, foliage) and a tiling ground layer
# The train carriages sit on the rail track and bounce gently
# Level 4-2 additionally plays a sprite-sheet animation on the carriages
 
@export var scrollSpeed: float = 200.0
@export var trainScale: float = 6.0
@export var trainScaleY: float = 1.8      # Extra vertical stretch for the carriage sprites
@export var railroadScale: float = 6.0
@export var groundStartY: float = 800.0
 
const CLOUD_SPEED_FRACTION: float = 0.15   # Clouds scroll at 15% of ground speed
const FOLIAGE_SPEED_FRACTION: float = 0.45 # Foliage scrolls at 45% of ground speed
 
@onready var skySprite    = $SkyParallax/SkySprite
@onready var cloudSprite  = $CloudParallax/CloudSprite
@onready var foliageSprite = $FoliageParallax/FoliageSprite
@onready var groundScroller = $GroundScroller
@onready var groundBackdrop = $GroundScroller/GroundBackdrop
@onready var groundTileMap  = $GroundScroller/GroundTileMap
@onready var railroadSprite = $GroundScroller/RailroadSprite
@onready var leftCarriage   = $TrainSegments/LeftCarriage
@onready var centerCarriage = $TrainSegments/CentreCarriage
@onready var rightCarriage  = $TrainSegments/RightCarriage
 
var viewportWidth: float
var viewportHeight: float
var levelId: String = ""
 
const REPEAT_MULTIPLIER: int = 3   # Tile map and backdrop are 3× viewport wide to hide wrap
const TILE_SIZE: int = 64
var wrapPoint: float
 
var cloudPanels: Array = []    # [panelA, panelB] — two-panel infinite scroll
var foliagePanels: Array = []
 
var trainBaseY: float = 0.0    # Y coordinate for the carriage centre, used for the bounce
 
# Sprite-sheet animation state (level 4-2 only)
var animationTime: float = 0.0
var currentFrame: int = 0
const ANIMATION_SPEED: float = 8.0
const CARRIAGE_FRAME_WIDTH: int = 256
const CARRIAGE_FRAME_HEIGHT: int = 64
const TOTAL_FRAMES: int = 16
 
var bounceTime: float = 0.0
 
# Per-level art and tile configuration
var biomeConfig = {
	"1-1": {
		"sky": "res://graphics/ParaBackgrounds/background_solid_sky.svg",
		"cloud": "res://graphics/ParaBackgrounds/background_solid_cloud.svg",
		"foliage": "res://graphics/ParaBackgrounds/background_color_hills.svg",
		"ground": "res://graphics/ParaBackgrounds/background_solid_grass.svg",
		"carriage": "res://graphics/carriages/carriage_v18_car4.png",
		"tile_top": Vector2i(11, 9), "tile_under": Vector2i(8, 9)
	},
	"2-1": {
		"sky": "res://graphics/ParaBackgrounds/background_solid_sky.svg",
		"cloud": "res://graphics/ParaBackgrounds/background_solid_cloud.svg",
		"foliage": "res://graphics/ParaBackgrounds/background_color_desert.svg",
		"ground": "res://graphics/ParaBackgrounds/background_solid_grass.svg",
		"carriage": "res://graphics/carriages/carriage_v18_car3.png",
		"tile_top": Vector2i(13, 12), "tile_under": Vector2i(10, 12)
	},
	"3-1": {
		"sky": "res://graphics/ParaBackgrounds/background_solid_sky.svg",
		"cloud": "res://graphics/ParaBackgrounds/background_solid_cloud.svg",
		"foliage": "res://graphics/ParaBackgrounds/background_color_mushrooms.svg",
		"ground": "res://graphics/ParaBackgrounds/background_solid_dirt.svg",
		"carriage": "res://graphics/carriages/carriage_v18_car7.png",
		"tile_top": Vector2i(1, 8), "tile_under": Vector2i(16, 7)
	},
	"4-1": {
		"sky": "res://graphics/ParaBackgrounds/background_solid_sky.svg",
		"cloud": "res://graphics/ParaBackgrounds/background_solid_cloud.svg",
		"foliage": "res://graphics/ParaBackgrounds/background_fade_hills.svg",
		"ground": "res://graphics/ParaBackgrounds/background_solid_grass.svg",
		"carriage": "res://graphics/carriages/carriage_v18_car8.png",
		"tile_top": Vector2i(15, 15), "tile_under": Vector2i(12, 15)
	},
	"4-2": {
		"sky": "res://graphics/ParaBackgrounds/background_solid_sky.svg",
		"cloud": "res://graphics/ParaBackgrounds/background_solid_cloud.svg",
		"foliage": "res://graphics/ParaBackgrounds/background_fade_hills.svg",
		"ground": "res://graphics/ParaBackgrounds/background_solid_grass.svg",
		"carriage": "animated",  # Special value; triggers sprite-sheet animation
		"tile_top": Vector2i(5, 14), "tile_under": Vector2i(2, 14)
	}
}
 
func _ready():
	viewportWidth = 1920.0
	viewportHeight = 1080.0
	wrapPoint = -viewportWidth
	var parentLevel = get_parent()
	if parentLevel and parentLevel.get("levelId") != null:
		levelId = parentLevel.levelId
	else:
		levelId = "1-1"
	loadBiome()
	setupGroundTiles()
	setupRailroad()
	setupTrainCarriages()
 
### Two-panel Parallax Helpers
 
func makePanelPair(template: Sprite2D, texture: Texture2D, posY: float) -> Array:
	# Configures the template sprite and creates a sibling sprite one viewport width to the right
	# Together they tile seamlessly; scrollPanels() rotates the left one to the right as it exits
	var panelA = template
	panelA.texture = texture; panelA.centered = false; panelA.region_enabled = true
	panelA.region_rect = Rect2(0, 0, viewportWidth, viewportHeight)
	panelA.position = Vector2(0.0, posY)
	var panelB = Sprite2D.new()
	panelB.texture = texture; panelB.centered = false; panelB.region_enabled = true
	panelB.region_rect = Rect2(0, 0, viewportWidth, viewportHeight)
	panelB.position = Vector2(viewportWidth, posY)
	template.get_parent().add_child(panelB)
	return [panelA, panelB]
 
func scrollPanels(panels: Array, delta: float, speedFraction: float):
	for p in panels:
		p.position.x -= scrollSpeed * delta * speedFraction
	var left  = panels[0] if panels[0].position.x <= panels[1].position.x else panels[1]
	var right = panels[0] if panels[0].position.x >  panels[1].position.x else panels[1]
	# When the left panel scrolls entirely off screen, teleport it to the right of the other
	if left.position.x + viewportWidth <= 0.0:
		left.position.x = right.position.x + viewportWidth
 
### Biome Loading
 
func loadBiome():
	if not biomeConfig.has(levelId):
		push_error("[LevelBackground] No biome config for level: ", levelId)
		return
	var config = biomeConfig[levelId]
	skySprite.texture = load(config["sky"]); skySprite.centered = false
	skySprite.region_enabled = true; skySprite.region_rect = Rect2(0, 0, viewportWidth, viewportHeight)
	cloudPanels = makePanelPair(cloudSprite, load(config["cloud"]), 0.0)
	foliagePanels = makePanelPair(foliageSprite, load(config["foliage"]), 0.0)
	var wide = viewportWidth * REPEAT_MULTIPLIER
	groundBackdrop.texture = load(config["ground"]); groundBackdrop.centered = false
	groundBackdrop.position = Vector2(0.0, groundStartY); groundBackdrop.region_enabled = true
	groundBackdrop.region_rect = Rect2(0, 0, wide, viewportHeight - groundStartY + 200)
 
func setupGroundTiles():
	if not biomeConfig.has(levelId): return
	var config = biomeConfig[levelId]
	groundTileMap.clear()
	var startRow = int(groundStartY / float(TILE_SIZE))
	var tilesWide = int(ceil(viewportWidth * REPEAT_MULTIPLIER / float(TILE_SIZE))) + 2
	var tilesHigh = int(ceil((viewportHeight - groundStartY) / float(TILE_SIZE))) + 2
	for x in range(tilesWide):
		for y in range(tilesHigh):
			var cellY = startRow + y
			groundTileMap.set_cell(Vector2i(x, cellY), 0, config["tile_top"] if y == 0 else config["tile_under"])
	groundTileMap.z_index = 1
 
func setupRailroad():
	railroadSprite.texture = load("res://graphics/railtrack_v1.png")
	var texH = railroadSprite.texture.get_height()
	var regionW = (viewportWidth * REPEAT_MULTIPLIER) / railroadScale
	railroadSprite.centered = false; railroadSprite.scale = Vector2(railroadScale, railroadScale)
	railroadSprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	railroadSprite.region_enabled = true; railroadSprite.region_rect = Rect2(0, 0, regionW, texH)
	railroadSprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	railroadSprite.position = Vector2(0.0, groundStartY - texH * railroadScale)
 
func setupTrainCarriages():
	if not biomeConfig.has(levelId): return
	var config = biomeConfig[levelId]
	var screenCenter = viewportWidth / 2.0
	var railTopY = groundStartY - (railroadSprite.texture.get_height() * railroadScale)
	var scaleVec = Vector2(trainScale, trainScale * trainScaleY)
 
	if config["carriage"] == "animated":
		# Level 4-2: load sprite sheet and set initial frame regions per carriage row
		var spriteSheet = load("res://graphics/carriages/sheet_carriage_v18.png")
		for c in [leftCarriage, centerCarriage, rightCarriage]:
			c.texture = spriteSheet; c.region_enabled = true
		leftCarriage.region_rect   = Rect2(0, 0 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)
		centerCarriage.region_rect = Rect2(0, 1 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)
		rightCarriage.region_rect  = Rect2(0, 4 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)
		var scaledH = CARRIAGE_FRAME_HEIGHT * trainScale * trainScaleY
		trainBaseY = railTopY - scaledH / 2.0
		var carriageW = CARRIAGE_FRAME_WIDTH * trainScale
		centerCarriage.position = Vector2(screenCenter, trainBaseY)
		leftCarriage.position   = Vector2(screenCenter - carriageW, trainBaseY)
		rightCarriage.position  = Vector2(screenCenter + carriageW, trainBaseY)
	else:
		var carriageTexture = load(config["carriage"])
		for c in [leftCarriage, centerCarriage, rightCarriage]:
			c.texture = carriageTexture; c.region_enabled = false
		var scaledH = carriageTexture.get_height() * trainScale * trainScaleY
		trainBaseY = railTopY - scaledH / 2.0
		var carriageW = carriageTexture.get_width() * trainScale
		centerCarriage.position = Vector2(screenCenter, trainBaseY)
		leftCarriage.position   = Vector2(screenCenter - carriageW, trainBaseY)
		rightCarriage.position  = Vector2(screenCenter + carriageW, trainBaseY)
 
	for carriage in [leftCarriage, centerCarriage, rightCarriage]:
		carriage.centered = true; carriage.scale = scaleVec
		carriage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 
### Process
 
func _process(delta: float):
	scrollPanels(cloudPanels, delta, CLOUD_SPEED_FRACTION)
	scrollPanels(foliagePanels, delta, FOLIAGE_SPEED_FRACTION)
	# Ground wraps at exactly one viewport width to keep the tiling seamless
	groundScroller.position.x -= scrollSpeed * delta
	if groundScroller.position.x <= wrapPoint:
		groundScroller.position.x += viewportWidth
	if levelId == "4-2":
		animateCarriages(delta)
	addTrainBounce(delta)
 
func animateCarriages(delta: float):
	# Advances the sprite-sheet frame counter and updates all three carriage region rects
	animationTime += delta * ANIMATION_SPEED
	var newFrame = int(animationTime) % TOTAL_FRAMES
	if newFrame != currentFrame:
		currentFrame = newFrame
		var frameX = currentFrame * CARRIAGE_FRAME_WIDTH
		leftCarriage.region_rect   = Rect2(frameX, 0 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)
		centerCarriage.region_rect = Rect2(frameX, 1 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)
		rightCarriage.region_rect  = Rect2(frameX, 4 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)
 
func addTrainBounce(delta: float):
	# Applies a gentle sinusoidal vertical oscillation to simulate the train riding the rails
	bounceTime += delta
	var bounce = sin(bounceTime * 3.0) + 1
	leftCarriage.position.y   = trainBaseY + bounce
	centerCarriage.position.y = trainBaseY + bounce
	rightCarriage.position.y  = trainBaseY + bounce

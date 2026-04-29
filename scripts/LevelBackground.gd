extends CanvasLayer

@export var scrollSpeed: float = 200.0
@export var trainScale: float = 6.0        # horizontal + base vertical scale
@export var trainScaleY: float = 1.8       # multiplied on top of trainScale vertically only
@export var railroadScale: float = 6.0
@export var groundStartY: float = 800.0

# Parallax speed fractions relative to ground scroll speed
const CLOUD_SPEED_FRACTION: float = 0.15
const FOLIAGE_SPEED_FRACTION: float = 0.45

# Existing scene sprites become panel A; panel B is created at runtime
@onready var skySprite    = $SkyParallax/SkySprite
@onready var cloudSprite  = $CloudParallax/CloudSprite
@onready var foliageSprite = $FoliageParallax/FoliageSprite

# Ground scroller
@onready var groundScroller = $GroundScroller
@onready var groundBackdrop = $GroundScroller/GroundBackdrop
@onready var groundTileMap  = $GroundScroller/GroundTileMap
@onready var railroadSprite = $GroundScroller/RailroadSprite

# Train carriages
@onready var leftCarriage   = $TrainSegments/LeftCarriage
@onready var centerCarriage = $TrainSegments/CentreCarriage
@onready var rightCarriage  = $TrainSegments/RightCarriage

var viewportWidth: float
var viewportHeight: float
var levelId: String = ""

const REPEAT_MULTIPLIER: int = 3
const TILE_SIZE: int = 64
var wrapPoint: float

# Two-panel arrays: [panelA, panelB] — both the same texture, viewportWidth apart
var cloudPanels: Array = []
var foliagePanels: Array = []

var trainBaseY: float = 0.0

# Sprite sheet animation (level 4-2)
var animationTime: float = 0.0
var currentFrame: int = 0
const ANIMATION_SPEED: float = 8.0
const CARRIAGE_FRAME_WIDTH: int = 256
const CARRIAGE_FRAME_HEIGHT: int = 64
const TOTAL_FRAMES: int = 16

var bounceTime: float = 0.0

var biomeConfig = {
	"1-1": {
		"sky": "res://graphics/ParaBackgrounds/background_solid_sky.svg",
		"cloud": "res://graphics/ParaBackgrounds/background_solid_cloud.svg",
		"foliage": "res://graphics/ParaBackgrounds/background_color_hills.svg",
		"ground": "res://graphics/ParaBackgrounds/background_solid_grass.svg",
		"carriage": "res://graphics/carriages/carriage_v18_car4.png",
		"tile_top": Vector2i(11, 9),
		"tile_under": Vector2i(8, 9)
	},
	"2-1": {
		"sky": "res://graphics/ParaBackgrounds/background_solid_sky.svg",
		"cloud": "res://graphics/ParaBackgrounds/background_solid_cloud.svg",
		"foliage": "res://graphics/ParaBackgrounds/background_color_desert.svg",
		"ground": "res://graphics/ParaBackgrounds/background_solid_grass.svg",
		"carriage": "res://graphics/carriages/carriage_v18_car3.png",
		"tile_top": Vector2i(13, 12),
		"tile_under": Vector2i(10, 12)
	},
	"3-1": {
		"sky": "res://graphics/ParaBackgrounds/background_solid_sky.svg",
		"cloud": "res://graphics/ParaBackgrounds/background_solid_cloud.svg",
		"foliage": "res://graphics/ParaBackgrounds/background_color_mushrooms.svg",
		"ground": "res://graphics/ParaBackgrounds/background_solid_dirt.svg",
		"carriage": "res://graphics/carriages/carriage_v18_car7.png",
		"tile_top": Vector2i(1, 8),
		"tile_under": Vector2i(16, 7)
	},
	"4-1": {
		"sky": "res://graphics/ParaBackgrounds/background_solid_sky.svg",
		"cloud": "res://graphics/ParaBackgrounds/background_solid_cloud.svg",
		"foliage": "res://graphics/ParaBackgrounds/background_fade_hills.svg",
		"ground": "res://graphics/ParaBackgrounds/background_solid_grass.svg",
		"carriage": "res://graphics/carriages/carriage_v18_car8.png",
		"tile_top": Vector2i(15, 15),
		"tile_under": Vector2i(12, 15)
	},
	"4-2": {
		"sky": "res://graphics/ParaBackgrounds/background_solid_sky.svg",
		"cloud": "res://graphics/ParaBackgrounds/background_solid_cloud.svg",
		"foliage": "res://graphics/ParaBackgrounds/background_fade_hills.svg",
		"ground": "res://graphics/ParaBackgrounds/background_solid_grass.svg",
		"carriage": "animated",
		"tile_top": Vector2i(5, 14),
		"tile_under": Vector2i(2, 14)
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

# Creates a second Sprite2D panel as a sibling of the template node, copies
# its texture and layout, and positions both panels side-by-side so they fill
# the screen with no gap. Returns [panelA, panelB].
func makePanelPair(template: Sprite2D, texture: Texture2D, posY: float) -> Array:
	var panelA = template
	panelA.texture       = texture
	panelA.centered      = false
	panelA.region_enabled = true
	panelA.region_rect   = Rect2(0, 0, viewportWidth, viewportHeight)
	panelA.position      = Vector2(0.0, posY)

	var panelB = Sprite2D.new()
	panelB.texture        = texture
	panelB.centered       = false
	panelB.region_enabled = true
	panelB.region_rect    = Rect2(0, 0, viewportWidth, viewportHeight)
	panelB.position       = Vector2(viewportWidth, posY)
	template.get_parent().add_child(panelB)

	return [panelA, panelB]

# Scrolls both panels left and wraps the one that exits the screen around to
# the right of the other — the transition always happens off-screen.
func scrollPanels(panels: Array, delta: float, speedFraction: float):
	for p in panels:
		p.position.x -= scrollSpeed * delta * speedFraction

	# Identify which panel is currently further left
	var left  = panels[0] if panels[0].position.x <= panels[1].position.x else panels[1]
	var right = panels[0] if panels[0].position.x >  panels[1].position.x else panels[1]

	# Once the left panel's right edge has left the screen, recycle it
	if left.position.x + viewportWidth <= 0.0:
		left.position.x = right.position.x + viewportWidth

# ─────────────────────────────────────────────
#  BIOME SETUP
# ─────────────────────────────────────────────

func loadBiome():
	if not biomeConfig.has(levelId):
		push_error("[LevelBackground] No biome config for level: ", levelId)
		return

	var config = biomeConfig[levelId]
	var wide = viewportWidth * REPEAT_MULTIPLIER

	# ── SKY ──────────────────────────────────────────────────────────────
	# Static solid colour — single sprite, no scrolling needed.
	skySprite.texture       = load(config["sky"])
	skySprite.centered      = false
	skySprite.position      = Vector2(0.0, 0.0)
	skySprite.region_enabled = true
	skySprite.region_rect   = Rect2(0, 0, viewportWidth, viewportHeight)

	# ── CLOUDS — two-panel wrap ───────────────────────────────────────────
	cloudPanels = makePanelPair(
		cloudSprite,
		load(config["cloud"]),
		0.0
	)

	# ── FOLIAGE — two-panel wrap ──────────────────────────────────────────
	foliagePanels = makePanelPair(
		foliageSprite,
		load(config["foliage"]),
		0.0
	)

	# ── GROUND BACKDROP ──────────────────────────────────────────────────
	# Solid colour fills from groundStartY downward; scrolls with the tilemap.
	groundBackdrop.texture       = load(config["ground"])
	groundBackdrop.centered      = false
	groundBackdrop.position      = Vector2(0.0, groundStartY)
	groundBackdrop.region_enabled = true
	groundBackdrop.region_rect   = Rect2(0, 0, wide, viewportHeight - groundStartY + 200)

# ─────────────────────────────────────────────
#  GROUND TILES
# ─────────────────────────────────────────────

func setupGroundTiles():
	if not biomeConfig.has(levelId):
		return

	var config = biomeConfig[levelId]
	groundTileMap.clear()

	var startRow: int  = int(groundStartY / float(TILE_SIZE))
	var tilesWide: int = int(ceil(viewportWidth * REPEAT_MULTIPLIER / float(TILE_SIZE))) + 2
	var tilesHigh: int = int(ceil((viewportHeight - groundStartY) / float(TILE_SIZE))) + 2

	for x in range(tilesWide):
		for y in range(tilesHigh):
			var cellY = startRow + y
			if y == 0:
				groundTileMap.set_cell(Vector2i(x, cellY), 0, config["tile_top"])
			else:
				groundTileMap.set_cell(Vector2i(x, cellY), 0, config["tile_under"])

	# GroundBackdrop is drawn after GroundTileMap in the scene tree so it
	# renders on top — raise the tilemap above it.
	groundTileMap.z_index = 1

func setupRailroad():
	railroadSprite.texture = load("res://graphics/railtrack_v1.png")

	var texH: float = railroadSprite.texture.get_height()

	# region_rect is in texture-space pixels; scale multiplies afterwards.
	# Divide target world-width by scale so the two cancel out correctly.
	var regionW: float = (viewportWidth * REPEAT_MULTIPLIER) / railroadScale

	railroadSprite.centered        = false
	railroadSprite.scale           = Vector2(railroadScale, railroadScale)
	railroadSprite.texture_repeat  = CanvasItem.TEXTURE_REPEAT_ENABLED
	railroadSprite.region_enabled  = true
	railroadSprite.region_rect     = Rect2(0, 0, regionW, texH)
	railroadSprite.texture_filter  = CanvasItem.TEXTURE_FILTER_NEAREST

	# Bottom edge flush with the ground surface
	railroadSprite.position = Vector2(0.0, groundStartY - texH * railroadScale)

# ─────────────────────────────────────────────
#  TRAIN CARRIAGES
# ─────────────────────────────────────────────

func setupTrainCarriages():
	if not biomeConfig.has(levelId):
		return

	var config    = biomeConfig[levelId]
	var screenCenter: float = viewportWidth / 2.0

	# Rail top edge — GroundScroller only ever moves on X, so Y is stable.
	var railTopY: float = groundStartY - (railroadSprite.texture.get_height() * railroadScale)

	# trainScaleY stretches the carriage vertically without affecting width.
	# Final scale: X = trainScale, Y = trainScale * trainScaleY
	var scaleVec = Vector2(trainScale, trainScale * trainScaleY)

	if config["carriage"] == "animated":
		var spriteSheet = load("res://graphics/carriages/sheet_carriage_v18.png")

		leftCarriage.texture   = spriteSheet
		centerCarriage.texture = spriteSheet
		rightCarriage.texture  = spriteSheet

		leftCarriage.region_enabled   = true
		centerCarriage.region_enabled = true
		rightCarriage.region_enabled  = true

		leftCarriage.region_rect   = Rect2(0, 0 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)
		centerCarriage.region_rect = Rect2(0, 1 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)
		rightCarriage.region_rect  = Rect2(0, 4 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)

		var scaledH: float = CARRIAGE_FRAME_HEIGHT * trainScale * trainScaleY
		trainBaseY = railTopY - scaledH / 2.0

		var carriageW: float = CARRIAGE_FRAME_WIDTH * trainScale
		centerCarriage.position = Vector2(screenCenter, trainBaseY)
		leftCarriage.position   = Vector2(screenCenter - carriageW, trainBaseY)
		rightCarriage.position  = Vector2(screenCenter + carriageW, trainBaseY)

	else:
		var carriageTexture = load(config["carriage"])

		centerCarriage.texture = carriageTexture
		leftCarriage.texture   = carriageTexture
		rightCarriage.texture  = carriageTexture

		centerCarriage.region_enabled = false
		leftCarriage.region_enabled   = false
		rightCarriage.region_enabled  = false

		var scaledH: float = carriageTexture.get_height() * trainScale * trainScaleY
		trainBaseY = railTopY - scaledH / 2.0

		var carriageW: float = carriageTexture.get_width() * trainScale
		centerCarriage.position = Vector2(screenCenter, trainBaseY)
		leftCarriage.position   = Vector2(screenCenter - carriageW, trainBaseY)
		rightCarriage.position  = Vector2(screenCenter + carriageW, trainBaseY)

	for carriage in [leftCarriage, centerCarriage, rightCarriage]:
		carriage.centered       = true
		carriage.scale          = scaleVec
		carriage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# ─────────────────────────────────────────────
#  PROCESS
# ─────────────────────────────────────────────

func _process(delta: float):
	# Clouds — 15 % speed; panels swap off-screen so no visible jump
	scrollPanels(cloudPanels, delta, CLOUD_SPEED_FRACTION)

	# Foliage — 45 % speed; same two-panel rotation
	scrollPanels(foliagePanels, delta, FOLIAGE_SPEED_FRACTION)

	# Ground — full speed; uniform tiles make the seamless wrap invisible
	groundScroller.position.x -= scrollSpeed * delta
	if groundScroller.position.x <= wrapPoint:
		groundScroller.position.x += viewportWidth

	if levelId == "4-2":
		animateCarriages(delta)

	addTrainBounce(delta)

# ─────────────────────────────────────────────
#  ANIMATION / BOUNCE
# ─────────────────────────────────────────────

func animateCarriages(delta: float):
	animationTime += delta * ANIMATION_SPEED
	var newFrame: int = int(animationTime) % TOTAL_FRAMES

	if newFrame != currentFrame:
		currentFrame = newFrame
		var frameX: int = currentFrame * CARRIAGE_FRAME_WIDTH
		leftCarriage.region_rect   = Rect2(frameX, 0 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)
		centerCarriage.region_rect = Rect2(frameX, 1 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)
		rightCarriage.region_rect  = Rect2(frameX, 4 * CARRIAGE_FRAME_HEIGHT, CARRIAGE_FRAME_WIDTH, CARRIAGE_FRAME_HEIGHT)

func addTrainBounce(delta: float):
	bounceTime += delta
	var bounce: float = sin(bounceTime * 3.0)+1
	leftCarriage.position.y   = trainBaseY + bounce
	centerCarriage.position.y = trainBaseY + bounce
	rightCarriage.position.y  = trainBaseY + bounce

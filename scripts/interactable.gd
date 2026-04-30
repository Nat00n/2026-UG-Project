class_name InteractableObject # Interactable Object Script - Base Class
extends Area2D
# Base class inherited by all puzzle objects (SortObject, SearchObject, GraphObject, KnapsackObject, CoinChangeObject)
# Provides shared functionality for:
#	- Hover detection and tooltip display
#	- Click-to-open IDE popup
#	- Script persistence via localStorage
#	- Card-based visualisation of data arrays (Sort and Search Objects)
#	- Tween lifecycle management

# Emitted when the child class determines the task has been solved correctly.
# The Level script connects to this to update room completion state.
signal roomTaskCompleted(objectID: String)

@onready var hoverLabel: Label = $hoverLabel       # Tooltip shown on mouse-over
@onready var visual: Sprite2D = $visual             # The sprite the player clicks on
@onready var nodeDisplay: Control = $nodeDisplay    # Container for the visualisation UI

# Exported fields are set per-object in the Godot editor
@export var objectName: String = "Object"
@export var objectID: String = "obj_0"
@export_multiline var taskDescription: String = "None"
@export var taskName: String = "None"
@export_multiline var taskGuide: String = "None"
@export_multiline var exampleCode: String = ""      # Optional example solution shown on demand

var _hovered := false
var _popup: CanvasLayer      # Reference to the IDE CanvasLayer, injected by RoomManager
var dataNodes: Array = []    # Current working data array
var initialDataNodes: Array = []  # Snapshot used to reset the display between runs
var cardNodes: Array = []    # References to the PanelContainer nodes in the card display
var savedScript: String = "" # Player's last-written code, persisted across sessions
var activeTweens: Array = [] # Tracked so all tweens can be killed on reset

const cardWidth = 60
const cardHeight = 60
const cardGap = 15

### Lifecycle

func _ready():
	hoverLabel.visible = false
	add_to_group("interactable_objects")
	_loadScript()
	await get_tree().process_frame  # Ensure scene is fully ready before init
	_init_object()

func _init_object():
	# Override in child classes to generate data and build the initial display
	pass

### Display

func _buildDisplay():
	# Constructs the bar-chart card visualisation from the current dataNodes array
	# Cards are scaled in height proportional to their value
	for child in nodeDisplay.get_children():
		child.queue_free()
	cardNodes.clear()

	if dataNodes.is_empty():
		return

	var totalWidth = dataNodes.size() * (cardWidth + cardGap) - cardGap
	var startX = -totalWidth / 2.0
	var tileTexture = _getCardTileTexture()

	for i in range(dataNodes.size()):
		var node = dataNodes[i]
		var scaledHeight = (1.0 + node["value"] / 10.0) * cardHeight
		var card = PanelContainer.new()
		card.size = Vector2(cardWidth, scaledHeight)
		card.position = Vector2(startX + i * (cardWidth + cardGap), 2.0 * cardHeight - scaledHeight)

		var tileStyle = StyleBoxTexture.new()
		tileStyle.texture = tileTexture
		card.add_theme_stylebox_override("panel", tileStyle)

		var label = Label.new()
		label.text = "%s\n%d" % [node["name"], node["value"]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(label)

		nodeDisplay.add_child(card)
		cardNodes.append(card)

	nodeDisplay.size = Vector2(totalWidth, 2.0 * cardHeight)

func _getCardTileTexture() -> AtlasTexture:
	# Extracts a single tile from the level tileset atlas for use as a card background
	var tileSet = load("res://graphics/LevelGroundTileset.tres") as TileSet
	var source = tileSet.get_source(0) as TileSetAtlasSource
	var atlas = AtlasTexture.new()
	atlas.atlas = source.texture
	atlas.region = Rect2(source.get_tile_texture_region(Vector2i(9, 0)))
	return atlas

func resetDisplay():
	# Kills all active tweens, restores the original data snapshot, and rebuilds the display
	for t in activeTweens:
		if is_instance_valid(t):
			t.kill()
	activeTweens.clear()
	dataNodes = initialDataNodes.duplicate(true)
	_buildDisplay()

func createTrackedTween() -> Tween:
	# Creates a tween and registers it so resetDisplay() can kill it if needed
	var t = create_tween()
	activeTweens.append(t)
	return t

### Guide & Preamble (overridden by children)

func getBaseGuide() -> String:
	# Returns BBCode-formatted text describing the available data and functions for this task
	return ""

func getPreambleFunctions() -> String:
	# Returns Python code injected before the player's script when executed via Pyodide
	return ""

func getArrayString() -> String:
	# Produces a Python list literal from the current dataNodes for injection into the preamble
	var values = []
	for n in dataNodes:
		values.append(str(n["value"]))
	return "[" + ", ".join(values) + "]"

### Hover & Interaction

func _process(_delta):
	if not is_visible_in_tree():
		return
	var mouse = get_global_mouse_position()
	var sprite_size = Vector2.ZERO
	if visual.texture:
		sprite_size = visual.texture.get_size() * visual.scale
	var sprite_pos = visual.global_position
	if visual.centered:
		sprite_pos -= sprite_size / 2.0
	var rect = Rect2(sprite_pos, sprite_size)
	var wasHovered = _hovered
	_hovered = rect.has_point(mouse)
	if _hovered != wasHovered:
		hoverLabel.visible = _hovered

func _input(event):
	# Opens the IDE popup when the player left-clicks on this object
	if not is_visible_in_tree():
		return
	if _hovered and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _popup:
				_popup.open(objectName, self)

### Script Persistence

func _loadScript():
	# Reads the player's previously saved code for this object from localStorage
	var result = JavaScriptBridge.eval("""
		localStorage.getItem('%s') || ''
	""" % _getStorageKey())
	if result != null:
		savedScript = str(result)

func saveScript(code: String):
	# Writes the current code to localStorage, called whenever the player types, runs code or closes the IDE
	savedScript = code
	JavaScriptBridge.eval("""
		localStorage.setItem('%s', %s);
	""" % [_getStorageKey(), JSON.stringify(code)])

func _getStorageKey() -> String:
	# Unique key per object, scoped to its parent room, to avoid collisions across levels
	return "script_%s_%s" % [get_parent().name, objectID]

func runSavedScript():
	# Re-executes the saved script silently (e.g. when re-entering a room)
	if savedScript.strip_edges() == "":
		return
	if not get_parent().visible:
		return
	if _popup:
		_popup.runScript(savedScript, self)

class_name InteractableObject
extends Area2D
# Emitted by child classes (SortObject, SearchObject, etc.) when their task is completed correctly
# The Level script connects to this signal to track room completion
signal roomTaskCompleted(objectID: String)

@onready var hoverLabel: Label = $hoverLabel
@onready var visual: Sprite2D = $visual
@onready var nodeDisplay: Control = $nodeDisplay

@export var objectName: String = "Object"
@export var objectID: String = "obj_0"
@export_multiline var taskDescription: String = "None"
@export var taskName: String = "None"
@export_multiline var taskGuide: String = "None"
@export_multiline var exampleCode: String = ""

var _hovered := false
var _popup: CanvasLayer
var dataNodes: Array = []
var initialDataNodes: Array = []
var cardNodes: Array = []
var savedScript: String = ""
var activeTweens: Array = []

const cardWidth = 60
const cardHeight = 60
const cardGap = 15

func _ready():
	hoverLabel.visible = false
	add_to_group("interactable_objects")
	_loadScript()
	await get_tree().process_frame
	_init_object()

# Override in child classes for custom setup
func _init_object():
	pass

func _buildDisplay():
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
	var tileSet = load("res://graphics/LevelGroundTileset.tres") as TileSet
	var source = tileSet.get_source(0) as TileSetAtlasSource
	var atlas = AtlasTexture.new()
	atlas.atlas = source.texture
	atlas.region = Rect2(source.get_tile_texture_region(Vector2i(9, 0)))
	return atlas

func getBaseGuide() -> String:
	return ""

func createTrackedTween() -> Tween:
	var t = create_tween()
	activeTweens.append(t)
	return t

func resetDisplay():
	for t in activeTweens:
		if is_instance_valid(t):
			t.kill()
	activeTweens.clear()
	dataNodes = initialDataNodes.duplicate(true)
	_buildDisplay()

func _process(_delta):
	if not is_visible_in_tree():
		return
	var mouse = get_global_mouse_position()
	
	# Calculate Sprite2D bounds
	var sprite_size = Vector2.ZERO
	if visual.texture:
		sprite_size = visual.texture.get_size() * visual.scale
	
	# Account for centered sprite (default for Sprite2D)
	var sprite_pos = visual.global_position
	if visual.centered:
		sprite_pos -= sprite_size / 2.0
	
	var rect = Rect2(sprite_pos, sprite_size)
	var wasHovered = _hovered
	_hovered = rect.has_point(mouse)
	if _hovered != wasHovered:
		hoverLabel.visible = _hovered

func _input(event):
	if not is_visible_in_tree():
		return
	if _hovered and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _popup:
				_popup.open(objectName, self)

# Override in child to provide Python preamble functions
func getPreambleFunctions() -> String:
	return ""

func getArrayString() -> String:
	var values = []
	for n in dataNodes:
		values.append(str(n["value"]))
	return "[" + ", ".join(values) + "]"

func selectNode(index: int):
	if index < 0 or index >= cardNodes.size():
		return
	for i in range(cardNodes.size()):
		var label = cardNodes[i].get_child(0)
		if i == index:
			label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label.remove_theme_color_override("font_color")

func _loadScript():
	var result = JavaScriptBridge.eval("""
        localStorage.getItem('%s') || ''
	""" % _getStorageKey())
	if result != null:
		savedScript = str(result)

func saveScript(code: String):
	savedScript = code
	JavaScriptBridge.eval("""
        localStorage.setItem('%s', %s);
	""" % [_getStorageKey(), JSON.stringify(code)])

func _getStorageKey() -> String:
	return "script_%s_%s" % [get_parent().name, objectID]

func runSavedScript():
	if savedScript.strip_edges() == "":
		return
	if not get_parent().visible:
		return
	if _popup:
		_popup.runScript(savedScript, self)

class_name InteractableObject
extends Area2D

# Emitted by child classes (SortObject, SearchObject, etc.) when their task is completed correctly
# The Level script connects to this signal to track room completion
signal roomTaskCompleted(objectID: String)

@onready var hoverLabel: Label = $hoverLabel
@onready var visual: ColorRect = $visual
@onready var nodeDisplay: Control = $nodeDisplay

@export var objectName: String = "Object"
@export var objectID: String = "obj_0"
@export_multiline var taskDescription: String = "None"
@export var taskName: String = "None"
@export_multiline var taskGuide: String = "None"

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
	add_to_group("interactable_objects")  # UPDATED: Changed to "interactable_objects"
	_loadScript()
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
	for i in range(dataNodes.size()):
		var node = dataNodes[i]
		var scaledHeight = (1.0 + node["value"] / 10.0) * cardHeight
		var card = PanelContainer.new()
		card.size = Vector2(cardWidth, scaledHeight)
		card.position = Vector2(startX + i * (cardWidth + cardGap), 2.0 * cardHeight - scaledHeight)
		var label = Label.new()
		label.text = "%s\n%d" % [node["name"], node["value"]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_child(label)
		nodeDisplay.add_child(card)
		cardNodes.append(card)
	nodeDisplay.size = Vector2(totalWidth, 2.0 * cardHeight)

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
	var mouse = get_global_mouse_position()
	var rect = Rect2(visual.global_position, visual.size)
	var wasHovered = _hovered
	_hovered = rect.has_point(mouse)
	if _hovered != wasHovered:
		hoverLabel.visible = _hovered

func _input(event):
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
		localStorage.getItem('script_%s') || ''
	""" % objectID)
	if result != null:
		savedScript = str(result)

func saveScript(code: String):
	savedScript = code
	JavaScriptBridge.eval("""
		localStorage.setItem('script_%s', %s);
	""" % [objectID, JSON.stringify(code)])

func runSavedScript():
	if savedScript.strip_edges() == "":
		return
	if not get_parent().visible:
		return
	if _popup:
		_popup.runScript(savedScript, self)

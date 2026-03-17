extends Area2D

@onready var hoverLabel: Label = $hoverLabel
@onready var visual: ColorRect = $visual
@onready var nodeDisplay: HBoxContainer = $nodeDisplay
@export var objectName: String = "object"

var _hovered := false
var _popup: CanvasLayer
var _selectedIndex :int = -1
var dataNodes: Array = []
var cardNodes: Array = []
var swapQueue: Array = [] 
var isAnimating : bool = false

func _ready():
	hoverLabel.visible = false
	
	for i in range(10):
		dataNodes.append({
			"name":"node%d" % i,
			"value": randi_range(1,10)
		})
		
	_buildDisplay()
	
func _buildDisplay():
	for child in nodeDisplay.get_children():
		child.queue_free()
	cardNodes.clear()
	
	for i in range(dataNodes.size()):
		var node = dataNodes[i]
		var card = PanelContainer.new()
		var label = Label.new()
		label.text = "%s : %d" % [node["name"], node["value"]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(label)
		nodeDisplay.add_child(card)
		cardNodes.append(card)

		if i == _selectedIndex:
			label.add_theme_color_override("font_color", Color.YELLOW)

		card.add_child(label)
		nodeDisplay.add_child(card)

func _process(_delta):
	var mouse = get_global_mouse_position()
	var rect = Rect2(visual.global_position, visual.size)
	
	var was_hovered = _hovered
	_hovered = rect.has_point(mouse)
	
	if _hovered != was_hovered:
		hoverLabel.visible = _hovered

func _input(event):
	if _hovered and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _popup:
				_popup.open(objectName, self)
				
func readNode(index: int) -> String:
	if index < 0 or index >= dataNodes.size():
		return "Error: index %d out of range" % index
	var node = dataNodes[index]
	return "%s = %d" % [node["name"], node["value"]]

func selectNode(index: int):
	_selectedIndex = index
	_buildDisplay()

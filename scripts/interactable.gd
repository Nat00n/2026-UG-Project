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
		card.add_child(label)
		nodeDisplay.add_child(card)
		cardNodes.append(card)

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
	
	for i in range(cardNodes.size()):
		var label = cardNodes[i].get_child(0)
		if i == _selectedIndex:
			label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label.remove_theme_color_override("font_color")

func queueSwap(i: int, j: int):
	swapQueue.append([i,j])
	
func commitSort():
	if not isAnimating:
		isAnimating = true
		_playNextSwap()
		
func _playNextSwap():
	if swapQueue.is_empty():
		isAnimating = false
		_buildDisplay()
		return
		
	var step = swapQueue.pop_front()
	var i = step[0]
	var j = step[1]

	# Swap in dataNodes array
	var temp = dataNodes[i]
	dataNodes[i] = dataNodes[j]
	dataNodes[j] = temp

	# Animate the two cards sliding past each other
	_animateSwap(i, j)
	
func _animateSwap(i: int, j: int):
	var cardA = cardNodes[i]
	var cardB = cardNodes[j]

	var posA = cardA.global_position
	var posB = cardB.global_position
	
	var sceneRoot = get_tree().current_scene
	cardA.reparent(sceneRoot)
	cardB.reparent(sceneRoot)
	
	cardA.global_position = posA
	cardB.global_position = posB

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(cardA, "global_position", posB, 0.4)
	tween.tween_property(cardB, "global_position", posA, 0.4)
	tween.set_parallel(false)
	
	tween.tween_callback(func():
		# Swap card references in cardNodes
		var temp = cardNodes[i]
		cardNodes[i] = cardNodes[j]
		cardNodes[j] = temp
		
		for card in cardNodes:
			card.reparent(nodeDisplay)

		# Play next step after a short pause
		await get_tree().create_timer(0.15).timeout
		_playNextSwap()
	)

extends Area2D

@onready var hoverLabel: Label = $hoverLabel
@onready var visual: ColorRect = $visual
@onready var nodeDisplay: Control = $nodeDisplay
@export var objectName: String = "NamelessObject"
@export var objectID: String = "object_000"
@export var taskDesc: String = "None"

var _hovered := false
var _popup: CanvasLayer
var _selectedIndex :int = -1
var dataNodes: Array = []
var cardNodes: Array = []
var swapQueue: Array = [] 
var isAnimating : bool = false
var savedScript: String = ""

const cardWidth = 60
const cardHeight = 60
const cardGap = 15

func _ready():
	hoverLabel.visible = false
	
	for i in range(10):
		dataNodes.append({
			"name":"node%d" % i,
			"value": randi_range(1,10)
		})
		
	_buildDisplay()
	_loadScript()
	
func _loadScript():
	var result = JavaScriptBridge.eval("""
        localStorage.getItem('script_%s') || ''
	""" % objectID)
	if result != null:
		savedScript = str(result)

func saveScript(code: String):
	savedScript = code
	# Encode string with json
	var jsonCode = JSON.stringify(code)
	JavaScriptBridge.eval("""
        localStorage.setItem('script_%s', %s);
	""" % [objectID, jsonCode])

func runSavedScript():
	if savedScript.strip_edges() == "":
		return
	if _popup:
		_popup.runScript(savedScript, self)
	
func _buildDisplay():
	for child in nodeDisplay.get_children():
		child.queue_free()
	cardNodes.clear()
	
	var totalWidth = dataNodes.size() * (cardWidth + cardGap) - cardGap
	var startX = -totalWidth / 2.0  # centred around origin
	
	for i in range(dataNodes.size()):
		var node = dataNodes[i]
		
		var scaledHeight = (1.0 + node["value"] / 10.0 ) * cardHeight
		
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
		return

	var step = swapQueue.pop_front()
	var i = step[0]
	var j = step[1]

	# Swap in dataNodes
	var temp = dataNodes[i]
	dataNodes[i] = dataNodes[j]
	dataNodes[j] = temp

	_animateSwap(i, j)

func _animateSwap(i: int, j: int):
	var cardA = cardNodes[i]
	var cardB = cardNodes[j]
	
	var totalWidth = dataNodes.size() * (cardWidth + cardGap) - cardGap
	var startX = -totalWidth / 2.0

	var scaledHeightA = (1.0 + dataNodes[i]["value"] / 10.0) * cardHeight
	var scaledHeightB = (1.0 + dataNodes[j]["value"] / 10.0) * cardHeight

	var posA = Vector2(startX + i * (cardWidth + cardGap), 2.0 * cardHeight - scaledHeightA)
	var posB = Vector2(startX + j * (cardWidth + cardGap), 2.0 * cardHeight - scaledHeightB)

	# Lift swapping cards above others visually
	cardA.z_index = 1
	cardB.z_index = 1

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(cardA, "position", posB, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cardB, "position", posA, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(false)

	tween.tween_callback(func():
		# Swap card references to match new order
		var temp = cardNodes[i]
		cardNodes[i] = cardNodes[j]
		cardNodes[j] = temp

		# Update labels to match dataNodes
		cardNodes[i].get_child(0).text = "%s\n%d" % [dataNodes[i]["name"], dataNodes[i]["value"]]
		cardNodes[j].get_child(0).text = "%s\n%d" % [dataNodes[j]["name"], dataNodes[j]["value"]]

		# Reset z
		cardNodes[i].z_index = 0
		cardNodes[j].z_index = 0

		await get_tree().create_timer(0.15).timeout
		_playNextSwap()
	)
